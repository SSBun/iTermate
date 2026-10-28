import asyncio
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest


spec = importlib.util.spec_from_file_location(
    "focus_bridge", Path(__file__).with_name("iTermateBridge.py")
)
bridge_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge_module)
bridge_module.iterm2 = SimpleNamespace(
    FocusUpdateWindowChanged=SimpleNamespace(
        Reason=SimpleNamespace(TERMINAL_WINDOW_BECAME_KEY="key")
    )
)


class FocusAcknowledgementTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.session = SimpleNamespace(session_id="session")
        self.tab = SimpleNamespace(tab_id="tab", current_session=self.session,
                                   all_sessions=[self.session])
        self.window = SimpleNamespace(window_id="window", current_tab=self.tab, tabs=[self.tab])
        self.app = SimpleNamespace(app_active=True, current_window=self.window, windows=[self.window])
        self.bridge = bridge_module.Bridge(
            None, self.app, str(Path(self.directory.name) / "viewed.json")
        )

    def update(self, **fields):
        values = dict(application_active=None, window_changed=None,
                      selected_tab_changed=None, active_session_changed=None)
        values.update(fields)
        return SimpleNamespace(**values)

    def test_activation_events_target_current_pane(self):
        for event in (
            self.update(selected_tab_changed=SimpleNamespace(tab_id="tab")),
            self.update(active_session_changed=SimpleNamespace(session_id="session")),
            self.update(window_changed=SimpleNamespace(window_id="window", event="key")),
        ):
            with self.subTest(event=event):
                self.assertEqual(self.bridge.activated_session_id(event), "session")

    def test_focus_loss_and_background_changes_do_not_acknowledge(self):
        for event in (
            self.update(),
            # App activation may focus Preferences while retaining current_window.
            self.update(application_active=SimpleNamespace(application_active=True)),
            self.update(application_active=SimpleNamespace(application_active=False)),
            self.update(window_changed=SimpleNamespace(window_id="window", event="resigned")),
            self.update(window_changed=SimpleNamespace(window_id="window", event="current")),
            self.update(selected_tab_changed=SimpleNamespace(tab_id="background")),
            self.update(active_session_changed=SimpleNamespace(session_id="background")),
        ):
            self.assertIsNone(self.bridge.activated_session_id(event))
        self.app.app_active = False
        self.assertIsNone(self.bridge.activated_session_id(
            self.update(selected_tab_changed=SimpleNamespace(tab_id="tab"))
        ))

    def test_finished_only_and_completion_history_preserved(self):
        completion = {"id": "completion", "completedAt": 100, "exitStatus": 0}
        for status in ("running", "awaitingInput", "finished"):
            self.bridge.set_agent_status(
                "session", status, agent_kind="pi", completion_id="completion",
                recent_completions=[completion]
            )
            before = self.bridge.session_statuses["session"]
            self.bridge.clear_finished_status("session", expected_status=before)
            after = self.bridge.session_statuses["session"]
            self.assertEqual(after["status"], "idle" if status == "finished" else status)
            self.assertEqual(after["recentCompletions"], [completion])

    def test_new_completion_during_focus_refresh_is_not_cleared(self):
        self.bridge.set_agent_status("session", "finished", completion_id="old")
        old = self.bridge.session_statuses["session"]
        self.bridge.set_agent_status("session", "finished", completion_id="new")
        self.bridge.clear_finished_status("session", expected_status=old)
        self.assertEqual(self.bridge.session_statuses["session"]["status"], "finished")

    def test_monitor_refreshes_focus_before_acknowledging(self):
        bridge = self.bridge
        event = self.update(selected_tab_changed=SimpleNamespace(tab_id="tab"))
        bridge.set_agent_status("session", "finished", completion_id="old")
        self.app.current_window = None

        class Monitor:
            async def __aenter__(self):
                return self

            async def __aexit__(self, *args):
                return False

            async def async_get_next_update(self):
                return event

        async def refresh():
            self.app.current_window = self.window

        async def publish():
            raise asyncio.CancelledError()

        self.app.async_refresh_focus = refresh
        bridge.publish_snapshot = publish
        bridge_module.iterm2.FocusMonitor = lambda connection: Monitor()
        with self.assertRaises(asyncio.CancelledError):
            asyncio.run(bridge.monitor_focus())
        self.assertEqual(bridge.session_statuses["session"]["status"], "idle")
