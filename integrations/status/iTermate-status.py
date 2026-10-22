#!/usr/bin/env python3

import json
import os
import socket
import sys
import uuid

STATUS_SOCKET_PATH = os.path.expanduser(
    "~/Library/Application Support/iTermate/status.sock"
)


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


def exchange(request):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(1)
            client.connect(STATUS_SOCKET_PATH)
            client.sendall(
                (json.dumps(request, separators=(",", ":")) + "\n").encode("utf-8")
            )
    except (OSError, TimeoutError):
        pass


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

    request = {
        "version": 1,
        "type": "setTerminalStatus",
        "requestId": str(uuid.uuid4()),
        "tty": tty,
        "source": "command",
        "reporterId": reporter_id,
        "sequence": sequence,
        "status": status,
        "heartbeat": False,
    }
    if status == "finished":
        request["exitStatus"] = exit_status
    exchange(request)


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "shell":
        report_shell(sys.argv[2:])


if __name__ == "__main__":
    main()
