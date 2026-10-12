"""冻结合成评估集与模型版本；不包含真实会话。"""
import hashlib
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parent
source = ROOT.parents[3] / "integrations/laya/answer-types.test.ts"
rows = []
for match in re.finditer(r'\{ id: ("(?:[^"\\]|\\.)*"), expected: ("\w+"), text: ("(?:[^"\\]|\\.)*") \}', source.read_text()):
    ident, expected, text = [json.loads(x) for x in match.groups()]
    rows.append(dict(id=ident, expected=expected, text=text, language="zh" if "-zh-" in ident else "en", split="regression"))
assert len(rows) == 16
pairs = [
    ("normal", "done", "修复已经合入，本轮没有需要你处理的事项。", "The fix has been merged. There is nothing you need to do this round."),
    ("normal", "historical", "得到你的确认后，我开始了测试，现在测试已结束。", "After receiving your approval, I started the tests. They have now finished."),
    ("normal", "negative", "不必确认这个范围，我已经按照之前的授权完成了工作。", "Do not confirm this scope again. I finished the work under your earlier authorization."),
    ("normal", "quote", "日志中的最后一行是“是否继续？”，这是旧日志，不是当前请求。", "The last line of the log says 'Continue?'. That is an old log, not a current request."),
    ("normal", "rhetorical", "为什么会这样？原因是缓存未刷新；刷新后问题已经消失。", "Why did this happen? The cache was stale; refreshing it has already resolved the issue."),
    ("normal", "deferred", "下次需要部署时再告诉我即可。本次文档更新已经完成。", "Let me know next time you need a deployment. This documentation update is finished."),
    ("normal", "progress", "我正在检查依赖，接下来会自动继续构建，不需要你操作。", "I am checking dependencies and will continue the build automatically. No action is needed from you."),
    ("normal", "code", "示例代码是 print(\"请确认后继续\")，以上只是代码说明。", "The sample code is print(\"Please confirm to proceed\"). This is only an explanation of code."),
    ("question", "permission", "可以删除这些临时文件吗？我会等你确认再操作。", "May I delete these temporary files? I will wait for your approval."),
    ("question", "implicit", "收到你的确认，我再开始部署。", "Once you confirm, I will begin the deployment."),
    ("question", "choice", "请选择保留旧配置，或切换到新配置。", "Please choose whether to retain the old configuration or switch to the new one."),
    ("question", "missing", "还缺少目标分支名称，请提供后我再创建请求。", "I still need the target branch name. Please provide it before I create the request."),
    ("question", "mixed", "旧问题不用回答。新方案是否按这个范围执行？", "No need to answer the old question. Should I implement the new plan within this scope?"),
    ("question", "future", "你确认之后，我将一直重试直到构建成功。", "After you confirm, I will keep retrying until the build succeeds."),
    ("question", "block", "工作已暂停，等待你授权后继续。", "Work is paused until you authorize me to continue."),
    ("question", "done-plus", "文档已经写完。是否还需要我更新示例？", "The documentation is done. Would you like me to update the examples too?"),
]
for label, name, zh, en in pairs:
    for language, text in [("zh", zh), ("en", en)]:
        rows.append(dict(id=f"new-{label}-{language}-{name}", expected=label, text=text, language=language, split="new"))
instructions = "Does this assistant message currently request or await a user reply, choice, information or permission? Include implicit confirmation gates. Ignore quoted/code examples, self-answered questions and past approvals. Classify the need for a user response, not terminal activity."
criteria = {
    "normal": "No user response is currently requested or awaited; includes completed reports, autonomous progress, quoted questions and past approvals.",
    "question": "The assistant currently asks or waits for the user to reply, choose, provide information or authorize an action, including implicit confirmation gates.",
}
suite = dict(schema="itermate-decision-eval/v1", instructions=instructions, criteria=criteria, rows=rows, threshold=0.5, rounds=2, limitations="48条人工合成样本；16条历史回归及32条新样本；冻结后不调提示词或阈值。新样本不是独立人工盲标，不代表生产分布。")
(ROOT / "suite.json").write_text(json.dumps(suite, ensure_ascii=False, indent=2) + "\n")
models = {"gliner": "fastino/GLiNER2.5-multi-Decide", "gliclass": "knowledgator/gliclass-multilang-mini", "vela": "vllm-sr/Vela-2.0-0.3B", "kev": "jaredpalmer/kev-0.8b", "qwen-base": "Qwen/Qwen3-0.6B", "d1": "LiquidAI/d1-3b"}
manifest = {}
for name, repo in models.items():
    with urllib.request.urlopen(f"https://huggingface.co/api/models/{repo}", timeout=60) as response:
        info = json.load(response)
    manifest[name] = dict(repo=repo, revision=info["sha"], files=[x["rfilename"] for x in info["siblings"]])
(ROOT / "models.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(dict(samples=len(rows), suite_sha256=hashlib.sha256((ROOT / "suite.json").read_bytes()).hexdigest(), models=manifest), indent=2))
