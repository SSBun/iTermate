"""隔离验证归档后只关闭目标分屏，不连接真实 iTerm2 或发送进程信号。"""

import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

spec = importlib.util.spec_from_file_location("archive_close_bridge", Path(__file__).with_name("iTermateBridge.py"))
bridge_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge_module)


class ArchiveCloseTests(unittest.IsolatedAsyncioTestCase):
    async def exercise(self, job_pids, *, missing=False, prompt_state="IDLE", alive=False, expected_pid=111):
        target = SimpleNamespace(
            async_get_variable=AsyncMock(side_effect=job_pids),
            async_close=AsyncMock(),
        )
        other = SimpleNamespace(async_close=AsyncMock())
        requested_ids = []

        def lookup(session_id):
            requested_ids.append(session_id)
            return None if missing else (target if session_id == "target-pane" else other)

        bridge = bridge_module.Bridge(None, SimpleNamespace(get_session_by_id=lookup))
        bridge.current_prompt = AsyncMock(return_value=SimpleNamespace(state=prompt_state))
        bridge.send_action_result = AsyncMock()
        bridge.publish_snapshot = AsyncMock()
        with patch.object(bridge_module, "iterm2", SimpleNamespace(PromptState=SimpleNamespace(RUNNING="RUNNING")), create=True), \
                patch.object(bridge_module.os, "kill", side_effect=None if alive else ProcessLookupError), \
                patch.object(bridge_module.asyncio, "sleep", new_callable=AsyncMock):
            await bridge.handle_command(None, json.dumps({
                "type": "closeArchivedSession", "requestId": "request-1",
                "sessionId": "target-pane", "expectedShellPID": expected_pid,
            }))
        other.async_close.assert_not_awaited()
        self.assertTrue(all(value == "target-pane" for value in requested_ids))
        result = bridge.send_action_result.await_args.args
        return target, result

    async def test_stale_exited_pid_refreshes_to_original_shell_and_closes_only_target(self):
        target, result = await self.exercise(["999", "111"])
        target.async_close.assert_awaited_once_with(force=False)
        self.assertTrue(result[2])

    async def test_live_replacement_process_is_never_closed(self):
        target, result = await self.exercise(["999"], alive=True)
        target.async_close.assert_not_awaited()
        self.assertFalse(result[2])
        self.assertIn("Another process", result[3])

    async def test_busy_original_shell_is_left_open(self):
        target, result = await self.exercise(["111"] * 30, prompt_state="RUNNING")
        target.async_close.assert_not_awaited()
        self.assertFalse(result[2])

    async def test_unknown_owner_times_out_without_closing(self):
        target, result = await self.exercise([None] * 30)
        target.async_close.assert_not_awaited()
        self.assertFalse(result[2])

    async def test_already_closed_pane_is_idempotent(self):
        target, result = await self.exercise([], missing=True)
        target.async_close.assert_not_awaited()
        self.assertTrue(result[2])

    async def test_invalid_owner_is_rejected(self):
        target, result = await self.exercise([], expected_pid=True)
        target.async_close.assert_not_awaited()
        self.assertFalse(result[2])


if __name__ == "__main__":
    unittest.main()
