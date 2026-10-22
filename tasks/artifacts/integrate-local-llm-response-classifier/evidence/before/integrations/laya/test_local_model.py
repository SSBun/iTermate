"""本地provider协议回归；只用临时文件，不启动模型或用户服务。"""
import importlib.util
import io
import json
from email.message import Message
from pathlib import Path
import tempfile
import threading
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location("local_model", Path(__file__).with_name("iTermate-laya.py"))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class LocalModelProtocolTests(unittest.TestCase):
    def test_provider_assets_are_separate_but_laya_stays_compatible(self):
        directory = Path("/isolated/Laya")
        self.assertEqual(helper.model_directory(directory, "laya"), directory)
        self.assertEqual(helper.model_directory(directory, "vela"), directory / "Vela")

    def test_question_contract_is_binary_and_not_terminal_state(self):
        state, questions = helper.validate_payload({"state": "May I proceed?", "questions": helper.QUESTION_QUESTIONS}, "vela")
        self.assertEqual(state, "May I proceed?")
        self.assertEqual(set(questions), {"question"})
        self.assertEqual(set(questions["question"]["criteria"]), {"question", "normal"})
        self.assertIn("implicit approval gates", questions["question"]["criteria"]["question"])
        self.assertIn("autonomous progress", questions["question"]["instructions"])
        self.assertNotIn("no interrogative", questions["question"]["criteria"]["normal"])

    def test_question_route_uses_the_product_participation_prompt_for_both_providers(self):
        # 仅验证协议和提示词路由；语义准确率由独立真实模型评估负责。
        for provider in ("laya", "vela"):
            seen = []
            def predict(state, questions):
                seen.append((state, questions))
                return {"answers": {"question": {"type": "choice", "choice": "question",
                                                 "probabilities": {"question": 0.8, "normal": 0.2}}}}
            state = "确认后我再继续。"
            body = json.dumps({"state": state, "questions": {"ignored": {}}}).encode()
            handler = helper.Handler.__new__(helper.Handler)
            handler.path = "/v1/question"
            handler.headers = Message()
            handler.headers["Content-Type"] = "application/json"
            handler.headers["Content-Length"] = str(len(body))
            handler.rfile = io.BytesIO(body)
            handler.authorized = lambda: True
            replies = []
            handler.reply = lambda status, payload: replies.append((status, payload))
            handler.server = SimpleNamespace(
                provider=provider, instance="test-instance", model_id="test-model",
                inference=threading.Lock(),
                agent=SimpleNamespace(tok=lambda text: {"input_ids": list(range(len(text.split())))},
                                      cfg={"max_len": 8192}, predict=predict),
            )
            handler.do_POST()
            self.assertEqual(seen, [(state, helper.QUESTION_QUESTIONS)])
            self.assertEqual(replies[0][0], 200)
            self.assertEqual(replies[0][1]["provider"], provider)
            self.assertEqual(replies[0][1]["instance"], "test-instance")
            self.assertFalse(handler.server.inference.locked())

    def test_session_contract_uses_only_two_participation_states(self):
        _, questions = helper.validate_payload({"state": "请确认范围。", "questions": helper.SESSION_QUESTIONS}, "vela")
        self.assertEqual(set(questions), {"state"})
        self.assertEqual(set(questions["state"]["criteria"]), {"idle", "awaitingInput"})
        self.assertEqual(questions["state"]["instructions"], helper.QUESTION_QUESTIONS["question"]["instructions"])
        self.assertEqual(questions["state"]["criteria"]["awaitingInput"], helper.QUESTION_QUESTIONS["question"]["criteria"]["question"])

    def test_vela_score_requires_two_levels_without_breaking_legacy_laya(self):
        payload = {"state": "example", "questions": {"level": {"type": "score", "instructions": "Rate", "criteria": ["one"]}}}
        helper.validate_payload(payload, "laya")
        with self.assertRaises(ValueError):
            helper.validate_payload(payload, "vela")

    def test_question_body_is_not_silently_truncated(self):
        with self.assertRaises(ValueError):
            helper.validate_payload({"state": "x" * 3001, "questions": helper.QUESTION_QUESTIONS}, "vela")

    def test_unverified_vela_files_are_rejected_before_remote_code_import(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "model.safetensors").write_bytes(b"not verified weights")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                helper.verify_vela(root)


if __name__ == "__main__":
    unittest.main()
