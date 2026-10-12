"""本地provider协议回归；只用临时文件，不启动模型或用户服务。"""
import importlib.util
from pathlib import Path
import tempfile
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
        self.assertIn("interrogative", questions["question"]["criteria"]["question"])

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
