"""运行前冻结开发集、留出集、提示词候选及选择规则。"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PREVIOUS = ROOT.parents[1] / 'evaluate-agent-directed-questions/evidence'
old = json.loads((PREVIOUS/'suite.json').read_text())
# 每组只描述最后一条助手消息，不提供先前对话，也不使用真实用户记录。
pairs = [
 ('question','path','你的项目目前放在哪个目录里？','Where is your project directory located?'),
 ('question','version','你当前安装的应用版本是多少？','What version of the application do you have installed?'),
 ('question','time','这个问题是从昨天开始出现的吗？','Did this problem start occurring yesterday?'),
 ('question','permission','现在可以由我重启这个进程吗？','May I restart this process now?'),
 ('question','optional','报告已经导出。你还想要一份 CSV 吗？','The report has been exported. Would you also like a CSV copy?'),
 ('question','format','你想要 JSON 格式，还是纯文本格式？','Would you prefer JSON or plain text?'),
 ('question','no-mark','你准备把文件保存到哪里','Where would you like to save the file'),
 ('question','short','现在发布？','Publish now?'),
 ('question','question-before-statement','要保留备份吗？两种选择都可以。','Should I keep a backup? Either choice is fine.'),
 ('question','polite','方便告诉我重现这个错误的步骤吗？','Could you tell me the steps to reproduce this error?'),
 ('question','markdown','检查完成。\n\n**你想先处理哪个错误？**','The inspection is complete.\n\n**Which error would you like to address first?**'),
 ('question','bullet','我需要确认两点：\n- 要保留原文件吗？\n- 输出放在哪个文件夹？','I have two questions:\n- Should I keep the original file?\n- Which folder should contain the output?'),
 ('question','quoted-and-real','说明书举例写着“确认吗？”。不过针对当前改动，你同意保留旧接口吗？','The manual gives the example "Confirm?". For the current change, do you agree to retain the old interface?'),
 ('question','completed-then-check','补丁已生成。你能在预览里看到新的按钮吗？','The patch has been generated. Can you see the new button in the preview?'),
 ('question','negative-context','无需再讨论上周的问题。今天的修改要发到正式环境吗？','There is no need to revisit last week\'s issue. Should today\'s changes go to production?'),
 ('question','not-blocking','脚本会照常运行。顺便问一下，你希望通知使用中文吗？','The script will keep running normally. By the way, would you like notifications in Chinese?'),
 ('question','reason','你为什么希望禁用自动更新？','Why would you like to disable automatic updates?'),
 ('question','embedded-direct','关于文件名，我想问的是：你希望使用哪个前缀？','Regarding the filename, my question is: which prefix would you like?'),
 ('question','confirmation','我理解你只想导出本月的数据，对吗？','My understanding is that you only want to export this month\'s data. Is that correct?'),
 ('question','mixed-message','我已找到原因，也没有改动文件。是否由我现在修复？确认后才会写入。','I found the cause and have not changed any files. Should I fix it now? I will only write after confirmation.'),
 ('normal','completion','索引重建完毕，所有文件都已同步。','The index has been rebuilt and all files are synchronized.'),
 ('normal','implicit-gate','等你同意这个计划，我再生成安装包。','Once you approve this plan, I will generate the installer.'),
 ('normal','paused','任务暂停中，仍在等待你的许可。','The task is paused and is still waiting for your permission.'),
 ('normal','imperative','请提供设备编号，然后我会继续排查。','Please provide the device identifier, then I will continue investigating.'),
 ('normal','choose-command','从下面两个路径中选一个作为输出目录。','Choose one of the following two paths as the output directory.'),
 ('normal','confirm-command','请核对这份清单并确认。','Please check this list and confirm.'),
 ('normal','self-answer','为什么没有通知？因为权限被关闭了。我已在上面说明开启方法。','Why was there no notification? Because permission was disabled. I explained how to enable it above.'),
 ('normal','heading','### 如何导出数据？\n点击导出按钮，选择文件夹即可。','### How do you export data?\nClick Export and choose a folder.'),
 ('normal','quote','这条日志记录了用户昨天的问题：“什么时候发布？”','This log records the user\'s question from yesterday: "When will it be released?"'),
 ('normal','code','用于测试的字符串如下，不是当前对话的问题：\n```js\nconst message = "要保存吗？";\n```','This is a test string, not a question in the current conversation:\n```js\nconst message = "Save it?";\n```'),
 ('normal','reported-question','团队正在讨论是否采用新数据库，目前还没有决定。','The team is discussing whether to adopt the new database. No decision has been made yet.'),
 ('normal','historical-approval','你刚才确认过要删除缓存，所以我已经完成清理。','You just confirmed that the cache should be deleted, so I have completed the cleanup.'),
 ('normal','no-response','无需回答这条消息，结果已经写入报告。','No response to this message is needed; the results are already in the report.'),
 ('normal','autonomous-progress','正在打包应用，结束后会自动保存，无需用户操作。','The application is being packaged and will be saved automatically. No user action is required.'),
 ('normal','suggestion','建议先备份文件，再修改配置。','I recommend backing up the file before modifying the configuration.'),
 ('normal','future-invitation','以后需要重新导出时，再通知我即可。','Let me know if you need another export in the future.'),
 ('normal','ui-label','按钮文字已改为“是否重试？”，这是界面文案。','The button label has been changed to "Retry?". This is interface copy.'),
 ('normal','instruction-to-other','你可以向管理员询问“我是否有访问权限？”，然后按其答复操作。','You can ask the administrator "Do I have access?" and follow their response.'),
 ('normal','rhetorical-explained','谁会想丢失文件呢？这只是说明备份很重要，并不是要你作答。','Who would want to lose files? This is just a rhetorical point about backups, not a request for an answer.'),
 ('normal','document-dialogue','下面是文档示例对话：\n助手：要打开预览吗？\n用户：不用。\n示例到此结束。','Here is a sample dialogue for the documentation:\nAssistant: Open the preview?\nUser: No.\nEnd of example.'),
]
heldout=[]
for expected,category,zh,en in pairs:
 for language,text in [('zh',zh),('en',en)]:heldout.append(dict(id=f'{expected}-{language}-{category}',expected=expected,category=category,language=language,text=text))
assert len(heldout)==80 and len({x['text'] for x in heldout})==80
assert not {x['text'] for x in heldout}&{x['text'] for x in old['rows']}
normal='No question is being asked of the user.'
question='The assistant is asking the user a question.'
examples='Examples: "May I begin making the changes?" -> question; "确认后，我会修改解析逻辑并重新评审。" -> normal; "Please confirm the scope before I begin." -> normal; "Why did the build fail? A dependency was missing." -> normal; "Which version would you like to keep" -> question; "The documentation is done. Would you like me to update the examples too?" -> question.'
variants=[
 dict(id='baseline',kind='choice',instructions=old['instructions'],criteria=old['criteria']),
 dict(id='minimal',kind='choice',instructions='Is the assistant asking the user a question in this message?',criteria={'normal':normal,'question':question}),
 dict(id='speech-act',kind='choice',instructions='Classify the assistant message as a question addressed to the user or a non-question. Requests and waiting statements are not questions. Ignore quoted, code, rhetorical and self-answered questions.',criteria={'normal':'Statement, command, request, quotation, example, or explanation; not an actual question to the user.','question':'An actual interrogative addressed to the user, asking for an answer. Includes optional follow-up questions.'}),
 dict(id='grammar',kind='choice',instructions='Does the assistant use an interrogative to ask the user something? Interrogatives may lack punctuation. A command such as "Please confirm" and a conditional such as "Once you confirm" are not interrogatives. Ignore questions inside examples or answered by the assistant.',criteria={'normal':'No genuine user-directed interrogative.','question':'Contains a genuine user-directed interrogative.'}),
 dict(id='chinese',kind='choice',instructions='判断这条助手回复是否真的在向用户提问。疑问表达即使没有问号也算，完成工作后的追问也算。仅陈述等待确认、命令或请求不算提问。排除引用、代码示例、自问自答和说明标题。判断整条消息，不是只看末句。',criteria={'normal':'没有向用户提出实际问题；包括陈述、祈使请求、等待确认、引用和自问自答。','question':'助手以疑问表达向用户提问，希望用户回答这个问题。'}),
 dict(id='bilingual',kind='choice',instructions='Is there an actual question from the assistant to the user? 是否真的在向用户提问？Do not count commands, waiting-for-approval statements, quotations or self-answered questions. 命令、等待确认、引用和自问自答不算。',criteria={'normal':'No actual question to the user / 没有向用户提问','question':'Actual question to the user / 确实向用户提问'}),
 dict(id='examples',kind='choice',instructions='Decide whether the assistant actually asks the user a question. Ignore questions in quotations, code, headings answered below, and self-answered questions. '+examples,criteria={'normal':normal,'question':question}),
 dict(id='recipient',kind='choice',instructions='Read the message as the user receiving it. Is the assistant directly asking YOU a question, rather than describing, quoting or answering a question? Classify statements, instructions and requests without an interrogative as normal.',criteria={'normal':'No interrogative question addressed to me.','question':'An interrogative question addressed to me.'}),
 dict(id='noul',kind='noul',instructions='Does this assistant message contain a genuine question directed to the user? Exclude commands, implicit approval gates, quotes, code, rhetorical and self-answered questions.',criteria={'false':'No actual question to the user.','true':'At least one actual question to the user.'}),
 dict(id='typed-answer',kind='choice',instructions=old['instructions'],criteria=old['criteria'],typed_state=True),
 dict(id='typed-examples',kind='choice',instructions='Determine whether the assistant asks the user an actual question. '+examples,criteria={'normal':normal,'question':question},typed_state=True),
 dict(id='positive-first',kind='choice',instructions='Does the assistant ask a question of the user? A literal question mark alone is insufficient. Statements awaiting permission and imperative requests are not questions. Exclude quotes, code and self-answered questions.',criteria={'question':question,'normal':normal}),
]
policy={'goal':'整体accuracy严格超过90%，不是precision超过90%。','selection':'开发集accuracy最高；并列时取中英文较低组accuracy较高者；再并列取候选列表中较早者。阈值固定0.5，不用留出集选择。','holdout':'选定提示词后仅验收所选项与预先指定baseline；不得根据留出结果继续调优或替换胜者。','limits':'80条留出数据仍由同一作者合成标注，非独立人工盲标；不同场景及近义结构可能相关；点估计超过90%不证明生产准确率或置信下限超过90%。','rounds':2}
for name,data in [('development.json',old['rows']),('holdout.json',heldout),('prompts.json',variants),('policy.json',policy)]:
 p=ROOT/name;assert not p.exists();p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
manifest={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['development.json','holdout.json','prompts.json','policy.json']}
(ROOT/'frozen-inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
