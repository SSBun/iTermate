"""冻结参与判定回归集；重标旧文本，不冒称新的盲测留出集。"""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parents[4]
spec=importlib.util.spec_from_file_location('helper',PROJECT/'integrations/laya/iTermate-laya.py')
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
old=PROJECT/'tasks/artifacts/optimize-vela-question-prompt/evidence/holdout.json'
rows=json.loads(old.read_text())
# 删去5组重复的直接问法，加入5组非交互报告，保持四个语言/类别格各20条。
remove={'path','version','time','reason','format'}
participation={'implicit-gate','paused','imperative','choose-command','confirm-command'}
rows=[r for r in rows if not (r['expected']=='question' and r['category'] in remove)]
for row in rows:
    row['prior_grammar_label']=row['expected']
    if row['category'] in participation:row['expected']='question'
    row['id']=f"{row['language']}-{row['category']}"
    row['origin']='historical-relabelled'
    if row['category']=='implicit-gate':
        row['text']='确认后我再继续。' if row['language']=='zh' else 'Once you confirm, I will continue.'
    if row['category']=='confirm-command':
        row['text']='请确认范围。' if row['language']=='zh' else 'Please confirm the scope.'
    if row['category']=='imperative':
        row['text']='请提供项目路径，然后我再继续。' if row['language']=='zh' else 'Please provide the project path before I continue.'
    if row['category']=='choose-command':
        row['text']='请选择方案 A 或 B。' if row['language']=='zh' else 'Please choose plan A or B.'
    if row['category']=='instruction-to-other':
        row['text']='以下是文档中的引用示例，不是当前要求：你可以向管理员询问“我是否有访问权限？”。' if row['language']=='zh' else 'This is a quoted documentation example, not a current request: You can ask the administrator "Do I have access?".'
extra=[
 ('saved','修改已保存，验证通过。没有需要你补充的内容。','The changes are saved and verification passed. Nothing further is needed from you.'),
 ('automatic-retry','构建还没有完成，我会自动重试并在结束后报告。','The build is not complete. I will retry automatically and report when it finishes.'),
 ('historical-success','确认后我提交成功，测试通过。','After your confirmation, I submitted successfully and the tests passed.'),
 ('reference-command','文档中的示例是“请确认范围”，这里只解释这句话，不需要你确认。','The documentation example is "Please confirm the scope". I am only explaining it, not asking for confirmation.'),
 ('automatic-check','正在检查依赖，接下来自动继续构建，不需要你操作。','I am checking dependencies and will continue the build automatically. No action is needed from you.'),
]
for category,zh,en in extra:
 for language,text in [('zh',zh),('en',en)]:rows.append(dict(id=f'{language}-{category}',expected='normal',language=language,category=category,text=text,origin='new'))
assert len(rows)==80 and len({r['id'] for r in rows})==80
for language in ['zh','en']:
 for expected in ['normal','question']:assert sum(r['language']==language and r['expected']==expected for r in rows)==20
suite=dict(schema='itermate-user-participation/v1',questions=helper.QUESTION_QUESTIONS,rows=rows,rounds=2,limits='固定回归集；复用并重标历史文本，另有新增/澄清文本，不是独立盲标或未见留出集；本轮不按结果调提示词。question表示当前需要用户参与，不要求疑问句。')
p=ROOT/'suite.json';assert not p.exists();p.write_text(json.dumps(suite,ensure_ascii=False,indent=2)+'\n')
(ROOT/'frozen.json').write_text(json.dumps({'suite_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'helper_sha256':hashlib.sha256((PROJECT/'integrations/laya/iTermate-laya.py').read_bytes()).hexdigest()},indent=2)+'\n')
print('Frozen 80 examples, 40 per label, 40 per language.')
