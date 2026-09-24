#!/usr/bin/env python3
"""验证 Jev 选择题 API；实际运行可能计费，--dry-run 不联网也不读取密钥。

接口依据：https://api.typesafe.ai/openapi.json
凭据来源：TYPESAFE_API_KEY，或 macOS 钥匙串的 typesafe-api-key。
"""

import argparse
import getpass
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request


API_URL = "https://api.typesafe.ai/v1/systemone"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # 不把 Authorization 转发给重定向目标。
        return None


def load_api_key():
    key = os.environ.get("TYPESAFE_API_KEY", "").strip()
    if not key and sys.platform == "darwin":
        try:
            result = subprocess.run(
                [
                    "/usr/bin/security", "find-generic-password",
                    "-a", getpass.getuser(), "-s", "typesafe-api-key", "-w",
                ],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ValueError("无法读取钥匙串，或授权等待超过 30 秒。") from error
        if result.returncode == 0:
            key = result.stdout.strip()
    if not key:
        raise ValueError("未找到密钥：请设置 TYPESAFE_API_KEY 或检查钥匙串授权。")
    if not key.isascii() or any(char.isspace() or ord(char) < 32 or ord(char) == 127 for char in key):
        raise ValueError("密钥格式无效：必须是无空白字符的 ASCII 字符串。")
    return key


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="jev-latest", help="模型名称或别名（默认 jev-latest）")
    parser.add_argument("--dry-run", action="store_true", help="只显示示例请求，不读取密钥、不联网")
    args = parser.parse_args()
    payload = {
        "model": args.model,
        "state": "I was charged twice for the same order. Please help me get a refund.",
        "questions": {
            "department": {
                "type": "choice",
                "instructions": "Which support department should handle this message?",
                "criteria": {
                    "technical_support": "Software bugs, crashes, or connection problems.",
                    "billing": "Charges, payments, invoices, or refunds.",
                    "account_management": "Account profiles, passwords, or login access.",
                },
            },
        },
    }
    if args.dry_run:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    try:
        key = load_api_key()
        request = urllib.request.Request(
            API_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )
        print("提交一次 Jev 推理请求（可能计费；不会自动重试）……", flush=True)
        started = time.perf_counter()
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
            result = json.load(response)
        elapsed = time.perf_counter() - started
        if not isinstance(result, dict):
            raise ValueError("API 返回的 JSON 不是预期的对象。")
        answers = result.get("answers")
        answer = answers.get("department") if isinstance(answers, dict) else None
        if not isinstance(answer, dict) or answer.get("type") != "choice":
            raise ValueError("API 未返回 department 选择题答案。")
        if answer.get("choice") not in payload["questions"]["department"]["criteria"]:
            raise ValueError("API 返回的选项不在给定列表中。")
        # 将潜在回显的凭据脱敏后再输出，包括 JSON 转义形式。
        output = json.dumps(result, ensure_ascii=False, indent=2)
        output = output.replace(json.dumps(key, ensure_ascii=False)[1:-1], "[REDACTED]")
        print(output)
        print(f"端到端耗时：{elapsed:.3f} 秒（包含网络时间）")
        print("示例预期选项：billing；单个示例不能证明整体准确率。")
        return 0
    except urllib.error.HTTPError as error:
        hints = {
            401: "密钥无效或已过期。",
            403: "账户没有访问权限。",
            402: "请检查账户余额或计费状态。",
            422: "请求或模型名称无效，请核对官方 API 文档。",
            429: "请求受限，请稍后手动重试。",
        }
        print(f"HTTP {error.code}：{hints.get(error.code, '服务请求失败（重定向也会被拒绝）。')}", file=sys.stderr)
        error.close()
    except (urllib.error.URLError, TimeoutError, OSError):
        print("网络、TLS 或读取失败；请求可能已到达服务端，不会自动重试。", file=sys.stderr)
    except (json.JSONDecodeError, UnicodeDecodeError):
        print("API 返回了无法解析的 JSON 响应。", file=sys.stderr)
    except ValueError as error:
        print(str(error), file=sys.stderr)
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("已取消；已发出的请求仍可能计费。", file=sys.stderr)
        sys.exit(130)
