#!/usr/bin/env python3

import asyncio
import fcntl
import json
import os
import sys

PROTOCOL_VERSION = 2
BRIDGE_VERSION = 2
SUPPORT_DIRECTORY = os.path.expanduser(
    "~/Library/Application Support/iTermate"
)
SOCKET_PATH = os.path.join(SUPPORT_DIRECTORY, "bridge.sock")
LOCK_PATH = os.path.join(SUPPORT_DIRECTORY, "bridge.lock")
SNAPSHOT_INTERVAL = 2


def acquire_process_lock():
    os.makedirs(SUPPORT_DIRECTORY, mode=0o700, exist_ok=True)
    os.chmod(SUPPORT_DIRECTORY, 0o700)
    lock_file = open(LOCK_PATH, "a+", encoding="utf-8")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock_file.close()
        return None
    return lock_file


def encode_message(message):
    return (json.dumps(message, ensure_ascii=False, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


class Bridge:
    def __init__(self, connection, app):
        self.connection = connection
        self.app = app
        self.clients = set()
        self.sequence = 0
        self.snapshot_lock = asyncio.Lock()

    async def run(self):
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        server = await asyncio.start_unix_server(self.handle_client, path=SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o600)

        await asyncio.gather(
            server.serve_forever(),
            self.monitor_layout(),
            self.monitor_focus(),
            self.publish_periodically(),
        )

    async def handle_client(self, reader, writer):
        self.clients.add(writer)
        try:
            await self.send(
                writer,
                {
                    "version": PROTOCOL_VERSION,
                    "type": "hello",
                    "bridgeVersion": BRIDGE_VERSION,
                },
            )
            await self.publish_snapshot(writer)

            while not reader.at_eof():
                line = await reader.readline()
                if not line:
                    break
                await self.handle_command(writer, line)
        except (ConnectionError, ValueError, json.JSONDecodeError):
            pass
        finally:
            self.clients.discard(writer)
            writer.close()
            try:
                await writer.wait_closed()
            except ConnectionError:
                pass

    async def handle_command(self, writer, line):
        request = json.loads(line)
        request_id = request.get("requestId")

        if request.get("version") != PROTOCOL_VERSION:
            await self.send_action_result(
                writer, request_id, False, "Unsupported protocol version"
            )
            return

        if request.get("type") != "activateSession":
            await self.send_action_result(writer, request_id, False, "Unknown action")
            return

        session_id = request.get("sessionId")
        if not isinstance(session_id, str) or not session_id or len(session_id) > 512:
            await self.send_action_result(writer, request_id, False, "Invalid session ID")
            return

        session = self.app.get_session_by_id(session_id)
        if session is None:
            await self.send_action_result(writer, request_id, False, "Session not found")
            return

        try:
            await session.async_activate()
        except Exception as error:
            await self.send_action_result(writer, request_id, False, str(error))
            return

        await self.send_action_result(writer, request_id, True, None)
        await self.publish_snapshot()

    async def send_action_result(self, writer, request_id, succeeded, error):
        message = {
            "version": PROTOCOL_VERSION,
            "type": "actionResult",
            "requestId": request_id,
            "ok": succeeded,
        }
        if error:
            message["error"] = error
        await self.send(writer, message)

    async def monitor_layout(self):
        async with iterm2.LayoutChangeMonitor(self.connection) as monitor:
            while True:
                await monitor.async_get()
                await self.publish_snapshot()

    async def monitor_focus(self):
        async with iterm2.FocusMonitor(self.connection) as monitor:
            while True:
                await monitor.async_get_next_update()
                await self.publish_snapshot()

    async def publish_periodically(self):
        while True:
            await asyncio.sleep(SNAPSHOT_INTERVAL)
            await self.publish_snapshot()

    async def publish_snapshot(self, target=None):
        if target is None and not self.clients:
            return

        async with self.snapshot_lock:
            snapshot = await self.build_snapshot()
            message = {
                "version": PROTOCOL_VERSION,
                "type": "snapshot",
                "sequence": self.next_sequence(),
                "windows": snapshot,
            }

            if target is not None:
                await self.send(target, message)
                return

            disconnected = []
            for writer in list(self.clients):
                try:
                    await self.send(writer, message)
                except ConnectionError:
                    disconnected.append(writer)
            for writer in disconnected:
                self.clients.discard(writer)

    async def build_snapshot(self):
        tab_pairs = [
            (window, tab)
            for window in self.app.windows
            for tab in window.tabs
        ]
        session_triplets = [
            (window, tab, session)
            for window, tab in tab_pairs
            for session in tab.all_sessions
        ]
        titles = await asyncio.gather(
            *(tab.async_get_variable("title") for _, tab in tab_pairs),
            return_exceptions=True,
        )
        paths = await asyncio.gather(
            *(
                session.async_get_variable("path")
                for _, _, session in session_triplets
            ),
            return_exceptions=True,
        )
        titles_by_tab = {
            tab.tab_id: title
            for (_, tab), title in zip(tab_pairs, titles)
            if isinstance(title, str) and title
        }
        paths_by_session = {
            session.session_id: path
            for (_, _, session), path in zip(session_triplets, paths)
            if isinstance(path, str) and path
        }

        active_window = self.app.current_window
        windows = []
        for window in self.app.windows:
            current_tab = window.current_tab
            tabs = []
            for tab in window.tabs:
                current_session = tab.current_session
                minimized_session_ids = {
                    session.session_id for session in tab.minimized_sessions
                }
                sessions = [
                    {
                        "id": session.session_id,
                        "name": session.name,
                        "path": paths_by_session.get(session.session_id),
                        "windowId": window.window_id,
                        "tabId": tab.tab_id,
                        "isActive": current_session is not None
                        and session.session_id == current_session.session_id,
                        "isMinimized": session.session_id in minimized_session_ids,
                    }
                    for session in tab.all_sessions
                ]
                fallback_title = current_session.name if current_session else "Tab"
                tabs.append(
                    {
                        "id": tab.tab_id,
                        "title": titles_by_tab.get(tab.tab_id, fallback_title),
                        "isSelected": current_tab is not None
                        and tab.tab_id == current_tab.tab_id,
                        "sessions": sessions,
                    }
                )

            windows.append(
                {
                    "id": window.window_id,
                    "number": window.window_number,
                    "isActive": active_window is not None
                    and window.window_id == active_window.window_id,
                    "tabs": tabs,
                }
            )
        return windows

    async def send(self, writer, message):
        writer.write(encode_message(message))
        await writer.drain()

    def next_sequence(self):
        self.sequence += 1
        return self.sequence


async def main(connection):
    app = await iterm2.async_get_app(connection)
    bridge = Bridge(connection, app)
    await bridge.run()


def self_test():
    encoded = encode_message(
        {
            "version": PROTOCOL_VERSION,
            "type": "activateSession",
            "sessionId": "session-1",
        }
    )
    assert encoded.endswith(b"\n")
    assert json.loads(encoded) == {
        "version": 2,
        "type": "activateSession",
        "sessionId": "session-1",
    }


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        import iterm2

        process_lock = acquire_process_lock()
        if process_lock is None:
            sys.exit(0)
        iterm2.run_forever(main, retry=True)
