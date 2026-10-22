import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import struct
import tempfile
import threading
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("codex_wrapper", Path(__file__).with_name("iTermate-codex.py"))
wrapper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(wrapper)
SPEC = importlib.util.spec_from_file_location("wrapper_reporter", Path(__file__).with_name("iTermate-status.py"))
reporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reporter)


def frame(message, mask=False, opcode=1, final=True):
    payload = message if isinstance(message, bytes) else json.dumps(message).encode()
    header = bytes([(128 if final else 0) | opcode])
    size = len(payload)
    flag = 128 if mask else 0
    if size < 126:
        header += bytes([flag | size])
    elif size < 65536:
        header += bytes([flag | 126]) + struct.pack("!H", size)
    else:
        header += bytes([flag | 127]) + struct.pack("!Q", size)
    if mask:
        key = b"1234"
        return header + key + bytes(value ^ key[index % 4] for index, value in enumerate(payload))
    return header + payload


def select(monitor, thread="thread-1", status=None, request_id=10):
    monitor.observe({"id": request_id, "method": "thread/resume", "params": {"threadId": thread}}, False)
    monitor.observe({"id": request_id, "result": {"thread": {"id": thread, "status": status or {"type": "idle"}}}}, True)


def notify(monitor, method, thread="thread-1", **params):
    monitor.observe({"method": method, "params": {"threadId": thread, **params}}, True)


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.monitor = wrapper.StatusMonitor()
        select(self.monitor)

    def test_selected_thread_is_idle_not_historical_finished(self):
        self.assertEqual(self.monitor.status, "idle")
        self.assertIsNone(self.monitor.exit_status)

    def test_lifecycle_and_approval_flags(self):
        notify(self.monitor, "turn/started", turn={"id": "turn-1", "status": "inProgress"})
        self.assertEqual(self.monitor.status, "running")
        for flag in ("waitingOnApproval", "waitingOnUserInput"):
            notify(self.monitor, "thread/status/changed", status={"type": "active", "activeFlags": [flag]})
            self.assertEqual(self.monitor.status, "awaitingInput")
        notify(self.monitor, "thread/status/changed", status={"type": "active", "activeFlags": []})
        self.assertEqual(self.monitor.status, "running")
        notify(self.monitor, "turn/completed", turn={"id": "turn-1", "status": "completed"})
        self.assertEqual((self.monitor.status, self.monitor.exit_status), ("finished", 0))
        generation = self.monitor.generation
        notify(self.monitor, "thread/status/changed", status={"type": "idle"})
        notify(self.monitor, "turn/completed", turn={"id": "turn-1", "status": "completed"})
        self.assertEqual(self.monitor.generation, generation)

    def test_failure_and_interrupt_are_not_success(self):
        for status, expected in (("failed", ("finished", 1)), ("interrupted", ("idle", None))):
            monitor = wrapper.StatusMonitor()
            select(monitor)
            notify(monitor, "turn/started", turn={"id": "turn-1"})
            notify(monitor, "turn/completed", turn={"id": "turn-1", "status": status})
            self.assertEqual((monitor.status, monitor.exit_status), expected)

    def test_other_threads_and_unsolicited_responses_never_rebind(self):
        notify(self.monitor, "thread/started", thread="child", status={"type": "active"})
        notify(self.monitor, "turn/started", thread="child", turn={"id": "child-turn"})
        self.monitor.observe({"id": 99, "result": {"thread": {"id": "other"}}}, True)
        self.assertEqual((self.monitor.thread_id, self.monitor.status), ("thread-1", "idle"))

    def test_old_completion_cannot_finish_new_turn(self):
        notify(self.monitor, "turn/started", turn={"id": "turn-1"})
        notify(self.monitor, "turn/started", turn={"id": "turn-2"})
        notify(self.monitor, "turn/completed", turn={"id": "turn-1", "status": "completed"})
        self.assertEqual((self.monitor.status, self.monitor.turn_id), ("running", "turn-2"))

    def test_resume_active_and_switch_thread(self):
        select(self.monitor, "thread-2", {"type": "active", "activeFlags": ["waitingOnApproval"]})
        self.assertEqual((self.monitor.thread_id, self.monitor.status), ("thread-2", "awaitingInput"))
        notify(self.monitor, "turn/completed", turn={"id": "turn-1", "status": "completed"})
        self.assertEqual(self.monitor.status, "awaitingInput")

    def test_unknown_status_and_disconnect_fail_closed(self):
        for status in ({"type": "systemError"}, {"type": "notLoaded"}, {"type": "active", "activeFlags": ["newFlag"]}, {}):
            notify(self.monitor, "thread/status/changed", status=status)
            self.assertEqual(self.monitor.status, "detached")
        self.monitor.close()
        notify(self.monitor, "turn/started", turn={"id": "turn-1"})
        self.assertEqual(self.monitor.status, "detached")

    def test_rapid_turns_retain_each_transition(self):
        self.monitor.snapshots.clear()
        for turn in ("turn-1", "turn-2"):
            notify(self.monitor, "turn/started", turn={"id": turn})
            notify(self.monitor, "turn/completed", turn={"id": turn, "status": "completed"})
        self.assertEqual([snapshot[1] for snapshot in self.monitor.snapshots], ["running", "finished", "running", "finished"])

    def test_queue_overflow_releases_status_instead_of_growing(self):
        for index in range(300):
            notify(self.monitor, "turn/started", turn={"id": str(index)})
        self.assertTrue(self.monitor.closed)
        self.assertLessEqual(len(self.monitor.snapshots), 256)
        self.assertEqual(self.monitor.snapshots[-1][1], "detached")


