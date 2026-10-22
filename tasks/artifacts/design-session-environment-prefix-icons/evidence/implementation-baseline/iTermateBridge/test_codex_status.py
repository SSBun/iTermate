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

    async def send_action_result(self, writer, request_id, ok, error):
        self.responses.append((ok, error))

    async def publish_snapshot(self, target=None):
        pass

    def report(self, status, sequence=1, event="event-1", reporter="codex-reporter", claim=False, **extra):
        request = dict(
            type="setSessionStatus", sessionId="pane", status=status,
            reporterId=reporter, sequence=sequence, codexSessionId="codex-session",
            codexEventId=event, codexClaim=claim, **extra,
        )
        asyncio.run(self.handle_command(None, json.dumps(request).encode()))
        return self.responses[-1][0]


class CodexBridgeTests(unittest.TestCase):
    def test_codex_replaces_command_fallback_with_leased_agent(self):
        bridge = RecordingBridge()
        bridge.set_session_status("pane", "running")
        self.assertTrue(bridge.report("running", claim=True))
        self.assertEqual(bridge.session_statuses["pane"]["activityKind"], "agent")
        bridge.expire_stale_agent_heartbeats(bridge.agent_heartbeat_times["pane"] + 9)
        self.assertNotIn("pane", bridge.session_statuses)

    def test_awaiting_input_heartbeat_renews_lease_and_preserves_start_time(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("idle", claim=True))
        self.assertTrue(bridge.report("awaitingInput", 2, event="approval"))
        changed = bridge.session_statuses["pane"]["statusChangedAt"]
        first_lease = bridge.agent_heartbeat_times["pane"]
        from unittest.mock import patch
        with patch.object(module, "heartbeat_time", return_value=first_lease + 7):
            self.assertTrue(bridge.report("awaitingInput", 3, event="approval", heartbeat=True))
        bridge.expire_stale_agent_heartbeats(first_lease + 9)
        self.assertEqual(bridge.session_statuses["pane"]["status"], "awaitingInput")
        self.assertEqual(bridge.session_statuses["pane"]["statusChangedAt"], changed)
        bridge.expire_stale_agent_heartbeats(first_lease + 16)
        self.assertNotIn("pane", bridge.session_statuses)

    def test_failed_turn_is_not_successful_completion(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("running", claim=True))
        self.assertTrue(bridge.report("finished", 2, event="failed", exitStatus=1))
        self.assertEqual(bridge.session_statuses["pane"]["exitStatus"], 1)

    def test_worker_restores_after_bridge_restart(self):
        bridge = RecordingBridge()
        bridge.set_session_status("pane", "running")
        self.assertTrue(bridge.report("running", sequence=5, heartbeat=True))
        self.assertEqual(bridge.session_statuses["pane"]["activityKind"], "agent")

    def test_lost_stop_ack_does_not_restore_read_badge(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("running", claim=True))
        self.assertTrue(bridge.report("finished", 2, event="stop"))
        bridge.clear_finished_status("pane")
        self.assertTrue(bridge.report("finished", 3, event="stop"))
        self.assertEqual(bridge.session_statuses["pane"]["status"], "idle")

    def test_old_reporter_cannot_overwrite_new_owner(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("running", claim=True))
        self.assertTrue(bridge.report("running", reporter="new-reporter", event="new", claim=True))
        self.assertFalse(bridge.report("running", 2, heartbeat=True))
        self.assertFalse(bridge.report("finished", 3, event="old-stop"))

    def test_pi_report_blocks_old_codex_worker(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("running", claim=True))
        payload = dict(type="setSessionStatus", sessionId="pane", status="running")
        asyncio.run(bridge.handle_command(None, json.dumps(payload).encode()))
        self.assertFalse(bridge.report("running", 2, heartbeat=True))

    def test_pending_claim_can_replace_expected_old_owner(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("idle", claim=True))
        self.assertTrue(bridge.report("detached", 2, event="end"))
        self.assertTrue(bridge.report(
            "running", 3, reporter="new-reporter", event="new",
            codexPreviousOwner=["codex-reporter", "codex-session"],
        ))
        self.assertEqual(bridge.codex_reports["pane"][0], ("new-reporter", "codex-session"))

    def test_terminal_state_can_complete_unacknowledged_owner_switch(self):
        for status in ("finished", "idle", "detached"):
            bridge = RecordingBridge()
            self.assertTrue(bridge.report("idle", claim=True))
            self.assertTrue(bridge.report(
                status, 2, reporter="new-reporter", event="new-terminal",
                codexPreviousOwner=["codex-reporter", "codex-session"],
            ))
            self.assertEqual(bridge.codex_reports["pane"][0], ("new-reporter", "codex-session"))
            if status == "detached":
                self.assertNotIn("pane", bridge.agent_managed_session_ids)
            else:
                self.assertEqual(bridge.session_statuses["pane"]["status"], status)

    def test_pending_claim_cannot_replace_newer_owner(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("idle", claim=True))
        self.assertTrue(bridge.report("running", reporter="newer", event="newer", claim=True))
        self.assertFalse(bridge.report(
            "running", 2, reporter="pending", event="pending",
            codexPreviousOwner=["codex-reporter", "codex-session"],
        ))

    def test_pending_claim_cannot_reclaim_after_other_agent_detaches(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("running", claim=True))
        payload = dict(type="setSessionStatus", sessionId="pane", status="detached")
        asyncio.run(bridge.handle_command(None, json.dumps(payload).encode()))
        self.assertFalse(bridge.report(
            "running", 2, codexPreviousOwner=["codex-reporter", "codex-session"],
        ))

    def test_new_prompt_can_claim_after_other_agent(self):
        bridge = RecordingBridge()
        bridge.set_agent_status("pane", "idle")
        self.assertFalse(bridge.report("running"))
        self.assertTrue(bridge.report("running", 2, claim=True))

    def test_delayed_session_end_preserves_subsequent_shell_command(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("idle", claim=True))
        bridge.set_session_status("pane", "running")
        self.assertTrue(bridge.report("detached", 2, event="end"))
        self.assertEqual(bridge.session_statuses["pane"]["activityKind"], "command")
        self.assertEqual(bridge.session_statuses["pane"]["status"], "running")

    def test_no_report_to_deleted_session(self):
        bridge = RecordingBridge()
        bridge.app.get_session_by_id = lambda _: None
        self.assertFalse(bridge.report("running", claim=True))

    def test_older_sequence_is_rejected(self):
        bridge = RecordingBridge()
        self.assertTrue(bridge.report("running", 3, claim=True))
        self.assertFalse(bridge.report("finished", 2, event="stop"))


if __name__ == "__main__":
    unittest.main()
