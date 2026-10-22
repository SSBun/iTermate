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
CODEX_AGENT_HOOKS_MARKER = os.path.join(SUPPORT_DIRECTORY, "integrations", "codex-agent-hooks.json")
VALID_STATUSES = {"idle", "running", "finished", "detached"}
# ponytail: bounds orphaned Codex heartbeat workers; raise if real turns exceed six hours.
MAX_AGENT_HEARTBEAT_AGE = 6 * 60 * 60
# A cached hook observation is not proof that a turn is still making progress.
CODEX_OBSERVATION_MAX_AGE = 5 * 60
CODEX_DELIVERY_RETRY_AGE = 15
CODEX_EVENTS = {
    "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
    "Stop", "Interrupt", "SessionEnd",
}


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
    # Send immediately; hello/snapshot messages may precede or interleave the ACK.
    deadline = time.monotonic() + (0.6 if bridge else 1)
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(max(0.001, deadline - time.monotonic()))
            client.connect(socket_path)
            client.sendall(
                (json.dumps(request, separators=(",", ":")) + "\n").encode("utf-8")
            )
            buffer = b""
            while time.monotonic() < deadline:
                client.settimeout(max(0.001, deadline - time.monotonic()))
                data = client.recv(65536)
                if not data:
                    return False, "closed"
                buffer += data
                if len(buffer) > 4 * 1024 * 1024:
                    return False, "oversized-response"
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    message = json.loads(line)
                    if (isinstance(message, dict)
                            and message.get("type") == "actionResult"
                            and message.get("requestId") == request["requestId"]):
                        return (True, None) if message.get("ok") is True else (False, "rejected")
            return False, "timeout"
    except (OSError, TimeoutError):
        return False, "transport"
    except (ValueError, UnicodeError):
        return False, "invalid-response"


def apply_codex_event(previous, event, now, owner=None):
    name = event.get("hook_event_name")
    codex_id = event.get("session_id")
    turn_id = event.get("turn_id")
    if name not in CODEX_EVENTS or not isinstance(codex_id, str) or not 1 <= len(codex_id) <= 128:
        return None
    if name not in {"SessionStart", "SessionEnd"} and (
        not isinstance(turn_id, str) or not 1 <= len(turn_id) <= 128
    ):
        return None
    state = dict(previous)
    same_session = state.get("codexSessionId") == codex_id
    producer_changed = not same_codex_process(state.get("ownerProcess"), owner)
    if name == "SessionStart":
        source = event.get("source")
        if source not in {"startup", "resume", "clear"}:
            return None
        if same_session and not producer_changed and state.get("status") == "running" and source != "clear":
            return None
        status = "idle"
    elif name == "UserPromptSubmit":
        if same_session and turn_id in state.get("retiredTurns", []):
            return None
        status = "running"
    else:
        if not same_session or (owner is not None and state.get("ownerProcess") is not None and producer_changed):
            return None
        if state.get("ownerProcess") is None:
            state["ownerProcess"] = owner
        if name != "SessionEnd" and turn_id != state.get("turnId"):
            return None
        if name in {"PreToolUse", "PostToolUse"}:
            if state.get("status") != "running":
                return None
            state["observedAt"] = now
            return state
        status = {"Stop": "finished", "Interrupt": "idle", "SessionEnd": "detached"}[name]
        if state.get("status") != "running" and name != "SessionEnd":
            return None
    if not same_session:
        # Keep wire ordering across Codex sessions sharing one terminal, too.
        state = {
            "reporterId": state.get("reporterId") or str(uuid.uuid4()),
            "sequence": state.get("sequence", 0),
            "retiredTurns": [],
            "acknowledgedOwner": state.get("acknowledgedOwner"),
        }
    if name in {"SessionStart", "UserPromptSubmit"}:
        state["ownerProcess"] = owner
    old_turn = state.get("turnId")
    if old_turn and old_turn != turn_id:
        state["retiredTurns"] = state.get("retiredTurns", []) + [old_turn]
    state.update({
        "codexSessionId": codex_id,
        "turnId": turn_id if name != "SessionStart" else None,
        "status": status,
        "generation": str(uuid.uuid4()),
        "observedAt": now,
        "acknowledged": False,
        "workerToken": None,
        # A terminal event can supersede a start before that start's ACK arrives.
        "pendingClaim": state.get("pendingClaim", False) or name in {"SessionStart", "UserPromptSubmit"},
    })
    return state