class ObserverTests(unittest.TestCase):
    def test_split_handshake_and_masked_fragmented_messages(self):
        received = []
        observer = wrapper.WebSocketObserver(received.append)
        data = b"GET / HTTP/1.1\r\nUpgrade: websocket\r\n\r\n"
        data += frame(b'{"id":', mask=True, final=False)
        data += frame(b"ping", opcode=9)
        data += frame(b"1}", mask=True, opcode=0)
        data += frame({"id": 2})
        for byte in data:
            observer.feed(bytes([byte]))
        self.assertEqual(received, [{"id": 1}, {"id": 2}])

    def test_extended_lengths(self):
        for size in (200, 70000):
            received = []
            observer = wrapper.WebSocketObserver(received.append)
            observer.feed(b"HTTP/1.1 101 Switching Protocols\r\n\r\n" + frame({"value": "x" * size}, mask=True))
            self.assertEqual(len(received[0]["value"]), size)

    def test_oversized_frame_rejected_before_payload_allocation(self):
        observer = wrapper.WebSocketObserver(lambda _: None)
        with self.assertRaises(ValueError):
            observer.feed(b"HTTP/1.1 101 OK\r\n\r\n\x81\x7f" + struct.pack("!Q", observer.maximum_size + 1))

    def test_relay_is_byte_transparent_and_never_replies_to_requests(self):
        source, writer = socket.socketpair()
        destination, reader = socket.socketpair()
        monitor = wrapper.StatusMonitor()
        select(monitor)
        data = b"HTTP/1.1 101 OK\r\n\r\n" + frame({"id": 7, "method": "item/commandExecution/requestApproval", "params": {"threadId": "thread-1"}})
        thread = threading.Thread(target=wrapper.relay, args=(source, destination, monitor, True))
        thread.start()
        try:
            writer.sendall(data)
            writer.shutdown(socket.SHUT_WR)
            reader.settimeout(2)
            received = bytearray()
            while True:
                chunk = reader.recv(4096)
                if not chunk:
                    break
                received.extend(chunk)
            self.assertEqual(received, data)
            writer.settimeout(2)
            self.assertEqual(writer.recv(1), b"")
        finally:
            thread.join(timeout=2)
            for peer in (source, writer, destination, reader):
                peer.close()
        self.assertFalse(thread.is_alive())
        self.assertEqual(monitor.status, "detached")


