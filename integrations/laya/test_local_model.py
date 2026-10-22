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
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("local_model", Path(__file__).with_name("iTermate-laya.py"))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class LocalModelProtocolTests(unittest.TestCase):
    def setUp(self):
        # 仅在隔离回归中启用保留实现；生产模块默认禁止所有旧服务入口。
        enabled = patch.object(helper, "LEGACY_DECISIONS_ENABLED", True)
        enabled.start()
        self.addCleanup(enabled.stop)

    def test_production_gate_blocks_server_and_model_entrypoints(self):
        with patch.object(helper, "LEGACY_DECISIONS_ENABLED", False):
            with self.assertRaises(RuntimeError):
                helper.Server(("127.0.0.1", 0), helper.Handler)
            with self.assertRaises(RuntimeError):
                helper.LocalLLMAgent().predict("reply", helper.QUESTION_QUESTIONS)
            with self.assertRaises(RuntimeError):
                helper.serve(Path("/not-created"), 1, 0)

    def test_provider_assets_are_separate_but_laya_stays_compatible(self):
        directory = Path("/isolated/Laya")
        self.assertEqual(helper.model_directory(directory, "laya"), directory)
        self.assertEqual(helper.model_directory(directory, "vela"), directory / "Vela")
        self.assertEqual(helper.model_directory(directory, "local-llm"), directory / "LocalLLM")

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

    def test_local_llm_uses_fixed_model_and_validated_labels_without_fake_probabilities(self):
        for label in ("normal", "question"):
            response = {"model": helper.LOCAL_LLM_ID, "done": True, "done_reason": "stop",
                        "message": {"content": json.dumps({"label": label})}}
            with patch.object(helper, "ollama_model_available", return_value=True), \
                    patch.object(helper, "ollama_request", return_value=response) as request:
                result = helper.LocalLLMAgent().predict("A reply", helper.QUESTION_QUESTIONS)
                value = result["answers"]["question"]
                self.assertEqual(value, {"type": "choice", "choice": label, "source": "local-llm"})
                payload = request.call_args.args[1]
                self.assertEqual(payload["model"], "qwen3.5:2b")
                self.assertFalse(payload["think"])
                self.assertEqual(payload["options"]["num_predict"], 32)
                self.assertEqual(request.call_args.kwargs["timeout"], 6)

    def test_local_llm_rejects_invalid_or_incomplete_output(self):
        for content in ["not json", "{}", '{"label":"other"}', '{"label":{}}',
                        '{"label":"normal","confidence":1}']:
            response = {"model": helper.LOCAL_LLM_ID, "done": True, "done_reason": "stop",
                        "message": {"content": content}}
            with patch.object(helper, "ollama_model_available", return_value=True), \
                    patch.object(helper, "ollama_request", return_value=response):
                with self.assertRaises(ValueError):
                    helper.LocalLLMAgent().predict("A reply", helper.QUESTION_QUESTIONS)
        with self.assertRaises(ValueError):
            helper.LocalLLMAgent().predict("A reply", {"arbitrary": {}})

    def test_local_llm_missing_model_is_not_a_normal_reply(self):
        with patch.object(helper, "ollama_model_available", return_value=False), \
                patch.object(helper, "ollama_request") as request:
            with self.assertRaises(ValueError):
                helper.LocalLLMAgent().predict("A reply", helper.QUESTION_QUESTIONS)
            request.assert_not_called()

    def test_local_llm_deployment_reuses_existing_weights_without_hub_dependencies(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(helper, "ollama_model_available", return_value=True), \
                patch.object(helper, "emit"):
            helper.download(Path(directory), "local-llm")
            marker = json.loads((Path(directory) / "LocalLLM/model.json").read_text())
            self.assertEqual(marker["model"], helper.LOCAL_LLM_ID)
            self.assertEqual(marker["revision"], helper.LOCAL_LLM_DIGEST)

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
