"""冻结新的向用户提问识别样本；不复用待回应标签。"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
pairs = [
    ("question", "choice", "你希望使用方案 A 还是 B？", "Which option do you prefer, A or B?"),
    ("question", "permission", "我可以开始修改了吗？", "May I begin making the changes?"),
    ("question", "optional-followup", "文档已经写完。是否还需要我更新示例？", "The documentation is done. Would you like me to update the examples too?"),
    ("question", "missing-information", "目标分支叫什么名字？", "What is the name of the target branch?"),
    ("question", "confirmation", "这个范围是否符合你的预期？", "Does this scope match what you expected?"),
    ("question", "no-question-mark", "你希望保留哪一个版本", "Which version would you like to keep"),
    ("question", "question-then-statement", "你想选哪个方案？我会等你的答复。", "Which plan would you like to choose? I will wait for your answer."),
    ("question", "quote-then-real", "日志里有“是否继续？”这个旧提示。你现在想重试吗？", "The log contains the old prompt 'Continue?'. Would you like to retry now?"),
    ("question", "old-negation-new-question", "旧问题不用回答。新方案是否按这个范围执行？", "No need to answer the old question. Should I implement the new plan within this scope?"),
    ("question", "debug-information", "你使用的是哪个操作系统？", "Which operating system are you using?"),
    ("question", "short", "要继续吗？", "Continue?"),
    ("question", "indirect-interrogative", "你能告诉我错误发生在什么时候吗？", "Could you tell me when the error occurred?"),
    ("normal", "completed", "已完成修改，编译通过。相关变更已经保存。", "The implementation is complete. The build passed and all changes are saved."),
    ("normal", "implicit-confirmation", "确认后，我会修改解析逻辑并重新评审。", "Once you confirm, I will modify the parser and review it again."),
    ("normal", "waiting-statement", "工作已暂停，等待你授权后继续。", "Work is paused until you authorize me to continue."),
    ("normal", "imperative-confirmation", "请确认范围后我再开始。", "Please confirm the scope before I begin."),
    ("normal", "imperative-choice", "请选择保留旧配置，或切换到新配置。", "Please choose whether to retain the old configuration or switch to the new one."),
    ("normal", "self-answered", "为什么构建失败？因为缺少依赖。我已经补齐依赖并完成构建。", "Why did the build fail? A dependency was missing. I have added it and completed the build."),
    ("normal", "quoted-example", "以下只是文档中的引用示例，不是在向你提问：\n> 你希望使用方案 A 还是 B？", "This is only a quoted documentation example, not a question to you:\n> Which option do you prefer, A or B?"),
    ("normal", "code-example", "示例代码如下：\n```python\nprint(\"是否继续？\")\n```", "Here is the example code:\n```python\nprint(\"Continue?\")\n```"),
    ("normal", "historical-question", "我之前问过你是否继续，你已经确认，现在任务完成。", "I previously asked whether to continue. You already confirmed, and the task is now complete."),
    ("normal", "negative-request", "请勿回复。工作已经完成，无需确认。", "Do not reply. The work is complete and no confirmation is needed."),
    ("normal", "question-heading", "## 如何配置？\n打开设置，填写路径，然后保存。这就是完整步骤。", "## How do you configure it?\nOpen Settings, enter the path, and save. Those are the complete steps."),
    ("normal", "future-gate", "确认后我会继续执行，直到测试通过。", "After you confirm, I will continue until the tests pass."),
]
rows = []
for expected, category, zh, en in pairs:
    for language, text in [("zh", zh), ("en", en)]:
        rows.append(dict(id=f"{expected}-{language}-{category}", expected=expected, category=category, language=language, split="new", text=text))
assert len(rows) == 48 and sum(row['expected'] == 'question' for row in rows) == 24
suite = dict(
    schema="itermate-agent-directed-question/v1", rounds=2, threshold=.5,
    instructions="Does this assistant message actually ask the user a question? Count direct questions even without a question mark or when work is already done. Ignore quoted/code questions and questions the assistant answers itself. Statements about waiting for confirmation and imperative requests are NOT questions. Judge the message, not terminal status or whether a reply is needed.",
    criteria={
        "normal": "No actual question directed at the user. Includes statements, imperative requests, implicit confirmation gates, quoted/code questions and self-answered questions.",
        "question": "The assistant actually asks the user a question seeking an answer, choice or confirmation. A question mark and a blocked task are not required.",
    },
    annotation_policy="按已确认边界判断向用户提问；仅等待确认的陈述不是问句。疑问句/疑问表达为正，命令句/请求句本身不是疑问表达；自问自答、文档标题和引用/代码中的问句为负。判断整条最后回答，而非只看最后一句。",
    limits="48条作者合成标注样本，不是独立盲标或生产分布；沿用部分旧文本但重新定义标签，不能把新旧准确率差归因于提示词单一因素。结果揭晓后不调提示词、标签或阈值。",
    rows=rows,
)
p = ROOT / 'suite.json'
assert not p.exists(), '禁止覆盖冻结样本'
p.write_text(json.dumps(suite, ensure_ascii=False, indent=2)+'\n')
print(hashlib.sha256(p.read_bytes()).hexdigest())