class ReportingTests(unittest.TestCase):
    def test_real_reporter_preserves_order_failure_and_detach(self):
        monitor = wrapper.StatusMonitor()
        select(monitor)
        notify(monitor, "turn/started", turn={"id": "turn-1"})
        notify(monitor, "thread/status/changed", status={"type": "active", "activeFlags": ["waitingOnApproval"]})
        notify(monitor, "turn/completed", turn={"id": "turn-1", "status": "failed"})
        sent = []
        def exchange(path, request, bridge=False):
            sent.append(dict(request))
            if request["status"] == "finished":
                monitor.close()
            return True, None
        with patch.object(reporter, "exchange", side_effect=exchange):
            wrapper.report_status(monitor, reporter, "pane")
        self.assertEqual([request["status"] for request in sent], ["idle", "idle", "running", "awaitingInput", "finished", "detached"])
        self.assertEqual(sent[-2]["exitStatus"], 1)
        self.assertTrue(sent[0]["codexClaim"])
        self.assertTrue(all(not request["heartbeat"] for request in sent))
        self.assertEqual([request["sequence"] for request in sent], list(range(1, len(sent) + 1)))

    def test_waiting_heartbeat_is_acknowledged_and_bounded_on_close(self):
        monitor = wrapper.StatusMonitor()
        select(monitor, status={"type": "active", "activeFlags": ["waitingOnUserInput"]})
        sent = []
        def exchange(path, request, bridge=False):
            sent.append(dict(request))
            if request["heartbeat"]:
                monitor.close()
            return True, None
        with patch.object(reporter, "exchange", side_effect=exchange):
            thread = threading.Thread(target=wrapper.report_status, args=(monitor, reporter, "pane"), daemon=True)
            thread.start()
            thread.join(timeout=4)
        self.assertFalse(thread.is_alive())
        self.assertTrue(any(request["heartbeat"] and request["status"] == "awaitingInput" for request in sent))
        self.assertEqual(sent[-1]["status"], "detached")

    def test_real_reporter_delivers_to_actual_bridge_handler(self):
        bridge_spec = importlib.util.spec_from_file_location(
            "wrapper_bridge_fixture", Path(__file__).parents[2] / "iTermateBridge/test_codex_status.py"
        )
        bridge_module = importlib.util.module_from_spec(bridge_spec)
        bridge_spec.loader.exec_module(bridge_module)
        import asyncio
        bridge = bridge_module.RecordingBridge()
        monitor = wrapper.StatusMonitor()
        select(monitor)
        notify(monitor, "turn/started", turn={"id": "turn-1"})
        notify(monitor, "thread/status/changed", status={"type": "active", "activeFlags": ["waitingOnApproval"]})
        notify(monitor, "turn/completed", turn={"id": "turn-1", "status": "failed"})
        seen = []
        def exchange(path, request, bridge=False):
            receiver = bridge_instance
            asyncio.run(receiver.handle_command(None, json.dumps(request).encode()))
            self.assertTrue(receiver.responses[-1][0], receiver.responses[-1])
            status = receiver.session_statuses.get("pane", {})
            seen.append(dict(status))
            if request["status"] == "finished":
                monitor.close()
            return True, None
        bridge_instance = bridge
        with patch.object(reporter, "exchange", side_effect=exchange):
            wrapper.report_status(monitor, reporter, "pane")
        self.assertTrue(any(state.get("status") == "awaitingInput" for state in seen))
        self.assertTrue(any(state.get("exitStatus") == 1 for state in seen))
        self.assertNotIn("pane", bridge.agent_managed_session_ids)

    def test_close_retries_finished_that_failed_while_inflight(self):
        monitor = wrapper.StatusMonitor()
        select(monitor)
        notify(monitor, "turn/started", turn={"id": "turn-1"})
        notify(monitor, "turn/completed", turn={"id": "turn-1", "status": "failed"})
        sent = []
        def exchange(path, request, bridge=False):
            sent.append(dict(request))
            if request["status"] == "finished" and sum(item["status"] == "finished" for item in sent) == 1:
                monitor.close()
                return False, "transport"
            return True, None
        with patch.object(reporter, "exchange", side_effect=exchange), patch.object(wrapper.time, "sleep"):
            wrapper.report_status(monitor, reporter, "pane")
        finished = [request for request in sent if request["status"] == "finished"]
        self.assertEqual(len(finished), 2)
        self.assertEqual(finished[0]["codexEventId"], finished[1]["codexEventId"])
        self.assertEqual(finished[1]["exitStatus"], 1)
        self.assertGreater(finished[1]["sequence"], finished[0]["sequence"])
        self.assertEqual(sent[-1]["status"], "detached")

    def test_detached_retries_until_ack_after_transient_failure(self):
        monitor = wrapper.StatusMonitor()
        select(monitor)
        monitor.close()
        sent = []
        def exchange(path, request, bridge=False):
            sent.append(dict(request))
            if request["status"] == "detached" and sum(item["status"] == "detached" for item in sent) == 1:
                return False, "transport"
            return True, None
        with patch.object(reporter, "exchange", side_effect=exchange), patch.object(wrapper.time, "sleep"):
            wrapper.report_status(monitor, reporter, "pane")
        detached = [request for request in sent if request["status"] == "detached"]
        self.assertEqual(len(detached), 2)
        self.assertEqual(detached[0]["codexEventId"], detached[1]["codexEventId"])
        self.assertGreater(detached[1]["sequence"], detached[0]["sequence"])

    def test_close_discards_stale_running_backlog(self):
        monitor = wrapper.StatusMonitor()
        select(monitor)
        notify(monitor, "turn/started", turn={"id": "turn-1"})
        monitor.close()
        sent = []
        def exchange(path, request, bridge=False):
            sent.append(dict(request))
            return False, "transport"
        clock = [0.0]
        with patch.object(reporter, "exchange", side_effect=exchange), \
                patch.object(wrapper.time, "monotonic", side_effect=lambda: clock[0]), \
                patch.object(wrapper.time, "sleep", side_effect=lambda delay: clock.__setitem__(0, clock[0] + delay)), \
                patch.object(wrapper.sys, "stderr", io.StringIO()) as diagnostics:
            wrapper.report_status(monitor, reporter, "pane")
        self.assertIn("未获确认", diagnostics.getvalue())
        self.assertLessEqual(clock[0], wrapper.FINAL_REPORT_TIMEOUT + 0.1)
        self.assertLessEqual(len(sent), 40)
        self.assertFalse(any(request["status"] == "running" for request in sent))
        self.assertEqual(sent[-1]["status"], "detached")

    def test_failed_completion_timeout_still_attempts_detach(self):
        monitor = wrapper.StatusMonitor()
        select(monitor)
        notify(monitor, "turn/started", turn={"id": "turn-1"})
        notify(monitor, "turn/completed", turn={"id": "turn-1", "status": "completed"})
        sent = []
        clock = [0.0]
        def exchange(path, request, bridge=False):
            sent.append(dict(request))
            if request["status"] == "finished":
                monitor.close()
                return False, "transport"
            return True, None
        with patch.object(reporter, "exchange", side_effect=exchange), \
                patch.object(wrapper.time, "monotonic", side_effect=lambda: clock[0]), \
                patch.object(wrapper.time, "sleep", side_effect=lambda delay: clock.__setitem__(0, clock[0] + delay)), \
                patch.object(wrapper.sys, "stderr", io.StringIO()) as diagnostics:
            wrapper.report_status(monitor, reporter, "pane")
        self.assertIn("finished 未获确认", diagnostics.getvalue())
        self.assertEqual(sent[-1]["status"], "detached")
        self.assertLessEqual(clock[0], wrapper.FINAL_REPORT_TIMEOUT + 0.1)

    def test_final_retry_respects_receiver_rejection_without_reclaim(self):
        state = reporter.apply_codex_event({}, {"hook_event_name": "UserPromptSubmit", "session_id": "thread-1", "turn_id": "turn-1"}, 100)
        state.update({"itermSessionId": "pane", "status": "detached"})
        with patch.object(reporter, "exchange", return_value=(False, "rejected")) as exchange, \
                patch.object(wrapper.sys, "stderr", io.StringIO()) as diagnostics:
            self.assertFalse(wrapper.deliver_final_status(reporter, state))
        exchange.assert_called_once()
        self.assertFalse(exchange.call_args.args[1]["codexClaim"])
        self.assertIn("rejected", diagnostics.getvalue())

    def test_final_retry_after_lost_ack_never_restores_read_completion(self):
        bridge_spec = importlib.util.spec_from_file_location(
            "retry_bridge_fixture", Path(__file__).parents[2] / "iTermateBridge/test_codex_status.py"
        )
        bridge_module = importlib.util.module_from_spec(bridge_spec)
        bridge_spec.loader.exec_module(bridge_module)
        import asyncio
        receiver = bridge_module.RecordingBridge()
        monitor = wrapper.StatusMonitor()
        select(monitor)
        notify(monitor, "turn/started", turn={"id": "turn-1"})
        notify(monitor, "turn/completed", turn={"id": "turn-1", "status": "completed"})
        completions = []
        def exchange(path, request, bridge=False):
            asyncio.run(receiver.handle_command(None, json.dumps(request).encode()))
            self.assertTrue(receiver.responses[-1][0])
            if request["status"] == "finished":
                completions.append(dict(request))
                if len(completions) == 1:
                    receiver.clear_finished_status("pane")
                    monitor.close()
                    return False, "transport"
                self.assertEqual(receiver.session_statuses["pane"]["status"], "idle")
            return True, None
        with patch.object(reporter, "exchange", side_effect=exchange), patch.object(wrapper.time, "sleep"):
            wrapper.report_status(monitor, reporter, "pane")
        self.assertEqual(len(completions), 2)
        self.assertEqual(completions[0]["codexEventId"], completions[1]["codexEventId"])
        self.assertNotIn("pane", receiver.agent_managed_session_ids)

    def test_hooks_do_not_compete_with_wrapper(self):
        with patch.dict(os.environ, {"ITERMATE_CODEX_WRAPPER": "1"}), patch.object(reporter, "report_codex_iterm") as hook:
            reporter.report_agent("running")
        hook.assert_not_called()


