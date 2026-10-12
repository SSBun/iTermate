import asyncio
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location("bridge_source", Path(__file__).with_name("iTermateBridge.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RecordingBridge(module.Bridge):
    def __init__(self):
        super().__init__(None, SimpleNamespace(get_session_by_id=lambda _: object()))
        self.responses = []
        self.snapshots = 0

    async def send_action_result(self, writer, request_id, ok, error):
        self.responses.append((ok, error))

    async def publish_snapshot(self, target=None):
        self.snapshots += 1

    def report(self, status, sequence=1, recovery=False, **extra):
        payload = dict(type="setSessionStatus", sessionId="pane", status=status,
                       reporterId="pi-instance", sequence=sequence, recovery=recovery, **extra)
        asyncio.run(self.handle_command(None, json.dumps(payload).encode()))
        return self.responses[-1][0]


class StatusRecoveryTests(unittest.TestCase):
    def test_missing_idle_and_finished_can_be_restored(self):
        for status in ("idle", "finished", "awaitingInput", "running"):
            bridge = RecordingBridge()
            self.assertTrue(bridge.report(status, recovery=True))
            self.assertEqual(bridge.session_statuses["pane"]["status"], status)
            self.assertEqual(bridge.session_statuses["pane"]["activityKind"], "agent")

    def test_recovery_never_overwrites_known_agent_or_focused_idle(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("finished", sequence=1))
        bridge.clear_finished_status("pane")
        self.assertEqual(bridge.session_statuses["pane"]["status"], "idle")
        self.assertFalse(bridge.report("finished", sequence=2, recovery=True))
        self.assertEqual(bridge.session_statuses["pane"]["status"], "idle")
        self.assertTrue(bridge.report("running", sequence=3))
        self.assertFalse(bridge.report("idle", sequence=4, recovery=True))
        self.assertEqual(bridge.session_statuses["pane"]["status"], "running")

    def test_recovery_can_replace_shell_fallback_but_has_a_running_lease(self):
        bridge = RecordingBridge()
        bridge.set_session_status("pane", "running")
        self.assertTrue(bridge.report("running", recovery=True))
        observed = bridge.agent_heartbeat_times["pane"]
        bridge.expire_stale_agent_heartbeats(observed + 9)
        self.assertNotIn("pane", bridge.session_statuses)

    def test_detach_tombstone_rejects_an_older_query(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("running", sequence=1))
        self.assertTrue(bridge.report("detached", sequence=3))
        self.assertFalse(bridge.report("finished", sequence=2, recovery=True))
        self.assertNotIn("pane", bridge.session_statuses)

    def test_recovered_sequence_rejects_older_push_and_accepts_newer_push(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("finished", sequence=3, recovery=True))
        self.assertFalse(bridge.report("running", sequence=2))
        self.assertEqual(bridge.session_statuses["pane"]["status"], "finished")
        self.assertTrue(bridge.report("running", sequence=4))

    def test_deleted_session_and_invalid_sequences_are_rejected(self):
        bridge = RecordingBridge()
        for sequence in (True, 0, -1, 9007199254740992, "1"):
            self.assertFalse(bridge.report("idle", sequence=sequence, recovery=True))
        bridge.app.get_session_by_id = lambda _: None
        self.assertFalse(bridge.report("idle", recovery=True))
        self.assertFalse(bridge.session_statuses)

    def test_legacy_unsequenced_agent_reports_remain_supported(self):
        bridge = RecordingBridge()
        payload = dict(type="setSessionStatus", sessionId="pane", status="idle")
        asyncio.run(bridge.handle_command(None, json.dumps(payload).encode()))
        self.assertTrue(bridge.responses[-1][0])


if __name__ == "__main__":
    unittest.main()
