#!/usr/bin/env python3

import json
import os
import socket
import sys
import uuid

SOCKET_PATH = os.path.expanduser(
    "~/Library/Application Support/iTermate/bridge.sock"
)


def iterm_session_id():
    value = os.environ.get("ITERM_SESSION_ID") or os.environ.get("TERM_SESSION_ID")
    return value.rsplit(":", 1)[-1] if value else None


def main():
    sys.stdin.buffer.read()

    if len(sys.argv) != 2 or sys.argv[1] not in {
        "idle",
        "running",
        "finished",
        "detached",
    }:
        return

    session_id = iterm_session_id()
    if session_id is None:
        return

    request = {
        "version": 5,
        "type": "setSessionStatus",
        "requestId": str(uuid.uuid4()),
        "sessionId": session_id,
        "status": sys.argv[1],
    }

    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(1)
            client.connect(SOCKET_PATH)
            stream = client.makefile("rb")
            stream.readline()
            stream.readline()
            client.sendall(
                (json.dumps(request, separators=(",", ":")) + "\n").encode("utf-8")
            )
    except (OSError, TimeoutError):
        pass


if __name__ == "__main__":
    main()