class LaunchTests(unittest.TestCase):
    def test_config_forwarding_and_transport_protection(self):
        self.assertEqual(wrapper.launch_arguments(["-c", "model=\"model-x\"", "--enable", "feature", "resume", "session"]), (["-c", "model=\"model-x\"", "--enable", "feature"], None))
        for option in ("--remote=x", "--no-daemon", "--profile", "--worktree"):
            with self.assertRaises(ValueError):
                wrapper.launch_arguments([option])
        self.assertEqual(wrapper.launch_arguments(["--", "--remote=literal-prompt"]), ([], None))
        self.assertEqual(wrapper.launch_arguments(["-C", "/tmp", "-cmodel=\"x\""]), (["-c", 'model="x"'], "/tmp"))
        for option in ("exec", "login", "app-server"):
            with self.assertRaises(ValueError):
                wrapper.launch_arguments([option])

    def test_missing_identity_never_starts_codex(self):
        with patch.object(reporter, "iterm_session_id", return_value=None), patch.object(wrapper.subprocess, "Popen") as spawn:
            with self.assertRaises(ValueError):
                wrapper.run([], reporter)
        spawn.assert_not_called()

    def test_launch_routes_native_style_frames_and_cleans_up_owned_backend(self):
        fake_source = r'''#!/usr/bin/env python3
import json, os, socket, sys, time
from pathlib import Path
sys.path.insert(0, os.environ["CODEX_TEST_MODULES"])
from test_codex_wrapper import frame, wrapper
root = Path(os.environ["CODEX_FAKE_ROOT"])
is_server = sys.argv[1] == "app-server"
(root / ("server.json" if is_server else "tui.json")).write_text(json.dumps({"pid": os.getpid(), "args": sys.argv[1:], "cwd": os.getcwd()}))
parser = wrapper.WebSocketObserver(lambda message: messages.append(message))
parser.upgraded = True
messages = []
def read_message(peer):
    while not messages:
        data = peer.recv(65536)
        if not data:
            raise EOFError()
        parser.feed(data)
    return messages.pop(0)
def header(peer):
    data = b""
    while b"\r\n\r\n" not in data:
        data += peer.recv(1)
    return data
if is_server:
    path = sys.argv[sys.argv.index("--listen") + 1][7:]
    listener = socket.socket(socket.AF_UNIX)
    listener.bind(path)
    listener.listen(1)
    peer, _ = listener.accept()
    peer.settimeout(5)
    assert header(peer).startswith(b"GET ")
    peer.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n\r\n")
    request = read_message(peer)
    assert request["method"] == "thread/resume"
    peer.sendall(frame({"id": request["id"], "result": {"thread": {"id": "fake-thread", "status": {"type": "idle"}}}}))
    for method, params in [
        ("turn/started", {"turn": {"id": "fake-turn", "status": "inProgress"}}),
        ("thread/status/changed", {"status": {"type": "active", "activeFlags": ["waitingOnApproval"]}}),
        ("item/commandExecution/requestApproval", {"turnId": "fake-turn", "command": "not-executed"}),
    ]:
        peer.sendall(frame({"id": 55, "method": method, "params": {"threadId": "fake-thread", **params}}))
        time.sleep(.1)
    reply = read_message(peer)
    (root / "approval.json").write_text(json.dumps(reply))
    assert reply == {"id": 55, "result": {"decision": "decline"}}
    peer.sendall(frame({"method": "thread/status/changed", "params": {"threadId": "fake-thread", "status": {"type": "active", "activeFlags": []}}}))
    time.sleep(.1)
    peer.sendall(frame({"method": "turn/completed", "params": {"threadId": "fake-thread", "turn": {"id": "fake-turn", "status": "completed"}}}))
    time.sleep(30)
else:
    peer = socket.socket(socket.AF_UNIX)
    peer.connect(sys.argv[sys.argv.index("--remote") + 1][7:])
    peer.settimeout(5)
    peer.sendall(b"GET / HTTP/1.1\r\nUpgrade: websocket\r\n\r\n")
    header(peer)
    peer.sendall(frame({"id": 10, "method": "thread/resume", "params": {"threadId": "fake-thread"}}, mask=True))
    while True:
        message = read_message(peer)
        if message.get("method") == "item/commandExecution/requestApproval":
            peer.sendall(frame({"id": 55, "result": {"decision": "decline"}}, mask=True))
        if message.get("method") == "turn/completed":
            break
    peer.close()
    sys.exit(7)
'''
        with tempfile.TemporaryDirectory(prefix="itc-test-", dir="/tmp") as directory:
            fake = Path(directory) / "codex"
            fake.write_text(fake_source)
            fake.chmod(0o700)
            session_id = "A1B2C3D4-E5F6-47A8-9B0C-D1E2F3A4B5C6"
            bridge_spec = importlib.util.spec_from_file_location(
                "launch_bridge_fixture", Path(__file__).parents[2] / "iTermateBridge/test_codex_status.py"
            )
            bridge_module = importlib.util.module_from_spec(bridge_spec)
            bridge_spec.loader.exec_module(bridge_module)
            import asyncio
            receiver = bridge_module.RecordingBridge()
            receiver.app.get_session_by_id = lambda value: object() if value == session_id else None
            receiver.set_session_status(session_id, "running")
            sent, acknowledgements, received = [], [], []
            def exchange(path, request, bridge=False):
                sent.append(dict(request))
                asyncio.run(receiver.handle_command(None, json.dumps(request).encode()))
                accepted, error = receiver.responses[-1]
                acknowledgements.append((accepted, error))
                received.append(dict(receiver.session_statuses.get(session_id, {})))
                return accepted, None if accepted else "rejected"
            environment = {"CODEX_FAKE_ROOT": directory, "CODEX_TEST_MODULES": str(Path(__file__).parent)}
            with patch.dict(os.environ, environment), patch.object(wrapper.shutil, "which", return_value=str(fake)), \
                    patch.object(reporter, "iterm_session_id", return_value=session_id), \
                    patch.object(reporter, "exchange", side_effect=exchange):
                self.assertEqual(wrapper.run(["-C", directory, "-c", 'model="example"', "resume", "fake-thread"], reporter), 7)
            self.assertEqual(json.loads((Path(directory) / "approval.json").read_text()), {"id": 55, "result": {"decision": "decline"}})
            server = json.loads((Path(directory) / "server.json").read_text())
            self.assertEqual(server["args"][:3], ["app-server", "-c", 'model="example"'])
            self.assertEqual(server["cwd"], str(Path(directory).resolve()))
            tui = json.loads((Path(directory) / "tui.json").read_text())
            self.assertEqual(tui["args"][-4:], ["-c", 'model="example"', "resume", "fake-thread"])
            for process in (server, tui):
                with self.assertRaises(ProcessLookupError):
                    os.kill(process["pid"], 0)
            self.assertTrue(all(accepted for accepted, _ in acknowledgements), acknowledgements)
            self.assertEqual({request["sessionId"] for request in sent}, {session_id})
            for expected in ("idle", "running", "awaitingInput", "finished"):
                self.assertTrue(any(state.get("status") == expected and state.get("activityKind") == "agent" for state in received))
            self.assertNotIn(session_id, receiver.agent_managed_session_ids)
            states = [request["status"] for request in sent]
            self.assertIn("running", states)
            self.assertIn("awaitingInput", states)
            self.assertIn("finished", states)
            self.assertEqual(states[-1], "detached")

    def test_cleanup_only_targets_owned_process(self):
        from unittest.mock import Mock
        process = Mock(pid=12345)
        process.poll.return_value = None
        with patch.object(wrapper.os, "killpg") as kill:
            wrapper.stop_process(process, process_group=True)
        kill.assert_called_once_with(12345, wrapper.signal.SIGTERM)
        process.wait.assert_called_once_with(timeout=3)


if __name__ == "__main__":
    unittest.main()