def codex_state_is_fresh(state, now):
    age = now - state.get("observedAt", 0)
    maximum = CODEX_OBSERVATION_MAX_AGE if state.get("status") == "running" else CODEX_DELIVERY_RETRY_AGE
    return 0 <= age <= maximum


def send_codex_state(state, claim=False):
    state["sequence"] += 1
    request = {
        "type": "setSessionStatus",
        "requestId": str(uuid.uuid4()),
        "sessionId": state["itermSessionId"],
        "reporterId": state["reporterId"],
        "sequence": state["sequence"],
        "codexSessionId": state["codexSessionId"],
        "codexEventId": state["generation"],
        "codexClaim": claim,
        "status": state["status"],
        "heartbeat": state["status"] in {"running", "awaitingInput"} and state.get("acknowledged", False),
    }
    if state.get("pendingClaim") and state.get("acknowledgedOwner"):
        # Retry an unacknowledged claim only against the last owner we observed.
        request["codexPreviousOwner"] = state["acknowledgedOwner"]
    if state["status"] == "finished":
        request["exitStatus"] = state.get("exitStatus", 0)
    accepted, error = exchange(BRIDGE_SOCKET_PATH, request, bridge=True)
    state["acknowledged"] = accepted
    state["lastError"] = error
    if accepted:
        state["pendingClaim"] = False
        state["acknowledgedOwner"] = [state["reporterId"], state["codexSessionId"]]
    return accepted


def codex_process_info(pid):
    try:
        output = subprocess.check_output(
            ["/bin/ps", "-p", str(pid), "-o", "ppid=,lstart=,comm="],
            text=True, stderr=subprocess.DEVNULL, timeout=0.2,
        ).strip().split(None, 6)
        if len(output) != 7:
            return None
        return {"pid": pid, "parent": int(output[0]), "started": " ".join(output[1:6]), "command": output[6]}
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def codex_hook_owner():
    # Only inspect this hook's ancestors for producer liveness, never discover terminal sessions.
    pid = os.getppid()
    deadline = time.monotonic() + 0.4
    for _ in range(8):
        if pid <= 1 or time.monotonic() >= deadline:
            break
        info = codex_process_info(pid)
        if info is None:
            break
        if os.path.basename(info["command"]) == "codex":
            return info
        pid = info["parent"]
    return None


def same_codex_process(left, right):
    if left is None or right is None:
        return left is right
    return all(left[key] == right[key] for key in ("pid", "started", "command"))


def codex_owner_is_alive(owner):
    return owner is not None and same_codex_process(codex_process_info(owner["pid"]), owner)


def codex_state_key(session_id):
    # iTerm's UUID, not the Codex session id or an inherited inner TTY.
    return "iterm-" + str(uuid.UUID(session_id))


def ensure_codex_worker(state_file, state):
    now = time.time()
    if state.get("acknowledged") and (state["status"] != "running" or not state.get("ownerProcess")):
        return
    if state.get("lastError") == "rejected":
        return
    if state.get("workerToken") and 0 <= now - state.get("workerLease", 0) < 6:
        return
    token = str(uuid.uuid4())
    state["workerToken"] = token
    state["workerLease"] = now
    write_agent_state(state_file, state)
    try:
        subprocess.Popen(
            [sys.executable, os.path.realpath(__file__), "_codex_worker", state["itermSessionId"], token],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True, close_fds=True,
        )
    except OSError:
        state["workerToken"] = None
        state["lastError"] = "worker-start"
        write_agent_state(state_file, state)


def codex_provider_is_enabled(state):
    if not state.get("agentHooks"):
        return True
    try:
        with open(CODEX_AGENT_HOOKS_MARKER, encoding="utf-8") as marker_file:
            marker = json.load(marker_file)
        return isinstance(marker, dict) and marker.get("schema") == "itermate.codex-agent-hooks/v1" and marker.get("enabled") is True
    except (OSError, ValueError):
        return False


