#!/usr/bin/env python3
"""在原生 Codex TUI 与专属 app-server 之间只读观察生命周期。"""

from collections import deque
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import uuid

FINAL_REPORT_TIMEOUT = 3


class StatusMonitor:
    def __init__(self):
        self.condition = threading.Condition()
        self.requests = {}
        self.thread_id = None
        self.turn_id = None
        self.retired_turns = []
        self.status = "detached"
        self.exit_status = None
        self.generation = 0
        self.closed = False
        self.snapshots = deque()
        self.last_snapshot = None

    def publish(self):
        snapshot = (self.thread_id, self.status, self.exit_status, self.generation, self.closed)
        if snapshot != self.last_snapshot:
            if len(self.snapshots) >= 256:
                self.closed = True
                self.status = "detached"
                self.snapshots.clear()
                snapshot = (self.thread_id, "detached", None, self.generation + 1, True)
            self.snapshots.append(snapshot)
            self.last_snapshot = snapshot
            self.condition.notify_all()

    def update(self, status, exit_status=None):
        if (status, exit_status) != (self.status, self.exit_status):
            self.status, self.exit_status = status, exit_status
            self.generation += 1
            self.condition.notify_all()

    def runtime_status(self, status):
        kind = status.get("type") if isinstance(status, dict) else None
        if kind == "active":
            flags = status.get("activeFlags")
            if not isinstance(flags, list) or any(
                flag not in {"waitingOnApproval", "waitingOnUserInput"} for flag in flags
            ):
                self.update("detached")
            else:
                self.update("awaitingInput" if flags else "running")
        elif kind == "idle":
            # Only turn/completed proves success; a later idle must not erase it.
            if self.status != "finished":
                self.update("idle")
        else:
            self.update("detached")

    def observe(self, message, from_server):
        if not isinstance(message, dict):
            return
        with self.condition:
            if self.closed:
                return
            try:
                self.observe_locked(message, from_server)
            finally:
                self.publish()

    def observe_locked(self, message, from_server):
        method = message.get("method")
        params = message.get("params", {})
        request_id = message.get("id")
        if not from_server:
            if method in {"thread/start", "thread/resume", "thread/fork"}:
                if type(request_id) in (int, str) and len(self.requests) < 64:
                    self.requests[request_id] = method
            return
        if method is None and type(request_id) in (int, str):
            if self.requests.pop(request_id, None) is None:
                return
            result = message.get("result")
            thread = result.get("thread") if isinstance(result, dict) else None
            if not isinstance(thread, dict) or not isinstance(thread.get("id"), str):
                return
            thread_id = thread["id"]
            if not 1 <= len(thread_id) <= 128:
                return
            self.thread_id, self.turn_id, self.retired_turns = thread_id, None, []
            self.generation += 1
            self.status, self.exit_status = "detached", None
            self.runtime_status(thread.get("status"))
            for turn in thread.get("turns", []):
                if isinstance(turn, dict) and turn.get("status") == "inProgress":
                    self.turn_id = turn.get("id")
            self.condition.notify_all()
            return
        if not isinstance(params, dict) or params.get("threadId") != self.thread_id or self.thread_id is None:
            return
        if method == "thread/status/changed":
            self.runtime_status(params.get("status"))
        elif method == "turn/started":
            turn = params.get("turn", {})
            if isinstance(turn, dict) and isinstance(turn.get("id"), str) and turn["id"] not in self.retired_turns:
                self.turn_id = turn["id"]
                self.generation += 1
                self.update("running")
                self.condition.notify_all()
        elif method == "turn/completed":
            turn = params.get("turn", {})
            if not isinstance(turn, dict) or not isinstance(turn.get("id"), str):
                return
            turn_id = turn["id"]
            if turn_id in self.retired_turns or (self.turn_id is not None and turn_id != self.turn_id):
                return
            self.retired_turns = (self.retired_turns + [turn_id])[-128:]
            self.turn_id = None
            self.generation += 1
            status = turn.get("status")
            if status in {"completed", "failed"}:
                self.update("finished", 0 if status == "completed" else 1)
            else:
                self.update("idle" if status == "interrupted" else "detached")
            self.condition.notify_all()
        elif method == "thread/closed":
            self.update("detached")

    def close(self):
        with self.condition:
            if self.closed:
                return
            # Never replay a backlog of working states after the TUI disconnects.
            terminal = next((snapshot for snapshot in reversed(self.snapshots)
                             if snapshot[0] == self.thread_id and snapshot[1] == "finished"), None)
            self.snapshots.clear()
            if terminal is not None:
                self.snapshots.append(terminal)
            self.closed = True
            self.update("detached")
            self.publish()
            self.condition.notify_all()


