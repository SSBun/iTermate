#!/usr/bin/env python3

import fcntl
import json
import os
import socket
import subprocess
import sys
import time
import uuid

SUPPORT_DIRECTORY = os.path.expanduser("~/Library/Application Support/iTermate")
BRIDGE_SOCKET_PATH = os.path.join(SUPPORT_DIRECTORY, "bridge.sock")
STATUS_SOCKET_PATH = os.path.join(SUPPORT_DIRECTORY, "status.sock")
AGENT_STATE_DIRECTORY = os.path.join(SUPPORT_DIRECTORY, "agent-state")
VALID_STATUSES = {"idle", "running", "finished", "detached"}
# ponytail: bounds orphaned Codex heartbeat workers; raise if real turns exceed six hours.
MAX_AGENT_HEARTBEAT_AGE = 6 * 60 * 60


def normalize_tty(value):
    if (
        not isinstance(value, str)
        or value == "/dev/tty"
        or not value.startswith("/dev/tty")
    ):
        return None
    if len(value) > 128 or "/" in value[len("/dev/") :]:
        return None
    return value


def controlling_tty():
    for descriptor in (0, 1, 2):
        try:
            value = os.ttyname(descriptor)
        except OSError:
            continue
        if value != "/dev/tty" and normalize_tty(value):
            return value

    try:
        value = subprocess.check_output(
            ["/bin/ps", "-o", "tty=", "-p", str(os.getpid())],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return None
    if not value or value == "??":
        return None
    return normalize_tty(value if value.startswith("/dev/") else f"/dev/{value}")


def iterm_session_id():
    if os.environ.get("TERM_PROGRAM") != "iTerm.app":
        return None
    value = os.environ.get("ITERM_SESSION_ID") or os.environ.get("TERM_SESSION_ID")
    return value.rsplit(":", 1)[-1] if value else None


def exchange(socket_path, request, bridge=False):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(1)
            client.connect(socket_path)
            stream = client.makefile("rb")
            if bridge:
                stream.readline()
                stream.readline()
            client.sendall(
                (json.dumps(request, separators=(",", ":")) + "\n").encode("utf-8")
            )
            stream.readline()
    except (OSError, TimeoutError):
        pass


def report_iterm(status):
    session_id = iterm_session_id()
    if session_id is None:
        return False
    request = {
        "version": 7,
        "type": "setSessionStatus",
        "requestId": str(uuid.uuid4()),
        "sessionId": session_id,
        "status": status,
    }
    if status == "finished":
        request["exitStatus"] = 0
    exchange(BRIDGE_SOCKET_PATH, request, bridge=True)
    return True


def report_terminal(
    tty,
    source,
    reporter_id,
    sequence,
    status,
    exit_status=None,
    heartbeat=False,
):
    request = {
        "version": 1,
        "type": "setTerminalStatus",
        "requestId": str(uuid.uuid4()),
        "tty": tty,
        "source": source,
        "reporterId": reporter_id,
        "sequence": sequence,
        "status": status,
        "heartbeat": heartbeat,
    }
    if status == "finished":
        request["exitStatus"] = exit_status
    exchange(STATUS_SOCKET_PATH, request)


def agent_state_path(tty):
    os.makedirs(AGENT_STATE_DIRECTORY, mode=0o700, exist_ok=True)
    os.chmod(AGENT_STATE_DIRECTORY, 0o700)
    return os.path.join(AGENT_STATE_DIRECTORY, f"codex-{os.path.basename(tty)}.json")


def locked_agent_state(tty):
    path = agent_state_path(tty)
    state_file = open(path, "a+", encoding="utf-8")
    os.chmod(path, 0o600)
    fcntl.flock(state_file, fcntl.LOCK_EX)
    state_file.seek(0)
    try:
        state = json.load(state_file)
    except (json.JSONDecodeError, ValueError):
        state = {}
    return state_file, state


def write_agent_state(state_file, state):
    state_file.seek(0)
    state_file.truncate()
    json.dump(state, state_file, separators=(",", ":"))
    state_file.flush()
    os.fsync(state_file.fileno())


def update_agent_state(tty, status):
    state_file, state = locked_agent_state(tty)
    try:
        if status in {"idle", "running"}:
            reporter_id = str(uuid.uuid4())
            sequence = 1
        else:
            reporter_id = state.get("reporterId") or str(uuid.uuid4())
            sequence = state.get("sequence", 0) + 1
        state = {
            "reporterId": reporter_id,
            "sequence": sequence,
            "status": status,
        }
        if status == "running":
            state["startedAt"] = time.time()
        write_agent_state(state_file, state)
        return reporter_id, sequence
    finally:
        state_file.close()


def next_heartbeat(tty, reporter_id):
    state_file, state = locked_agent_state(tty)
    try:
        if state.get("reporterId") != reporter_id or state.get("status") != "running":
            return None
        state["sequence"] = state.get("sequence", 0) + 1
        status = "running"
        if time.time() - state.get("startedAt", 0) > MAX_AGENT_HEARTBEAT_AGE:
            status = "detached"
            state["status"] = status
        write_agent_state(state_file, state)
        return status, state["sequence"]
    finally:
        state_file.close()


def run_heartbeat(tty, reporter_id):
    while True:
        time.sleep(2)
        event = next_heartbeat(tty, reporter_id)
        if event is None:
            return
        status, sequence = event
        report_terminal(
            tty,
            "agent",
            reporter_id,
            sequence,
            status,
            heartbeat=status == "running",
        )
        if status == "detached":
            return


def start_heartbeat(tty, reporter_id):
    subprocess.Popen(
        [sys.executable, os.path.realpath(__file__), "_heartbeat", tty, reporter_id],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        close_fds=True,
    )


def report_agent(status):
    sys.stdin.buffer.read()
    if report_iterm(status):
        return
    tty = controlling_tty()
    if tty is None:
        return
    reporter_id, sequence = update_agent_state(tty, status)
    report_terminal(
        tty,
        "agent",
        reporter_id,
        sequence,
        status,
        exit_status=0 if status == "finished" else None,
    )
    if status == "running":
        start_heartbeat(tty, reporter_id)


def detach_running_agent(tty):
    path = os.path.join(
        AGENT_STATE_DIRECTORY,
        f"codex-{os.path.basename(tty)}.json",
    )
    if not os.path.exists(path):
        return None
    state_file, state = locked_agent_state(tty)
    try:
        if state.get("status") != "running" or not state.get("reporterId"):
            return None
        state["sequence"] = state.get("sequence", 0) + 1
        state["status"] = "detached"
        write_agent_state(state_file, state)
        return state["reporterId"], state["sequence"]
    finally:
        state_file.close()


def report_shell(arguments):
    if len(arguments) != 5:
        return
    status, tty, reporter_id, sequence_text, exit_status_text = arguments
    tty = normalize_tty(tty)
    if tty is None or status not in {"running", "finished", "detached"}:
        return
    try:
        sequence = int(sequence_text)
        exit_status = None if exit_status_text == "-" else int(exit_status_text)
    except ValueError:
        return
    if sequence <= 0 or (status == "finished") != (exit_status is not None):
        return
    if exit_status is not None and not 0 <= exit_status <= 255:
        return
    if status == "finished":
        detached_agent = detach_running_agent(tty)
        if detached_agent is not None:
            agent_reporter_id, agent_sequence = detached_agent
            report_terminal(
                tty,
                "agent",
                agent_reporter_id,
                agent_sequence,
                "detached",
            )
    report_terminal(
        tty,
        "command",
        reporter_id,
        sequence,
        status,
        exit_status=exit_status,
    )


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "_heartbeat":
        tty = normalize_tty(sys.argv[2])
        if tty is not None:
            run_heartbeat(tty, sys.argv[3])
        return
    if len(sys.argv) == 3 and sys.argv[1] == "agent":
        if sys.argv[2] in VALID_STATUSES:
            report_agent(sys.argv[2])
        return
    if len(sys.argv) >= 2 and sys.argv[1] == "shell":
        report_shell(sys.argv[2:])


if __name__ == "__main__":
    main()
