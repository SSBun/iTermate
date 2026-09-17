#!/usr/bin/env python3

import asyncio
import fcntl
import json
import os
import shlex
import sys
import time

SUPPORT_DIRECTORY = os.path.expanduser(
    "~/Library/Application Support/iTermate"
)
SOCKET_PATH = os.path.join(SUPPORT_DIRECTORY, "bridge.sock")
LOCK_PATH = os.path.join(SUPPORT_DIRECTORY, "bridge.lock")
SNAPSHOT_INTERVAL = 2
AGENT_HEARTBEAT_TIMEOUT = 8


def heartbeat_time():
    return time.clock_gettime(time.CLOCK_MONOTONIC_RAW)


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
        self.agent_heartbeat_times = {}
        self.session_statuses = {}
        self.session_names = {}
        self.ignore_prompt_events_until = 0
        self.layout_reconcile_task = None

    async def run(self):
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        server = await asyncio.start_unix_server(self.handle_client, path=SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o600)

        await asyncio.gather(
            server.serve_forever(),
            self.monitor_iterm_connection(),
            self.monitor_layout(),
            self.monitor_focus(),
            self.monitor_commands(),
            self.publish_periodically(),
        )

    async def handle_client(self, reader, writer):
        self.clients.add(writer)
        try:
            await self.send(writer, {"type": "hello"})
            await self.refresh_after_wake()
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

        if action == "openProject":
            path = request.get("path")
            if (
                not isinstance(path, str)
                or not path
                or len(path) > 4096
                or "\0" in path
                or not os.path.isabs(path)
            ):
                await self.send_action_result(
                    writer, request_id, False, "Invalid project path"
                )
                return
            try:
                await self.open_project(path)
            except Exception as error:
                await self.send_action_result(writer, request_id, False, str(error))
                return
            await self.send_action_result(writer, request_id, True, None)
            await self.publish_snapshot()
            return

        session_id = request.get("sessionId")
        if not isinstance(session_id, str) or not session_id or len(session_id) > 512:
            await self.send_action_result(writer, request_id, False, "Invalid session ID")
            return

        if action == "setSessionStatus":
            status = request.get("status")
            if status not in {"idle", "running", "awaitingInput", "finished", "detached"}:
                await self.send_action_result(writer, request_id, False, "Invalid status")
                return
            exit_status = request.get("exitStatus", 0)
            if status == "finished" and (
                isinstance(exit_status, bool)
                or not isinstance(exit_status, int)
                or not 0 <= exit_status <= 255
            ):
                await self.send_action_result(
                    writer, request_id, False, "Invalid exit status"
                )
                return
            if status == "awaitingInput" and request.get("exitStatus") is not None:
                await self.send_action_result(
                    writer, request_id, False, "Invalid exit status"
                )
                return
            heartbeat = request.get("heartbeat", False)
            if not isinstance(heartbeat, bool) or (
                heartbeat and status not in {"running", "awaitingInput"}
            ):
                await self.send_action_result(
                    writer, request_id, False, "Invalid heartbeat"
                )
                return
            accepted = self.set_agent_status(session_id, status, exit_status, heartbeat)
            await self.send_action_result(
                writer, request_id, accepted,
                None if accepted else "Stale heartbeat"
            )
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
            "type": "actionResult",
            "requestId": request_id,
            "ok": succeeded,
        }
        if error:
            message["error"] = error
        await self.send(writer, message)

    async def open_project(self, path):
        for window in self.app.windows:
            for tab in window.tabs:
                for session in tab.all_sessions:
                    try:
                        session_path = await session.async_get_variable("path")
                    except Exception as error:
                        raise RuntimeError(
                            "Could not read iTerm2 session paths"
                        ) from error
                    if session_path == path:
                        await session.async_activate()
                        await self.app.async_activate(raise_all_windows=False)
                        self.clear_finished_status(session.session_id)
                        return

        if not os.path.isdir(path):
            raise ValueError("Favorite project folder no longer exists")

        profile = iterm2.LocalWriteOnlyProfile()
        profile.set_initial_directory_mode(
            iterm2.InitialWorkingDirectory.INITIAL_WORKING_DIRECTORY_CUSTOM
        )
        profile.set_custom_directory(path)

        window = self.app.current_window
        if window is None:
            window = await iterm2.Window.async_create(
                self.connection,
                profile_customizations=profile,
            )
            tab = window.current_tab if window is not None else None
        else:
            tab = await window.async_create_tab(profile_customizations=profile)

        if tab is None or tab.current_session is None:
            raise RuntimeError("Could not create iTerm2 session")
        await tab.current_session.async_activate()
        await self.app.async_activate(raise_all_windows=False)

    async def monitor_iterm_connection(self):
        await self.connection.websocket.wait_closed()
        raise ConnectionError("iTerm2 disconnected")

    async def monitor_layout(self):
        async with iterm2.LayoutChangeMonitor(self.connection) as monitor:
            while True:
                await monitor.async_get()
                self.ignore_prompt_events_until = (
                    heartbeat_time() + SNAPSHOT_INTERVAL
                )
                if self.layout_reconcile_task is not None:
                    self.layout_reconcile_task.cancel()
                self.layout_reconcile_task = asyncio.create_task(
                    self.reconcile_after_layout()
                )
                await self.publish_snapshot()

    async def reconcile_after_layout(self):
        await asyncio.sleep(SNAPSHOT_INTERVAL)
        await self.refresh_running_statuses(restore_commands=False)
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
                self.agent_heartbeat_times.pop(session_id, None)
                self.session_statuses.pop(session_id, None)

            await asyncio.sleep(1)

    async def current_prompt(self, session_id):
        try:
            return await iterm2.async_get_last_prompt(
                self.connection, session_id
            )
        except Exception:
            return None

    async def current_foreground_job(self, session_id):
        session = self.app.get_session_by_id(session_id)
        if session is None:
            return None
        try:
            job_name, command_line, shell = await asyncio.gather(
                session.async_get_variable("jobName"),
                session.async_get_variable("commandLine"),
                session.async_get_variable("shell"),
            )
        except Exception:
            return None
        if (
            not isinstance(job_name, str)
            or not isinstance(command_line, str)
            or not isinstance(shell, str)
            or not job_name
            or not shell
        ):
            return None
        job_name = os.path.basename(job_name).lstrip("-")
        shell = os.path.basename(shell).lstrip("-")
        return command_line, job_name != shell

    async def current_command_is_running(
        self,
        session_id,
        include_agent_commands=True,
    ):
        prompt = await self.current_prompt(session_id)
        if (
            prompt is not None
            and prompt.state == iterm2.PromptState.RUNNING
            and prompt.command
        ):
            command = prompt.command
        elif prompt is not None and not include_agent_commands:
            return False
        else:
            foreground_job = await self.current_foreground_job(session_id)
            if foreground_job is None or not foreground_job[1]:
                return False
            command = foreground_job[0]
        return include_agent_commands or not is_agent_command(command)

    async def refresh_after_wake(self):
        await self.refresh_running_statuses(restore_commands=True)

    async def refresh_running_statuses(self, restore_commands):
        self.expire_stale_agent_heartbeats(heartbeat_time())
        session_ids = self.current_session_ids()
        for session_id, status in list(self.session_statuses.items()):
            if (
                status.get("status") != "running"
                or session_id in self.agent_heartbeat_times
            ):
                continue
            if not await self.current_command_is_running(
                session_id,
                include_agent_commands=status.get("activityKind") == "agent",
            ):
                self.session_statuses.pop(session_id, None)
                self.agent_managed_session_ids.discard(session_id)
                self.agent_heartbeat_times.pop(session_id, None)

        if not restore_commands:
            return

        for session_id in session_ids - self.agent_managed_session_ids:
            if (
                session_id not in self.session_statuses
                and await self.current_command_is_running(
                    session_id,
                    include_agent_commands=False,
                )
            ):
                # ponytail: recovered commands are timed from observation;
                # use prompt timestamps if iTerm exposes them later.
                self.set_session_status(session_id, "running")

    async def monitor_session_commands(self, session_id):
        try:
            prompt = await self.current_prompt(session_id)
            if prompt is None:
                await self.monitor_session_foreground_job(session_id)
                return

            running_command = (
                prompt.command
                if prompt.state == iterm2.PromptState.RUNNING
                and prompt.command
                else None
            )
            observing_agent_command = (
                running_command is not None and is_agent_command(running_command)
            )
            observing_normal_command = (
                running_command is not None and not observing_agent_command
            )
            if (
                session_id not in self.agent_managed_session_ids
                and running_command is not None
                and not observing_agent_command
            ):
                # ponytail: recovered commands are timed from observation;
                # use prompt timestamps if iTerm exposes them later.
                self.set_session_status(session_id, "running")
                await self.publish_snapshot()

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
                    mode, value, prompt_id = await monitor.async_get(include_id=True)
                    if heartbeat_time() < self.ignore_prompt_events_until:
                        continue
                    current_prompt = await self.current_prompt(session_id)
                    if (
                        current_prompt is not None
                        and current_prompt.unique_id is not None
                        and prompt_id is not None
                        and current_prompt.unique_id != prompt_id
                    ):
                        continue
                    if mode == iterm2.PromptMonitor.Mode.COMMAND_START:
                        if (
                            current_prompt is not None
                            and current_prompt.state != iterm2.PromptState.RUNNING
                        ):
                            continue
                        foreground_job = await self.current_foreground_job(session_id)
                        if foreground_job is not None and (
                            not foreground_job[1]
                            or is_agent_command(foreground_job[0])
                            != is_agent_command(value)
                        ):
                            continue
                        observing_agent_command = is_agent_command(value)
                        if session_id in self.agent_managed_session_ids:
                            continue
                        observing_normal_command = not observing_agent_command
                        if observing_agent_command:
                            self.session_statuses.pop(session_id, None)
                        else:
                            self.set_session_status(session_id, "running")
                        await self.publish_snapshot()
                        continue

                    if mode != iterm2.PromptMonitor.Mode.COMMAND_END:
                        continue
                    if (
                        observing_agent_command
                        or session_id in self.agent_managed_session_ids
                    ):
                        observing_agent_command = False
                        was_managed = session_id in self.agent_managed_session_ids
                        had_running_status = self.session_statuses.get(
                            session_id, {}
                        ).get("status") == "running"
                        self.agent_managed_session_ids.discard(session_id)
                        self.agent_heartbeat_times.pop(session_id, None)
                        if was_managed or had_running_status:
                            self.session_statuses.pop(session_id, None)
                            await self.publish_snapshot()
                        continue

                    if not observing_normal_command:
                        continue
                    observing_normal_command = False
                    self.set_session_status(session_id, "finished", int(value))
                    await self.publish_snapshot()
        except asyncio.CancelledError:
            raise
        except Exception:
            self.command_monitor_unavailable.add(session_id)
        finally:
            if self.command_monitor_tasks.get(session_id) is asyncio.current_task():
                self.command_monitor_tasks.pop(session_id, None)

    async def monitor_session_foreground_job(self, session_id):
        observing_agent_command = False
        observing_normal_command = False
        async with iterm2.VariableMonitor(
            self.connection,
            iterm2.VariableScopes.SESSION,
            "jobPid",
            session_id,
        ) as monitor:
            while True:
                foreground_job = await self.current_foreground_job(session_id)
                if foreground_job is not None:
                    command, is_running = foreground_job
                    changed = False
                    if not is_running:
                        if (
                            observing_agent_command
                            or session_id in self.agent_managed_session_ids
                        ):
                            was_managed = (
                                session_id in self.agent_managed_session_ids
                            )
                            had_running_status = self.session_statuses.get(
                                session_id, {}
                            ).get("status") == "running"
                            self.agent_managed_session_ids.discard(session_id)
                            self.agent_heartbeat_times.pop(session_id, None)
                            if was_managed or had_running_status:
                                self.session_statuses.pop(session_id, None)
                            changed = was_managed or had_running_status
                        elif observing_normal_command:
                            self.set_session_status(session_id, "finished")
                            changed = True
                        observing_agent_command = False
                        observing_normal_command = False
                    elif is_agent_command(command):
                        observing_agent_command = True
                        observing_normal_command = False
                        if (
                            session_id not in self.agent_managed_session_ids
                            and session_id in self.session_statuses
                        ):
                            self.session_statuses.pop(session_id, None)
                            changed = True
                    elif (
                        session_id not in self.agent_managed_session_ids
                        and not observing_agent_command
                    ):
                        observing_normal_command = True
                        if self.session_statuses.get(session_id, {}).get(
                            "status"
                        ) != "running":
                            self.set_session_status(session_id, "running")
                            changed = True
                    if changed:
                        await self.publish_snapshot()
                await monitor.async_get()

    def set_agent_status(self, session_id, status, exit_status=0, heartbeat=False):
        if status == "detached":
            self.agent_managed_session_ids.discard(session_id)
            self.agent_heartbeat_times.pop(session_id, None)
            self.session_statuses.pop(session_id, None)
            return True

        current = self.session_statuses.get(session_id)
        if heartbeat and current is not None and current.get("status") != status:
            return False
        self.agent_managed_session_ids.add(session_id)
        if heartbeat or status == "awaitingInput":
            self.agent_heartbeat_times[session_id] = heartbeat_time()
        else:
            self.agent_heartbeat_times.pop(session_id, None)
        self.set_session_status(
            session_id,
            status,
            exit_status if status == "finished" else None,
            activity_kind="agent",
        )
        return True

    def expire_stale_agent_heartbeats(self, now):
        for session_id, last_heartbeat in list(self.agent_heartbeat_times.items()):
            if now - last_heartbeat <= AGENT_HEARTBEAT_TIMEOUT:
                continue
            self.agent_heartbeat_times.pop(session_id, None)
            if self.session_statuses.get(session_id, {}).get("status") in {
                "running", "awaitingInput"
            }:
                self.session_statuses.pop(session_id, None)

    def set_session_status(
        self,
        session_id,
        status,
        exit_status=None,
        activity_kind="command",
    ):
        current_status = self.session_statuses.get(session_id)
        changed_at = (
            current_status["statusChangedAt"]
            if current_status is not None and current_status["status"] == status
            else time.time()
        )
        self.session_statuses[session_id] = {
            "status": status,
            "activityKind": activity_kind,
            "exitStatus": exit_status,
            "statusChangedAt": changed_at,
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
        status = self.session_statuses.get(session_id)
        if status is None or status.get("status") != "finished":
            return
        if (
            status.get("activityKind") == "agent"
            and session_id in self.agent_managed_session_ids
        ):
            self.set_session_status(session_id, "idle", activity_kind="agent")
        else:
            self.session_statuses.pop(session_id, None)

    async def publish_periodically(self):
        last_tick = time.time()
        while True:
            await asyncio.sleep(SNAPSHOT_INTERVAL)
            now = time.time()
            if now - last_tick > SNAPSHOT_INTERVAL * 2:
                await self.refresh_after_wake()
            else:
                self.expire_stale_agent_heartbeats(heartbeat_time())
            last_tick = now
            await self.publish_snapshot()

    async def publish_snapshot(self, target=None):
        if target is None and not self.clients:
            return

        async with self.snapshot_lock:
            snapshot = await self.build_snapshot()
            message = {
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
            if isinstance(name, str) and name.strip()
        }
        for _, _, session in session_triplets:
            if session.session_id in names_by_session:
                continue
            cached_name = self.session_names.get(session.session_id)
            if cached_name:
                names_by_session[session.session_id] = cached_name
            elif isinstance(session.name, str) and session.name.strip():
                names_by_session[session.session_id] = session.name
        for _, tab in tab_pairs:
            if tab.current_session is not None and tab.tab_id in titles_by_tab:
                names_by_session[tab.current_session.session_id] = titles_by_tab[
                    tab.tab_id
                ]
        self.session_names = {
            session.session_id: names_by_session.get(session.session_id, "")
            for _, _, session in session_triplets
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
                        "name": self.session_names[session.session_id],
                        "path": paths_by_session.get(session.session_id),
                        "windowId": window.window_id,
                        "tabId": tab.tab_id,
                        "isActive": session.session_id == active_session_id,
                        "isMinimized": session.session_id in minimized_session_ids,
                        "status": self.session_statuses.get(session.session_id, {}).get(
                            "status"
                        ),
                        "activityKind": self.session_statuses.get(
                            session.session_id, {}
                        ).get("activityKind"),
                        "exitStatus": self.session_statuses.get(
                            session.session_id, {}
                        ).get("exitStatus"),
                        "statusChangedAt": self.session_statuses.get(
                            session.session_id, {}
                        ).get("statusChangedAt"),
                    }
                    for session in tab.all_sessions
                ]
                fallback_title = (
                    self.session_names[current_session.session_id]
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
    assert is_agent_command("pi")
    assert is_agent_command("/usr/local/bin/codex --resume")
    assert not is_agent_command("python3 build.py")

    class FakeSession:
        session_id = "session-1"
        name = "Cached title"

        def __init__(self):
            self.closed = False
            self.current_name = "Current title"
            self.job_name = "zsh"
            self.command_line = "zsh --login"
            self.shell = "zsh"
            self.job_pid = 100

        async def async_get_variable(self, name):
            return {
                "name": self.current_name,
                "path": "/tmp",
                "jobName": self.job_name,
                "commandLine": self.command_line,
                "shell": self.shell,
                "jobPid": self.job_pid,
            }[name]

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
            self.current_title = ""

        async def async_get_variable(self, name):
            assert name == "title"
            return self.current_title

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

    class FakeWebSocket:
        async def wait_closed(self):
            pass

    class FakeConnection:
        websocket = FakeWebSocket()

    class FakeWriter:
        def __init__(self):
            self.messages = []

        def write(self, message):
            self.messages.append(json.loads(message))

        async def drain(self):
            pass

        def close(self):
            pass

        async def wait_closed(self):
            pass

    session = FakeSession()
    tab = FakeTab(session)
    window = FakeWindow(tab)
    app = FakeApp(window, session)
    bridge = Bridge(None, app)
    try:
        asyncio.run(Bridge(FakeConnection(), app).monitor_iterm_connection())
        assert False, "Closed iTerm2 connection should stop the Bridge"
    except ConnectionError:
        pass

    snapshot = asyncio.run(bridge.build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["name"] == "Current title"
    assert snapshot[0]["tabs"][0]["title"] == "Current title"

    bridge.set_session_status("session-1", "running")
    snapshot = asyncio.run(bridge.build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["activityKind"] == "command"
    bridge.set_agent_status("session-1", "running")
    snapshot = asyncio.run(bridge.build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["activityKind"] == "agent"
    bridge.set_agent_status("session-1", "detached")

    session.current_name = ""
    session.name = "caishilin (python)"
    snapshot = asyncio.run(bridge.build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["name"] == "Current title"

    session.current_name = "caishilin (zsh)"
    tab.current_title = "Current title"
    snapshot = asyncio.run(bridge.build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["name"] == "Current title"

    second_tab = FakeTab(SecondFakeSession())
    second_tab.tab_id = "tab-2"
    window.tabs.append(second_tab)
    snapshot = asyncio.run(Bridge(None, app).build_snapshot())
    assert snapshot[0]["tabs"][0]["sessions"][0]["isActive"]
    assert not snapshot[0]["tabs"][1]["sessions"][0]["isActive"]

    class FakePrompt:
        def __init__(self, state, command, unique_id):
            self.state = state
            self.command = command
            self.unique_id = unique_id

    class FakePromptMonitor:
        class Mode:
            COMMAND_START = "command-start"
            COMMAND_END = "command-end"

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return False

        async def async_get(self):
            raise asyncio.CancelledError

    class FakeIterm2:
        PromptState = type("PromptState", (), {"RUNNING": "running"})
        PromptMonitor = FakePromptMonitor
        prompt_state = "running"
        prompt_command = "python3 build.py"
        prompt_id = "prompt-1"
        prompt_available = True

        @staticmethod
        async def async_get_last_prompt(_, __):
            if not FakeIterm2.prompt_available:
                return None
            return FakePrompt(
                FakeIterm2.prompt_state,
                FakeIterm2.prompt_command,
                FakeIterm2.prompt_id,
            )

    globals()["iterm2"] = FakeIterm2
    bridge = Bridge(None, app)
    try:
        asyncio.run(bridge.monitor_session_commands("session-1"))
    except asyncio.CancelledError:
        pass
    assert bridge.session_statuses["session-1"]["status"] == "running"
    assert bridge.session_statuses["session-1"]["activityKind"] == "command"

    FakeIterm2.prompt_state = "editing"
    session.job_name = "node"
    session.command_line = "node /usr/local/bin/pi"
    editing_prompt_bridge = Bridge(None, app)
    try:
        asyncio.run(editing_prompt_bridge.monitor_session_commands("session-1"))
    except asyncio.CancelledError:
        pass
    assert "session-1" not in editing_prompt_bridge.session_statuses

    class ScriptedPromptMonitor:
        Mode = FakePromptMonitor.Mode
        events = []

        def __init__(self, *_):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return False

        async def async_get(self, include_id=False):
            if not self.events:
                raise asyncio.CancelledError
            mode, value, prompt_id, update = self.events.pop(0)
            update()
            if include_id:
                return mode, value, prompt_id
            return mode, value

    class RecordingBridge(Bridge):
        def __init__(self, connection, app):
            super().__init__(connection, app)
            self.published_statuses = []

        async def publish_snapshot(self, target=None):
            self.published_statuses.append(
                self.session_statuses.get("session-1", {}).get("status")
            )

    FakeIterm2.PromptMonitor = ScriptedPromptMonitor
    FakeIterm2.prompt_state = "editing"
    FakeIterm2.prompt_command = ""
    FakeIterm2.prompt_id = "current-prompt"
    session.job_name = "zsh"
    session.command_line = "zsh --login"
    stale_start_bridge = RecordingBridge(None, app)
    ScriptedPromptMonitor.events = [
        (
            ScriptedPromptMonitor.Mode.COMMAND_START,
            "npm run dev",
            "current-prompt",
            lambda: (
                setattr(FakeIterm2, "prompt_state", "running"),
                setattr(FakeIterm2, "prompt_command", "npm run dev"),
            ),
        ),
        (
            ScriptedPromptMonitor.Mode.COMMAND_END,
            0,
            "current-prompt",
            lambda: setattr(FakeIterm2, "prompt_state", "editing"),
        ),
    ]
    try:
        asyncio.run(stale_start_bridge.monitor_session_commands("session-1"))
    except asyncio.CancelledError:
        pass
    assert stale_start_bridge.published_statuses == []

    ignored_event_bridge = RecordingBridge(None, app)
    ignored_event_bridge.ignore_prompt_events_until = heartbeat_time() + 1
    session.job_name = "node"
    session.command_line = "npm run dev"
    ScriptedPromptMonitor.events = [
        (
            ScriptedPromptMonitor.Mode.COMMAND_START,
            "npm run dev",
            "current-prompt",
            lambda: None,
        ),
    ]
    try:
        asyncio.run(ignored_event_bridge.monitor_session_commands("session-1"))
    except asyncio.CancelledError:
        pass
    assert ignored_event_bridge.published_statuses == []

    FakeIterm2.prompt_state = "running"
    FakeIterm2.prompt_command = "pi"
    FakeIterm2.prompt_id = "agent-prompt"
    session.job_name = "node"
    session.command_line = "node /usr/local/bin/pi"
    agent_command_bridge = RecordingBridge(None, app)
    agent_command_bridge.set_agent_status("session-1", "idle")
    agent_command_bridge.set_agent_status("session-1", "detached")
    ScriptedPromptMonitor.events = [
        (
            ScriptedPromptMonitor.Mode.COMMAND_END,
            0,
            "agent-prompt",
            lambda: setattr(FakeIterm2, "prompt_state", "editing"),
        ),
        (
            ScriptedPromptMonitor.Mode.COMMAND_START,
            "npm run dev",
            "command-prompt",
            lambda: (
                setattr(FakeIterm2, "prompt_state", "running"),
                setattr(FakeIterm2, "prompt_command", "npm run dev"),
                setattr(FakeIterm2, "prompt_id", "command-prompt"),
                setattr(session, "command_line", "npm run dev"),
            ),
        ),
        (
            ScriptedPromptMonitor.Mode.COMMAND_END,
            0,
            "command-prompt",
            lambda: setattr(FakeIterm2, "prompt_state", "editing"),
        ),
    ]
    try:
        asyncio.run(agent_command_bridge.monitor_session_commands("session-1"))
    except asyncio.CancelledError:
        pass
    assert agent_command_bridge.published_statuses == [
        "running",
        "finished",
    ], agent_command_bridge.published_statuses

    class ScriptedVariableMonitor:
        events = []

        def __init__(self, *_):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return False

        async def async_get(self):
            if not self.events:
                raise asyncio.CancelledError
            update = self.events.pop(0)
            update()
            return session.job_pid

    def set_foreground_job(job_name, command_line, job_pid):
        session.job_name = job_name
        session.command_line = command_line
        session.job_pid = job_pid

    FakeIterm2.VariableMonitor = ScriptedVariableMonitor
    FakeIterm2.VariableScopes = type("VariableScopes", (), {"SESSION": "session"})
    FakeIterm2.PromptMonitor = FakePromptMonitor
    FakeIterm2.prompt_available = False
    set_foreground_job(
        "node",
        "node /usr/local/bin/venom-cli build --run --debug",
        101,
    )
    ScriptedVariableMonitor.events = [
        lambda: set_foreground_job("zsh", "zsh --login", 100),
    ]
    foreground_bridge = RecordingBridge(None, app)
    try:
        asyncio.run(foreground_bridge.monitor_session_commands("session-1"))
    except asyncio.CancelledError:
        pass
    assert foreground_bridge.published_statuses == [
        "running",
        "finished",
    ], foreground_bridge.published_statuses
    assert foreground_bridge.session_statuses["session-1"]["exitStatus"] is None
    assert foreground_bridge.session_statuses["session-1"]["activityKind"] == "command"

    set_foreground_job("node", 'pi ""', 102)
    ScriptedVariableMonitor.events = [
        lambda: set_foreground_job("zsh", "zsh --login", 100),
        lambda: set_foreground_job("node", "npm run dev", 103),
        lambda: set_foreground_job("zsh", "zsh --login", 100),
    ]
    agent_foreground_bridge = RecordingBridge(None, app)
    agent_foreground_bridge.set_agent_status("session-1", "idle")
    agent_foreground_bridge.set_agent_status("session-1", "detached")
    try:
        asyncio.run(
            agent_foreground_bridge.monitor_session_commands("session-1")
        )
    except asyncio.CancelledError:
        pass
    assert agent_foreground_bridge.published_statuses == [
        "running",
        "finished",
    ], agent_foreground_bridge.published_statuses

    FakeIterm2.prompt_available = True
    FakeIterm2.PromptMonitor = FakePromptMonitor
    FakeIterm2.prompt_state = "finished"
    FakeIterm2.prompt_command = "python3 build.py"
    wake_bridge = Bridge(None, app)
    wake_bridge.agent_managed_session_ids.add("session-1")
    wake_bridge.set_session_status("session-1", "running")
    asyncio.run(wake_bridge.refresh_after_wake())
    assert "session-1" not in wake_bridge.session_statuses
    assert "session-1" not in wake_bridge.agent_managed_session_ids

    heartbeat_wake_bridge = Bridge(None, app)
    heartbeat_wake_bridge.set_agent_status(
        "session-1", "running", heartbeat=True
    )
    asyncio.run(heartbeat_wake_bridge.refresh_after_wake())
    assert heartbeat_wake_bridge.session_statuses["session-1"]["status"] == "running"

    heartbeat_now = [100.0]
    original_heartbeat_time = globals()["heartbeat_time"]
    globals()["heartbeat_time"] = lambda: heartbeat_now[0]
    try:
        sleeping_heartbeat_bridge = Bridge(None, app)
        sleeping_heartbeat_bridge.set_agent_status(
            "session-1", "running", heartbeat=True
        )
        heartbeat_now[0] += AGENT_HEARTBEAT_TIMEOUT + 1
        asyncio.run(sleeping_heartbeat_bridge.refresh_after_wake())
        assert "session-1" not in sleeping_heartbeat_bridge.session_statuses
    finally:
        globals()["heartbeat_time"] = original_heartbeat_time

    FakeIterm2.prompt_state = "running"
    FakeIterm2.prompt_command = "python3 build.py"
    layout_bridge = RecordingBridge(None, app)
    original_sleep = asyncio.sleep

    async def immediate_sleep(_):
        pass

    asyncio.sleep = immediate_sleep
    try:
        asyncio.run(layout_bridge.reconcile_after_layout())
    finally:
        asyncio.sleep = original_sleep
    assert layout_bridge.published_statuses == [None], (
        layout_bridge.published_statuses
    )

    wake_bridge = Bridge(None, app)
    wake_bridge.agent_managed_session_ids.add("session-1")
    wake_bridge.set_session_status("session-1", "running")
    asyncio.run(wake_bridge.refresh_after_wake())
    assert wake_bridge.session_statuses["session-1"]["status"] == "running"

    ordinary_prompt_bridge = Bridge(None, app)
    asyncio.run(ordinary_prompt_bridge.refresh_after_wake())
    assert ordinary_prompt_bridge.session_statuses["session-1"]["status"] == "running"

    FakeIterm2.prompt_command = "pi"
    agent_prompt_bridge = Bridge(None, app)
    asyncio.run(agent_prompt_bridge.refresh_after_wake())
    assert "session-1" not in agent_prompt_bridge.session_statuses

    FakeIterm2.prompt_state = "editing"
    set_foreground_job("node", "node /usr/local/bin/pi", 102)
    stale_agent_command_bridge = Bridge(None, app)
    stale_agent_command_bridge.set_session_status("session-1", "running")
    asyncio.run(stale_agent_command_bridge.refresh_after_wake())
    assert "session-1" not in stale_agent_command_bridge.session_statuses

    FakeIterm2.prompt_command = ""
    unknown_prompt_bridge = Bridge(None, app)
    asyncio.run(unknown_prompt_bridge.refresh_after_wake())
    assert "session-1" not in unknown_prompt_bridge.session_statuses

    FakeIterm2.prompt_state = "finished"
    reconnect_bridge = Bridge(None, app)
    reconnect_bridge.agent_managed_session_ids.add("session-1")
    reconnect_bridge.set_session_status("session-1", "running")

    class FakeReader:
        def at_eof(self):
            return True

    reconnect_writer = FakeWriter()
    asyncio.run(reconnect_bridge.handle_client(FakeReader(), reconnect_writer))
    assert "session-1" not in reconnect_bridge.session_statuses
    assert reconnect_writer.messages[0]["type"] == "hello"
    assert reconnect_writer.messages[1]["type"] == "snapshot"
    del globals()["iterm2"]

    writer = FakeWriter()
    asyncio.run(
        Bridge(None, app).handle_command(
            writer,
            encode_message(
                {
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
            "type": "actionResult",
            "requestId": "request-1",
            "ok": True,
        }
    ]

    bridge.set_agent_status("session-1", "running")
    started_at = bridge.session_statuses["session-1"]["statusChangedAt"]
    bridge.set_agent_status("session-1", "running")
    assert bridge.session_statuses["session-1"]["statusChangedAt"] == started_at
    bridge.expire_stale_agent_heartbeats(time.monotonic() + 100)
    assert bridge.session_statuses["session-1"]["status"] == "running"
    assert bridge.session_statuses["session-1"]["activityKind"] == "agent"

    heartbeat_bridge = Bridge(None, app)
    writer = FakeWriter()
    asyncio.run(
        heartbeat_bridge.handle_command(
            writer,
            encode_message(
                {
                    "type": "setSessionStatus",
                    "requestId": "request-heartbeat",
                    "sessionId": "session-1",
                    "status": "running",
                    "heartbeat": True,
                }
            ),
        )
    )
    heartbeat_at = heartbeat_bridge.agent_heartbeat_times["session-1"]
    heartbeat_started_at = heartbeat_bridge.session_statuses["session-1"][
        "statusChangedAt"
    ]
    heartbeat_bridge.set_agent_status("session-1", "running", heartbeat=True)
    assert writer.messages[0]["ok"]
    assert (
        heartbeat_bridge.session_statuses["session-1"]["statusChangedAt"]
        == heartbeat_started_at
    )

    heartbeat_bridge.set_agent_status("session-1", "finished")
    heartbeat_bridge.expire_stale_agent_heartbeats(
        heartbeat_at + AGENT_HEARTBEAT_TIMEOUT + 1
    )
    assert heartbeat_bridge.session_statuses["session-1"]["status"] == "finished"

    assert not heartbeat_bridge.set_agent_status(
        "session-1", "running", heartbeat=True
    )
    assert heartbeat_bridge.session_statuses["session-1"]["status"] == "finished"
    assert "session-1" not in heartbeat_bridge.agent_heartbeat_times
    assert heartbeat_bridge.set_agent_status("session-1", "running")
    assert heartbeat_bridge.set_agent_status("session-1", "running", heartbeat=True)
    heartbeat_at = heartbeat_bridge.agent_heartbeat_times["session-1"]
    heartbeat_bridge.expire_stale_agent_heartbeats(
        heartbeat_at + AGENT_HEARTBEAT_TIMEOUT + 1
    )
    assert "session-1" not in heartbeat_bridge.session_statuses
    assert "session-1" not in heartbeat_bridge.agent_heartbeat_times
    assert "session-1" in heartbeat_bridge.agent_managed_session_ids

    bridge.set_agent_status("session-1", "finished")
    assert bridge.session_statuses["session-1"]["exitStatus"] == 0
    assert isinstance(bridge.session_statuses["session-1"]["statusChangedAt"], float)

    writer = FakeWriter()
    asyncio.run(
        bridge.handle_command(
            writer,
            encode_message(
                {
                    "type": "setSessionStatus",
                    "requestId": "request-3",
                    "sessionId": "session-1",
                    "status": "finished",
                    "exitStatus": 1,
                }
            ),
        )
    )
    assert bridge.session_statuses["session-1"]["exitStatus"] == 1
    assert writer.messages[0]["ok"]
    bridge.clear_finished_status("session-1")
    assert bridge.session_statuses["session-1"]["status"] == "idle"
    assert bridge.session_statuses["session-1"]["activityKind"] == "agent"
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