class WebSocketObserver:
    """只解析副本；HTTP Upgrade、帧和审批回复始终原字节转发。"""

    maximum_size = 16 * 1024 * 1024

    def __init__(self, on_message):
        self.on_message = on_message
        self.buffer = bytearray()
        self.upgraded = False
        self.fragments = None

    def feed(self, data):
        self.buffer.extend(data)
        if not self.upgraded:
            end = self.buffer.find(b"\r\n\r\n")
            if end < 0:
                if len(self.buffer) > 16384:
                    raise ValueError("oversized handshake")
                return
            del self.buffer[:end + 4]
            self.upgraded = True
        while len(self.buffer) >= 2:
            first, second = self.buffer[:2]
            final, opcode, masked = bool(first & 128), first & 15, bool(second & 128)
            if first & 112:
                raise ValueError("unsupported WebSocket extension")
            size, offset = second & 127, 2
            if size in (126, 127):
                width = 2 if size == 126 else 8
                if len(self.buffer) < 2 + width:
                    return
                size = int.from_bytes(self.buffer[2:2 + width], "big")
                offset += width
            if size > self.maximum_size:
                raise ValueError("oversized frame")
            total = offset + (4 if masked else 0) + size
            if len(self.buffer) < total:
                return
            mask = self.buffer[offset:offset + 4] if masked else None
            offset += 4 if masked else 0
            payload = self.buffer[offset:total]
            del self.buffer[:total]
            if mask:
                payload = bytearray(value ^ mask[index % 4] for index, value in enumerate(payload))
            if opcode >= 8:
                continue
            if opcode == 1 and self.fragments is None:
                self.fragments = bytearray()
            elif opcode != 0 or self.fragments is None:
                raise ValueError("unsupported data frame")
            self.fragments.extend(payload)
            if len(self.fragments) > self.maximum_size:
                raise ValueError("oversized message")
            if final:
                message = json.loads(self.fragments.decode("utf-8"))
                self.fragments = None
                self.on_message(message)


def relay(source, destination, monitor, from_server):
    observer = WebSocketObserver(lambda message: monitor.observe(message, from_server))
    try:
        while True:
            data = source.recv(65536)
            if not data:
                break
            if observer is not None:
                try:
                    observer.feed(data)
                except (ValueError, UnicodeError, TypeError):
                    # A newer protocol may remain usable, but its status is no longer proven.
                    monitor.close()
                    observer = None
            destination.sendall(data)
    except OSError:
        pass
    finally:
        monitor.close()
        for peer in (source, destination):
            try:
                peer.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            peer.close()


def deliver_final_status(reporter, state):
    deadline = time.monotonic() + FINAL_REPORT_TIMEOUT
    while time.monotonic() < deadline:
        if reporter.send_codex_state(state):
            return True
        # Rejection can mean a newer Agent owns the terminal. Never reclaim it.
        if state.get("lastError") == "rejected":
            break
        time.sleep(min(0.1, max(0, deadline - time.monotonic())))
    print("iTermate Codex：最终状态 " + state["status"] + " 未获确认（"
          + (state.get("lastError") or "timeout") + "）。", file=sys.stderr)
    return False