def run_codex_worker(session_id, token):
    key = codex_state_key(session_id)
    # Bound lock outages too; successful reads still require fresh lifecycle evidence.
    deadline = time.monotonic() + CODEX_OBSERVATION_MAX_AGE
    while time.monotonic() < deadline:
        time.sleep(2)
        try:
            state_file, state = locked_agent_state(key, timeout=1)
        except (OSError, TimeoutError):
            continue
        try:
            if state.get("workerToken") != token:
                return
            if (not codex_provider_is_enabled(state)
                    or not codex_state_is_fresh(state, time.time())
                    or (state.get("status") == "running" and state.get("ownerProcess")
                        and not codex_owner_is_alive(state["ownerProcess"]))
                    or (not state.get("ownerProcess")
                        and time.time() - state["observedAt"] > CODEX_DELIVERY_RETRY_AGE)):
                state["workerToken"] = None
                state["lastError"] = "observation-expired"
                write_agent_state(state_file, state)
                # Do not invent completion or renew stale running; Bridge's lease expires.
                return
            deadline = time.monotonic() + CODEX_OBSERVATION_MAX_AGE
            state["workerLease"] = time.time()
            accepted = send_codex_state(state)
            write_agent_state(state_file, state)
            if (accepted and (state["status"] != "running" or not state.get("ownerProcess"))) or state["lastError"] == "rejected":
                return
        finally:
            state_file.close()


def report_codex_iterm(event, session_id):
    owner = codex_hook_owner()
    try:
        state_file, previous = locked_agent_state(codex_state_key(session_id), timeout=1.2)
        try:
            state = apply_codex_event(previous, event, time.time(), owner)
            if state is None:
                return
            state["itermSessionId"] = session_id
            state["agentHooks"] = os.environ.get("AGENT_HOOKS_HOST") == "codex"
            # Keep transition and delivery under one lock: an old worker cannot send after Stop.
            write_agent_state(state_file, state)
            claim = event.get("hook_event_name") in {"SessionStart", "UserPromptSubmit"}
            send_codex_state(state, claim=claim)
            write_agent_state(state_file, state)
            ensure_codex_worker(state_file, state)
            if state.get("lastError"):
                print("iTermate Codex status: " + state["lastError"], file=sys.stderr)
        finally:
            state_file.close()
    except (OSError, ValueError, TimeoutError):
        print("iTermate Codex status: state-unavailable", file=sys.stderr)


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


def locked_agent_state(tty, timeout=None):
    path = agent_state_path(tty)
    state_file = open(path, "a+", encoding="utf-8")
    os.chmod(path, 0o600)
    if timeout is None:
        fcntl.flock(state_file, fcntl.LOCK_EX)
    else:
        deadline = time.monotonic() + timeout
        while True:
            try:
                fcntl.flock(state_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    state_file.close()
                    raise TimeoutError("Agent state is busy")
                time.sleep(0.02)
    state_file.seek(0)
    try:
        state = json.load(state_file)
        if not isinstance(state, dict):
            state = {}
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
            "agentHooks": os.environ.get("AGENT_HOOKS_HOST") == "codex",
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
        if (state.get("reporterId") != reporter_id or state.get("status") != "running"
                or not codex_provider_is_enabled(state)):
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
    if os.environ.get("ITERMATE_CODEX_WRAPPER") == "1":
        # The owned app-server stream is authoritative; hooks must not race it.
        return
    try:
        payload = sys.stdin.buffer.read(1024 * 1024 + 1)
        if len(payload) > 1024 * 1024:
            raise ValueError("Hook input too large")
        event = json.loads(payload)
        if not isinstance(event, dict):
            raise ValueError("Invalid hook input")
    except (ValueError, UnicodeError):
        print("iTermate Codex status: invalid-hook-input", file=sys.stderr)
        return
    session_id = iterm_session_id()
    if session_id is not None:
        report_codex_iterm(event, session_id)
        return
    # Preserve the existing TTY route; tool observations are only used by iTerm recovery.
    name = event.get("hook_event_name")
    if name in {"PreToolUse", "PostToolUse"}:
        return
    if name == "SessionStart" and event.get("source") not in {"startup", "resume", "clear"}:
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
    if len(sys.argv) == 4 and sys.argv[1] == "_codex_worker":
        try:
            run_codex_worker(sys.argv[2], sys.argv[3])
        except (OSError, ValueError):
            pass
        return
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
