"""用固定合成样例对比分类提示词；只访问本机 Ollama，不读取真实会话或修改配置。"""
import ast
import hashlib
import json
from pathlib import Path
import re
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "integrations/pi/iTermate-integration.ts"
MODEL = "qwen3.5:2b"
DIGEST = "dfaf2605162e689c8cac330dc4a190c4c50ad30aa47814a8fe9b79fa5127e97e"
SAMPLES = [
    ("restart-report", "normal", '因为修复还没加载到当前运行的 App：当前进程启动于 15:51，而修复后的构建在 15:57 才完成，我没有替你重启。\n\n请退出当前 iTermate，再运行本次构建的 App（"/Users/caishilin/Desktop/personal/iTermate/.build/codex-finished-seen-idle/Build/Products/Debug/iTermate.app"）。\n\n截图已显示选中高亮，不是你没选中；新版本的真实交互仍需这一步验证。'),
    ("install-instructions", "normal", "安装完成后，请在系统设置中开启辅助功能权限。"),
    ("verification-instructions", "normal", "修复已完成，尚未执行测试。你可以运行以下命令验证：npm test。"),
    ("approval", "question", "需要重启 App 才能继续验证，是否允许我现在重启？"),
    ("choice", "question", "你希望保留原来的交互，还是改成单击展开？"),
    ("missing-information", "question", "请提供当前版本号和错误日志，我才能继续定位。"),
    ("implicit-gate", "question", "方案已整理，等你确认后我再开始修改。"),
    ("mixed-report-and-question", "question", "修复已经完成。要不要我现在替你重启 App？"),
    ("autonomous-progress", "normal", "我会继续检查其他调用方，完成后汇报。"),
    ("quoted-question", "normal", "已将示例中的‘是否允许重启？’保留为测试数据，不需要你回答。"),
    ("english-instructions", "normal", "The fix is built. Please restart the app to load it and verify the behavior."),
    ("english-gate", "question", "Please send the failing command and its output so I can continue debugging."),
]


def request(path, payload=None, timeout=10):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request("http://127.0.0.1:11434" + path, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(req, timeout=timeout) as response:
        return json.load(response)


def main():
    phase = sys.argv[1]
    if phase not in ("before", "after"):
        raise ValueError("Expected before or after")
    source = SOURCE.read_text()
    classifier = source.split("export async function classifyReplyWithModel", 1)[1]
    match = re.search(r"completeLocalLLM\(\s*('(?:[^'\\]|\\.)*'|`[^`]*`)", classifier)
    if not match:
        raise ValueError("Cannot extract production prompt")
    literal = match.group(1)
    prompt = literal[1:-1] if literal.startswith("`") else ast.literal_eval(literal)
    inventory = request("/api/tags")
    if not any(m.get("name") == MODEL and m.get("digest") == DIGEST for m in inventory["models"]):
        raise ValueError("Pinned diagnostic model unavailable; no fallback")
    report = {"phase": phase, "model": MODEL, "digest": DIGEST,
              "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
              "prompt": prompt, "rows": []}
    for name, expected, text in SAMPLES:
        started = time.monotonic()
        row = {"id": name, "expected": expected, "text": text}
        try:
            value = request("/api/chat", {
                "model": MODEL, "stream": False, "think": False, "keep_alive": "10m",
                "messages": [{"role": "system", "content": prompt}, {"role": "user", "content": text}],
                "options": {"temperature": 0, "seed": 42, "num_ctx": 16384, "num_predict": 32},
            })
            row["output"] = value.get("message", {}).get("content")
            if (value.get("model") != MODEL or value.get("done") is not True
                    or value.get("done_reason") != "stop" or value.get("message", {}).get("thinking")):
                raise ValueError("Incomplete or unexpected model response")
            answer = json.loads(row["output"])
            if not isinstance(answer, dict) or set(answer) != {"label"} or answer["label"] not in ("normal", "question"):
                raise ValueError("Invalid binary JSON")
            row["actual"] = answer["label"]
            row["passed"] = row["actual"] == expected
        except Exception as error:
            row["error"] = type(error).__name__
            row["passed"] = False
        row["seconds"] = round(time.monotonic() - started, 3)
        report["rows"].append(row)
        print(name, row.get("actual", row.get("error")), "PASS" if row["passed"] else "FAIL", flush=True)
    report["passed"] = sum(row["passed"] for row in report["rows"])
    report["total"] = len(report["rows"])
    (Path(__file__).parent / (phase + ".json")).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f'{report["passed"]}/{report["total"]}')


if __name__ == "__main__":
    main()
