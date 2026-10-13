import importlib.util
import pathlib
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "status_reporter", pathlib.Path(__file__).with_name("iTermate-status.py")
)
reporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reporter)


def event(name, turn="turn-1", session="codex-1", **fields):
    return {"hook_event_name": name, "session_id": session, "turn_id": turn, **fields}


class CodexStatusTests(unittest.TestCase):
    def running(self):
        return reporter.apply_codex_event({}, event("UserPromptSubmit"), 100)

    def test_compact_does_not_reset_running(self):
        state = self.running()
        self.assertIsNone(reporter.apply_codex_event(
            state, event("SessionStart", source="compact"), 101
        ))
        self.assertEqual(state["status"], "running")

    def test_old_stop_cannot_finish_new_turn(self):
        state = reporter.apply_codex_event(self.running(), event("UserPromptSubmit", "turn-2"), 101)
        self.assertIsNone(reporter.apply_codex_event(state, event("Stop"), 102))
        self.assertEqual(state["turnId"], "turn-2")
        self.assertEqual(state["status"], "running")

    def test_old_prompt_cannot_reopen_retired_turn(self):
        state = reporter.apply_codex_event(self.running(), event("UserPromptSubmit", "turn-2"), 101)
        self.assertIsNone(reporter.apply_codex_event(state, event("UserPromptSubmit"), 102))

    def test_interrupt_is_idle_not_success(self):
        state = reporter.apply_codex_event(self.running(), event("Interrupt"), 101)
        self.assertEqual(state["status"], "idle")
        self.assertNotIn("exitStatus", state)

    def test_late_tool_event_does_not_restart_stopped_turn(self):
        state = reporter.apply_codex_event(self.running(), event("Stop"), 101)
        self.assertIsNone(reporter.apply_codex_event(state, event("PostToolUse"), 102))

    def test_other_session_cannot_end_current_session(self):
        self.assertIsNone(reporter.apply_codex_event(
            self.running(), event("SessionEnd", session="other"), 101
        ))

    def test_tool_observation_refreshes_without_replacing_generation(self):
        state = self.running()
        updated = reporter.apply_codex_event(state, event("PreToolUse"), 101)
        self.assertEqual(updated["generation"], state["generation"])
        self.assertEqual(updated["observedAt"], 101)

    def test_missing_turn_is_not_running_evidence(self):
        self.assertIsNone(reporter.apply_codex_event({}, event("UserPromptSubmit", None), 100))

    def test_cached_observation_expires_without_inventing_completion(self):
        state = self.running()
        self.assertTrue(reporter.codex_state_is_fresh(state, 101))
        self.assertFalse(reporter.codex_state_is_fresh(state, 100 + reporter.CODEX_OBSERVATION_MAX_AGE + 1))
        self.assertFalse(reporter.codex_state_is_fresh(state, 99))
        self.assertEqual(state["status"], "running")

    def test_resume_does_not_reset_active_turn(self):
        self.assertIsNone(reporter.apply_codex_event(
            self.running(), event("SessionStart", source="resume"), 101
        ))

    def test_resume_rebinds_same_session_to_new_producer(self):
        first = {"pid": 100, "started": "first", "command": "/bin/codex"}
        second = {"pid": 101, "started": "second", "command": "/bin/codex"}
        for normal_exit in (True, False):
            state = reporter.apply_codex_event({}, event("UserPromptSubmit"), 100, first)
            if normal_exit:
                state = reporter.apply_codex_event(state, event("SessionEnd"), 101, first)
            state = reporter.apply_codex_event(state, event("SessionStart", source="resume"), 102, second)
            self.assertEqual(state["status"], "idle")
            self.assertEqual(state["ownerProcess"], second)
            state = reporter.apply_codex_event(state, event("UserPromptSubmit", "turn-2"), 103, second)
            self.assertEqual(state["ownerProcess"], second)
            self.assertEqual(state["status"], "running")
            self.assertIsNone(reporter.apply_codex_event(state, event("SessionEnd"), 104, first))

    def test_unacknowledged_claim_retains_compare_and_swap_owner(self):
        state = self.running()
        state["itermSessionId"] = "terminal-1"
        state["acknowledgedOwner"] = ["old-reporter", "old-session"]
        with patch.object(reporter, "exchange", side_effect=[(False, "transport"), (True, None)]) as exchange:
            reporter.send_codex_state(state, claim=True)
            self.assertTrue(state["pendingClaim"])
            reporter.send_codex_state(state)
            retry = exchange.call_args.args[1]
        self.assertFalse(retry["codexClaim"])
        self.assertEqual(retry["codexPreviousOwner"], ["old-reporter", "old-session"])
        self.assertFalse(state["pendingClaim"])

    def test_terminal_transition_keeps_unacknowledged_owner_switch(self):
        for name in ("Stop", "Interrupt", "SessionEnd"):
            state = self.running()
            state["itermSessionId"] = "terminal-1"
            with patch.object(reporter, "exchange", return_value=(True, None)):
                reporter.send_codex_state(state, claim=True)
            old_owner = state["acknowledgedOwner"]
            state = reporter.apply_codex_event(state, event("UserPromptSubmit", session="codex-2"), 101)
            state["itermSessionId"] = "terminal-1"
            with patch.object(reporter, "exchange", return_value=(False, "transport")):
                reporter.send_codex_state(state, claim=True)
            state = reporter.apply_codex_event(state, event(name, session="codex-2"), 102)
            self.assertTrue(state["pendingClaim"])
            with patch.object(reporter, "exchange", return_value=(True, None)) as exchange:
                reporter.send_codex_state(state)
                request = exchange.call_args.args[1]
            self.assertEqual(request["codexPreviousOwner"], old_owner)
            self.assertFalse(request["codexClaim"])
            self.assertFalse(state["pendingClaim"])

    def test_terminal_retry_survives_producer_exit(self):
        from unittest.mock import MagicMock
        state = reporter.apply_codex_event(self.running(), event("SessionEnd"), 101)
        state.update({"workerToken": "worker", "ownerProcess": {"pid": 100}, "itermSessionId": "pane"})
        with patch.object(reporter, "locked_agent_state", return_value=(MagicMock(), state)), \
                patch.object(reporter, "write_agent_state"), \
                patch.object(reporter, "codex_owner_is_alive", return_value=False) as alive, \
                patch.object(reporter, "send_codex_state", return_value=True) as send, \
                patch.object(reporter.time, "sleep"), \
                patch.object(reporter.time, "time", return_value=102), \
                patch.object(reporter.time, "monotonic", return_value=100):
            reporter.run_codex_worker("11111111-1111-1111-1111-111111111111", "worker")
        send.assert_called_once()
        alive.assert_not_called()

    def test_delivery_uses_session_route_and_monotonic_sequence(self):
        state = self.running()
        state["itermSessionId"] = "terminal-1"
        with patch.object(reporter, "exchange", return_value=(True, None)) as exchange:
            reporter.send_codex_state(state, claim=True)
            first = exchange.call_args.args[1]
            reporter.send_codex_state(state)
            second = exchange.call_args.args[1]
        self.assertEqual(first["sessionId"], "terminal-1")
        self.assertEqual(first["codexSessionId"], "codex-1")
        self.assertTrue(first["codexClaim"])
        self.assertFalse(second["codexClaim"])
        self.assertGreater(second["sequence"], first["sequence"])
        self.assertEqual(first["codexEventId"], second["codexEventId"])