def report_status(monitor, reporter, session_id):
    state = {"reporterId": str(uuid.uuid4()), "sequence": 0}
    last_generation = -1
    observed_at = time.monotonic()
    snapshot = (None, "detached", None, 0, False)
    while True:
        with monitor.condition:
            if monitor.snapshots:
                snapshot = monitor.snapshots.popleft()
        thread_id, status, exit_status, generation, closed = snapshot
        if thread_id is not None:
            # Keep an in-flight, failed completion intact until its final retry.
            # close() cannot recover it from the queue once it has been popped.
            if ((closed or status == "detached") and state.get("codexSessionId") == thread_id
                    and state.get("status") == "finished" and not state.get("acknowledged")):
                deliver_final_status(reporter, state)
            changed = generation != last_generation
            if changed:
                new_owner = thread_id != state.get("codexSessionId")
                state.update({
                    "itermSessionId": session_id, "codexSessionId": thread_id,
                    "status": status, "exitStatus": exit_status,
                    "generation": str(uuid.uuid4()), "acknowledged": False,
                })
                if new_owner:
                    # The existing receiver only permits explicit idle/running ownership claims.
                    state["pendingClaim"] = True
                    state["status"] = "idle"
                    reporter.send_codex_state(state, claim=True)
                    state.update({"status": status, "acknowledged": False, "generation": str(uuid.uuid4())})
                last_generation, observed_at = generation, time.monotonic()
            if closed:
                deliver_final_status(reporter, state)
            elif changed or status in {"running", "awaitingInput"} or (
                not state.get("acknowledged") and time.monotonic() - observed_at < 15
            ):
                reporter.send_codex_state(state)
        if closed:
            return
        with monitor.condition:
            if not monitor.snapshots and not monitor.closed:
                monitor.condition.wait(timeout=2)


def launch_arguments(arguments):
    # Keep the native TUI argument parser; prevent escaping the owned transport or
    # silently using a local-only profile on a differently configured server.
    server_arguments = []
    working_directory = None
    index = 0
    first_operand = None
    value_options = {"-C", "--cd", "-m", "--model", "-s", "--sandbox", "-a", "--ask-for-approval", "-i", "--image", "--add-dir", "--local-provider"}
    while index < len(arguments):
        argument = arguments[index]
        if argument == "--":
            break
        if argument.startswith("-c") and not argument.startswith("--") and len(argument) > 2:
            server_arguments.extend(["-c", argument[2:].removeprefix("=")])
            index += 1
            continue
        if argument.startswith("-p") and not argument.startswith("--") and len(argument) > 2:
            raise ValueError("包装器不支持 --profile；请直接使用 codex 执行该模式。")
        if argument.startswith("-C") and len(argument) > 2:
            working_directory = argument[2:].removeprefix("=")
            index += 1
            continue
        key = argument.split("=", 1)[0]
        if key in {"--remote", "--remote-auth-token-env", "--no-daemon", "--profile", "-p", "--worktree"}:
            raise ValueError("包装器不支持 " + key + "；请直接使用 codex 执行该模式。")
        if key in {"-c", "--config", "--enable", "--disable"}:
            server_arguments.append(argument)
            if "=" not in argument:
                index += 1
                if index >= len(arguments):
                    raise ValueError("缺少参数：" + key)
                server_arguments.append(arguments[index])
        elif key == "--strict-config":
            server_arguments.append(argument)
        elif key in {"-C", "--cd"}:
            if "=" in argument:
                working_directory = argument.split("=", 1)[1]
            else:
                index += 1
                if index >= len(arguments):
                    raise ValueError("缺少参数：" + key)
                working_directory = arguments[index]
        elif key in value_options and "=" not in argument:
            index += 1
        elif not argument.startswith("-") and first_operand is None:
            first_operand = argument
        index += 1
    if first_operand in {"agents", "exec", "e", "review", "login", "logout", "mcp", "plugin", "app-server", "remote-control", "app", "completion", "update", "doctor", "sandbox", "debug", "apply", "a", "queue", "archive", "delete", "migrate-rollouts", "unarchive", "cloud", "exec-server", "features", "help"}:
        raise ValueError("包装器只支持交互 TUI、resume 和 fork；其他命令请直接使用 codex。")
    return server_arguments, working_directory


