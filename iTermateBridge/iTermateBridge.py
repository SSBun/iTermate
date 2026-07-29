#!/usr/bin/env python3

import asyncio
import fcntl
import json
import os
import shlex
import sys

PROTOCOL_VERSION = 5
BRIDGE_VERSION = 5
SUPPORT_DIRECTORY = os.path.expanduser(
    "~/Library/Application Support/iTermate"
)
SOCKET_PATH = os.path.join(SUPPORT_DIRECTORY, "bridge.sock")
LOCK_PATH = os.path.join(SUPPORT_DIRECTORY, "bridge.lock")
SNAPSHOT_INTERVAL = 2


def is_agent_command(command):
    try:
        executable = shlex.split(command)[0]
    except (IndexError, ValueError):
        return False
    return os.path.basename(executable) in {"pi", "codex"}


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
        self.command_monitor_tasks = {}
        self.command_monitor_unavailable = set()
        self.agent_managed_session_ids = set()
        self.session_statuses = {}

    async def run(self):
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        server = await asyncio.start_unix_server(self.handle_client, path=SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o600)

        await asyncio.gather(
            server.serve_forever(),
            self.monitor_layout(),
            self.monitor_focus(),
            self.monitor_commands(),
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
        action = request.get("type")

        # Enabled integrations are not reinstalled automatically when the app updates.
        if request.get("version") != PROTOCOL_VERSION and not (
            action == "setSessionStatus" and request.get("version") == 4
        ):
            await self.send_action_result(
                writer, request_id, False, "Unsupported protocol version"
            )
            return

        session_id = request.get("sessionId")
        if not isinstance(session_id, str) or not session_id or len(session_id) > 512:
            await self.send_action_result(writer, request_id, False, "Invalid session ID")
            return

        if action == "setSessionStatus":
            status = request.get("status")
            if status not in {"idle", "running", "finished", "detached"}:
                await self.send_action_result(writer, request_id, False, "Invalid status")
                return
            self.set_agent_status(session_id, status)
            await self.send_action_result(writer, request_id, True, None)
            await self.publish_snapshot()
            return

        if action not in {"activateSession", "closeSession"}:
            await self.send_action_result(writer, request_id, False, "Unknown action")
            return

        session = self.app.get_session_by_id(session_id)
        if session is None:
            await self.send_action_result(writer, request_id, False, "Session not found")
            return

        try:
            if action == "closeSession":
                await session.async_close()
            else:
                await session.async_activate()
                await self.app.async_activate(raise_all_windows=False)
        except Exception as error:
            await self.send_action_result(writer, request_id, False, str(error))
            return

        if action == "activateSession":
            self.clear_finished_status(session_id)
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
                self.clear_finished_status(self.current_active_session_id())
                await self.publish_snapshot()

    async def monitor_commands(self):
        while True:
            session_ids = self.current_session_ids()
            monitored_ids = set(self.command_monitor_tasks)
            for session_id in session_ids - monitored_ids - self.command_monitor_unavailable:
                self.command_monitor_tasks[session_id] = asyncio.create_task(
                    self.monitor_session_commands(session_id)
                )

            for session_id in monitored_ids - session_ids:
                self.command_monitor_tasks.pop(session_id).cancel()
                self.command_monitor_unavailable.discard(session_id)
                self.agent_managed_session_ids.discard(session_id)
                self.session_statuses.pop(session_id, None)

            await asyncio.sleep(1)

    async def monitor_session_commands(self, session_id):
        try:
            modes = [
                iterm2.PromptMonitor.Mode.COMMAND_START,
                iterm2.PromptMonitor.Mode.COMMAND_END,
            ]
            async with iterm2.PromptMonitor(
                self.connection,
                session_id,
                modes,
            ) as monitor:
                while True:
                    mode, value = await monitor.async_get()
                    if session_id in self.agent_managed_session_ids:
                        continue
                    if mode == iterm2.PromptMonitor.Mode.COMMAND_START:
                        if is_agent_command(value):
                            self.session_statuses.pop(session_id, None)
                        else:
                            self.session_statuses[session_id] = {
                                "status": "running",
                                "exitStatus": None,
                            }
                    elif mode == iterm2.PromptMonitor.Mode.COMMAND_END:
                        self.session_statuses[session_id] = {
                            "status": "finished",
                            "exitStatus": int(value),
                        }
                    else:
                        continue
                    await self.publish_snapshot()
        except asyncio.CancelledError:
            raise
        except Exception:
            self.command_monitor_unavailable.add(session_id)
        finally:
            if self.command_monitor_tasks.get(session_id) is asyncio.current_task():
                self.command_monitor_tasks.pop(session_id, None)

    def set_agent_status(self, session_id, status):
        if status == "detached":
            self.agent_managed_session_ids.discard(session_id)
            self.session_statuses.pop(session_id, None)
            return

        self.agent_managed_session_ids.add(session_id)
        if status == "idle":
            self.session_statuses.pop(session_id, None)
            return

        self.session_statuses[session_id] = {
            "status": status,
            "exitStatus": 0 if status == "finished" else None,
        }

    def current_session_ids(self):
        return {
            session.session_id
            for window in self.app.windows
            for tab in window.tabs
            for session in tab.all_sessions
        }

    def current_active_session_id(self):
        window = self.app.current_window
        if window is None or window.current_tab is None:
            return None
        session = window.current_tab.current_session
        return session.session_id if session is not None else None

    def clear_finished_status(self, session_id):
        if session_id is not None and self.session_statuses.get(session_id, {}).get(
            "status"
        ) == "finished":
            self.session_statuses.pop(session_id, None)

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
        names = await asyncio.gather(
            *(
                session.async_get_variable("name")
                for _, _, session in session_triplets
            ),
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
        names_by_session = {
            session.session_id: name
            for (_, _, session), name in zip(session_triplets, names)
            if isinstance(name, str) and name
        }
        paths_by_session = {
            session.session_id: path
            for (_, _, session), path in zip(session_triplets, paths)
            if isinstance(path, str) and path
        }

        active_window = self.app.current_window
        active_tab = active_window.current_tab if active_window is not None else None
        active_session = (
            active_tab.current_session if active_tab is not None else None
        )
        active_session_id = (
            active_session.session_id if active_session is not None else None
        )
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
                        "name": names_by_session.get(session.session_id, session.name),
                        "path": paths_by_session.get(session.session_id),
                        "windowId": window.window_id,
                        "tabId": tab.tab_id,
                        "isActive": session.session_id == active_session_id,
                        "isMinimized": session.session_id in minimized_session_ids,
                        "status": self.session_statuses.get(session.session_id, {}).get(
                            "status"
                        ),
                        "exitStatus": self.session_statuses.get(
                            session.session_id, {}
                        ).get("exitStatus"),
                    }
                    for session in tab.all_sessions
                ]
                fallback_title = (
                    names_by_session.get(current_session.session_id, current_session.name)
                    if current_session
                    else "Tab"
                )
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
        "version": 5,
        "type": "activateSession",
        "sessionId": "session-1",
    }

    assert is_agent_command("pi")
    assert is_agent_command("/usr/local/bin/codex --resume")
    assert not is_agent_command("python3 build.py")

    class FakeSession:
        session_id = "session-1"
        name = "Cached title"

        def __init__(self):
            self.closed = False

        async def async_get_variable(self, name):
            return {"name": "Current title", "path": "/tmp"}[name]

        async def async_close(self, force=False):
            assert not force
            self.closed = True

    class SecondFakeSession(FakeSession):
        session_id = "session-2"
        name = "Second title"

    class FakeTab:
        tab_id = "tab-1"
        minimized_sessions = []

        def __init__(self, session):
            self.all_sessions = [session]
            self.current_session = session

        async def async_get_variable(self, name):
            assert name == "title"
            return ""

    class FakeWindow:
        window_id = "window-1"
        window_number = 1

        def __init__(self, tab):
            self.tabs = [tab]
            self.current_tab = tab

    class FakeApp:
        def __init__(self, window, session):
            self.windows = [window]
            self.current_window = window
            self.session = session

        def get_session_by_id(self, session_id):
            return self.session if session_id == self.session.session_id else None

    class FakeWriter:
        def __init__(self):
            self.messages = []

        def write(self, message):
            self.messages.append(json.loads(message))

        async def drain(self):
            pass

    session = FakeSession()
    tab = FakeTab(session)
    window = FakeWindow(tab)
    app = FakeApp(window, session)
    snapshot = asyncio.run(Bridge(None, app).build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["name"] == "Current title"
    assert snapshot[0]["tabs"][0]["title"] == "Current title"

    second_tab = FakeTab(SecondFakeSession())
    second_tab.tab_id = "tab-2"
    window.tabs.append(second_tab)
    snapshot = asyncio.run(Bridge(None, app).build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["isActive"]
    assert not snapshot[0]["tabs"][1]["sessions"][0]["isActive"]

    writer = FakeWriter()
    asyncio.run(
        Bridge(None, app).handle_command(
            writer,
            encode_message(
                {
                    "version": PROTOCOL_VERSION,
                    "type": "closeSession",
                    "requestId": "request-1",
                    "sessionId": "session-1",
                }
            ),
        )
    )
    assert session.closed
    assert writer.messages == [
        {
            "version": PROTOCOL_VERSION,
            "type": "actionResult",
            "requestId": "request-1",
            "ok": True,
        }
    ]

    bridge = Bridge(None, None)
    writer = FakeWriter()
    asyncio.run(
        bridge.handle_command(
            writer,
            encode_message(
                {
                    "version": 4,
                    "type": "setSessionStatus",
                    "requestId": "request-2",
                    "sessionId": "session-1",
                    "status": "running",
                }
            ),
        )
    )
    assert bridge.session_statuses["session-1"]["status"] == "running"
    assert writer.messages[0]["ok"]
    bridge.set_agent_status("session-1", "finished")
    assert bridge.session_statuses["session-1"]["exitStatus"] == 0
    bridge.clear_finished_status("session-1")
    assert "session-1" not in bridge.session_statuses
    assert "session-1" in bridge.agent_managed_session_ids
    bridge.set_agent_status("session-1", "detached")
    assert "session-1" not in bridge.agent_managed_session_ids


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        import iterm2

        process_lock = acquire_process_lock()
        if process_lock is None:
            sys.exit(0)
        iterm2.run_forever(main, retry=True)