class ExchangeTests(unittest.TestCase):
    def test_skips_snapshots_and_unrelated_acknowledgements(self):
        from unittest.mock import MagicMock
        import json
        client = MagicMock()
        client.__enter__.return_value = client
        client.recv.side_effect = [b'\n'.join(json.dumps(message).encode() for message in [
            {"type": "hello"},
            {"type": "snapshot"},
            {"type": "actionResult", "requestId": "other", "ok": True},
            {"type": "actionResult", "requestId": "wanted", "ok": True},
        ]) + b'\n']
        with patch.object(reporter.socket, "socket", return_value=client):
            self.assertEqual(reporter.exchange("unused", {"requestId": "wanted"}), (True, None))

    def test_rejected_ack_is_not_success(self):
        from unittest.mock import MagicMock
        client = MagicMock()
        client.__enter__.return_value = client
        client.recv.return_value = b'{"type":"actionResult","requestId":"wanted","ok":false}\n'
        with patch.object(reporter.socket, "socket", return_value=client):
            self.assertEqual(reporter.exchange("unused", {"requestId": "wanted"}), (False, "rejected"))

    def test_connection_failure_is_observable(self):
        with patch.object(reporter.socket, "socket", side_effect=OSError()):
            self.assertEqual(reporter.exchange("unused", {"requestId": "wanted"}), (False, "transport"))


if __name__ == "__main__":
    unittest.main()