def stop_process(process, process_group=False):
    if process is None or process.poll() is not None:
        return
    try:
        if process_group:
            os.killpg(process.pid, signal.SIGTERM)
        else:
            process.terminate()
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        if process_group:
            os.killpg(process.pid, signal.SIGKILL)
        else:
            process.kill()
        process.wait(timeout=3)
    except ProcessLookupError:
        pass


def run(arguments, reporter):
    server_arguments, working_directory = launch_arguments(arguments)
    session_id = reporter.iterm_session_id()
    try:
        # Validate the format without changing iTerm2's case-sensitive routing ID.
        uuid.UUID(session_id)
    except (ValueError, TypeError, AttributeError):
        raise ValueError("此包装器目前仅支持具有真实 Session ID 的 iTerm2 终端。")
    codex = shutil.which("codex")
    if codex is None:
        raise ValueError("PATH 中未找到 codex。")
    monitor = StatusMonitor()
    backend = tui = None
    worker = None
    connections = []
    environment = dict(os.environ, ITERMATE_CODEX_WRAPPER="1")
    # Short, private paths also fit macOS's sockaddr_un limit.
    with tempfile.TemporaryDirectory(prefix="itc-", dir="/tmp") as directory:
        backend_path, frontend_path = directory + "/b.sock", directory + "/f.sock"
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(frontend_path)
            listener.listen(1)
            listener.settimeout(0.1)
            try:
                backend = subprocess.Popen(
                    [codex, "app-server", *server_arguments, "--listen", "unix://" + backend_path],
                    stdin=subprocess.DEVNULL, env=environment, start_new_session=True,
                    cwd=working_directory,
                )
                deadline = time.monotonic() + 15
                while not os.path.exists(backend_path):
                    if backend.poll() is not None or time.monotonic() >= deadline:
                        raise ValueError("Codex app-server 未能启动；需要支持 --remote 与 Unix Socket 的版本。")
                    time.sleep(0.05)
                tui = subprocess.Popen([codex, "--remote", "unix://" + frontend_path, *arguments], env=environment)
                while tui.poll() is None and backend.poll() is None:
                    try:
                        client, _ = listener.accept()
                    except socket.timeout:
                        continue
                    connections.append(client)
                    upstream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    connections.append(upstream)
                    upstream.connect(backend_path)
                    worker = threading.Thread(target=report_status, args=(monitor, reporter, session_id), daemon=True)
                    worker.start()
                    for source, destination, from_server in ((client, upstream, False), (upstream, client, True)):
                        threading.Thread(target=relay, args=(source, destination, monitor, from_server), daemon=True).start()
                    break
                while tui.poll() is None and backend.poll() is None:
                    time.sleep(0.1)
                code = tui.returncode
                return (128 - code if code < 0 else code) if code is not None else 1
            finally:
                monitor.close()
                for connection in connections:
                    connection.close()
                if worker is not None:
                    worker.join(timeout=2 * FINAL_REPORT_TIMEOUT + 3)
                stop_process(tui)
                stop_process(backend, process_group=True)


def main():
    if sys.argv[1:] in (["--help"], ["-h"]):
        print("用法：iTermate-codex.py [Codex TUI 参数] [resume|fork]\n"
              "保留原生 TUI，通过专属 app-server 监控状态，仅支持 iTerm2。\n"
              "不支持 --remote、--no-daemon、--profile、--worktree 或非交互子命令。")
        return 0
    if sys.argv[1:] in (["--version"], ["-V"]):
        return subprocess.call(["codex", "--version"])
    spec = importlib.util.spec_from_file_location("itermate_status", Path(__file__).with_name("iTermate-status.py"))
    reporter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reporter)
    # Let the foreground TUI handle Ctrl-C as a turn interrupt, not a wrapper exit.
    signal.signal(signal.SIGINT, lambda *_: None)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    try:
        return run(sys.argv[1:], reporter)
    except (OSError, ValueError) as error:
        print("iTermate Codex：" + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
