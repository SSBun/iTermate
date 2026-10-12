"""仅依据第一轮开发错误设计第二轮候选；不读取留出内容或输出。"""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
assert not (ROOT/'selection.json').exists()
normal='No question is being asked of the user.'
question='The assistant is asking the user a question.'
variants=[
 dict(id='unanswered',kind='choice',instructions='Is the assistant asking the user an unanswered question in this message?',criteria={'normal':normal,'question':question}),
 dict(id='unanswered-detailed',kind='choice',instructions='Does this message ask the user a question that the assistant does not answer itself? A question in a quotation, code example or answered heading is not directed at the user. Commands and conditional statements are not questions.',criteria={'normal':'Statements, commands, explanations, quotations, or questions already answered within the message.','question':'An unanswered question directed to the user, including short questions such as "Continue?".'}),
 dict(id='minimal-zh',kind='choice',instructions='这条助手消息是在向用户发问吗？',criteria={'normal':'不是在向用户发问。','question':'是在向用户发问。'}),
 dict(id='minimal-reversed',kind='choice',instructions='Is the assistant asking the user a question in this message?',criteria={'question':question,'normal':normal}),
 dict(id='minimal-noul',kind='noul',instructions='Is the assistant asking the user a question in this message?',criteria={'false':normal,'true':question}),
 dict(id='speech-kind',kind='choice',instructions='What is the communicative form of this assistant message?',criteria={'normal':'A statement, imperative, instruction, explanation, or quotation; no interrogative directed to the user.','question':'An interrogative directed to the user, asking them something rather than explaining or quoting a question.'}),
 dict(id='boundary-examples',kind='choice',instructions='Is the assistant asking the user a question? "Continue?" is a question. "Please choose a version" is a command, not a question. "Why did it fail? A dependency was missing." is an explanation, not a question to the user. A question heading followed by its answer is not a question to the user.',criteria={'normal':normal,'question':question}),
 dict(id='unanswered-zh',kind='choice',instructions='助手是否向用户提出了一个需要用户作答、而不是助手已经自行解答的问题？“继续吗？”算提问；“请选择版本”是命令，不算提问；说明标题后面已有答案、自问自答、引用或代码中的问句不算。即使前文已完成工作或说旧问题不用回答，也要判断后面的新问题。',criteria={'normal':'没有实际向用户发问。','question':'有实际向用户发问。'}),
]
p=ROOT/'prompts-round2.json';assert not p.exists();p.write_text(json.dumps(variants,ensure_ascii=False,indent=2)+'\n')
(ROOT/'frozen-round2.json').write_text(json.dumps({'prompts-round2.json':hashlib.sha256(p.read_bytes()).hexdigest()},indent=2)+'\n')
