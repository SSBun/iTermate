"""核验开发选择、一次留出验收及所有原始预测；生成负结果报告。"""
import ast
import hashlib
import json
from pathlib import Path
from experiment import check_inputs, choose, digest, metrics

ROOT=Path(__file__).resolve().parent


def main():
    frozen=check_inputs()
    prompts=json.loads((ROOT/'prompts.json').read_text())+json.loads((ROOT/'prompts-round2.json').read_text())
    selection=json.loads((ROOT/'selection.json').read_text())
    assert selection['ranked']==choose(prompts)
    assert selection['selected']==next(p for p in prompts if p['id']==selection['ranked'][0]['id'])
    inputs={phase:json.loads((ROOT/name).read_text()) for phase,name in [('dev','development.json'),('holdout','holdout.json')]}
    assert not {r['text'] for r in inputs['dev']}&{r['text'] for r in inputs['holdout']}
    for phase,size in [('dev',48),('holdout',80)]:
        rows=inputs[phase];assert len(rows)==size and len({r['id'] for r in rows})==size
        for lang in ['zh','en']:
            for expected in ['normal','question']:assert sum(r['language']==lang and r['expected']==expected for r in rows)==size//4
    source_hashes={digest(ROOT/'experiment.py'),digest(ROOT/'history/experiment-round1.py')}
    checked={}
    for path in sorted(list(ROOT.glob('dev-*.json'))+list(ROOT.glob('holdout-*.json'))):
        data=json.loads(path.read_text());phase='holdout' if data['phase']=='holdout' else 'dev'
        expected={r['id']:r for r in inputs[phase]}
        assert data['status']=='complete' and data['script_sha256'] in source_hashes
        assert data['prompt']==next(p for p in prompts if p['id']==data['prompt']['id'])
        assert all(frozen[name]==sha for name,sha in data['frozen'].items())
        for round_index in [1,2]:
            rows=[r for r in data['rows'] if r['round']==round_index]
            assert len(rows)==len(expected) and {r['id'] for r in rows}==set(expected)
        for row in data['rows']:
            assert 'error' not in row
            assert all(row[key]==value for key,value in expected[row['id']].items())
            answer=row['raw']['answers']['reply']
            predicted=answer['choice'] if data['prompt']['kind']=='choice' else 'question' if answer['noul']>=.5 else 'normal'
            assert row['predicted']==predicted and row['correct']==(predicted==row['expected'])
        rows=[r for r in data['rows'] if r['round']==1];second={r['id']:r for r in data['rows'] if r['round']==2}
        assert len(data['rows'])==2*len(expected)
        if phase=='holdout':
            assert data['selection_sha256']==digest(ROOT/'selection.json')
            assert data['started_at']>=selection['selected_at']
        else:assert data['finished_at']<=selection['selected_at']
        checked[path.stem]=dict(metrics=metrics(rows),by_language={lang:metrics([r for r in rows if r['language']==lang]) for lang in ['zh','en']},flips=sum(r['predicted']!=second[r['id']]['predicted'] for r in rows),rows=len(data['rows']))
    assert len(list(ROOT.glob('dev-*.json')))==20
    assert len(list(ROOT.glob('holdout-*.json')))==2
    chosen=selection['selected']['id'];winner=checked['holdout-'+chosen];baseline=checked['holdout-baseline']
    selected_rows=[r for r in json.loads((ROOT/f'holdout-{chosen}.json').read_text())['rows'] if r['round']==1]
    base_rows={r['id']:r for r in json.loads((ROOT/'holdout-baseline.json').read_text())['rows'] if r['round']==1}
    paired={'improved':sum(r['correct'] and not base_rows[r['id']]['correct'] for r in selected_rows),'regressed':sum(not r['correct'] and base_rows[r['id']]['correct'] for r in selected_rows),'unchanged':sum(r['correct']==base_rows[r['id']]['correct'] for r in selected_rows)}
    summary=dict(selected=chosen,goal='holdout accuracy > 0.90',goal_met=winner['metrics']['accuracy']>.9,paired=paired,checked=checked)
    (ROOT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    for p in ROOT.glob('*.py'):ast.parse(p.read_text())
    (ROOT/'self-check.json').write_text(json.dumps(dict(checks=['20候选开发结果及选择规则重算一致','48开发及80留出均中英/正负平衡，无完全相同文本交集','全部2240条样本评估输出、样本、预测及correct一致，零请求错误（另有22次warm-up）','脚本历史及冻结数据哈希匹配','开发完成时间早于选择，留出执行晚于选择且绑定selection哈希','AST语法检查通过'],total_rows=sum(x['rows'] for x in checked.values()),goal_met=summary['goal_met'],limits=['同一作者合成标注，不是独立人工盲标','没有生产准确率/延迟SLA证据','本轮未达到90%以上'],paired=paired),ensure_ascii=False,indent=2)+'\n')
    lines=['# Vela 提示词优化：整体准确率验收','','## 结论','',
        '**本轮未达到整体准确率超过90%的目标。** 开发集尝试20个候选后最高为43/48（89.6%）；按预先规则选出的speech-kind在留出集为62/80（77.5%），基线为61/80（76.25%）。只多对1条，不能认为获得稳定改进。',
        '', '## 方法与边界','',
        '- 目标仍是Agent最后一条回答是否实际向用户提问，不是是否等待回复。隐含确认、命令请求、引用、代码和自问自答为负例。',
        '- 48条旧评估样本仅作开发集；运行前另行冻结80条留出样本，各有一半中英文、一半问句/非问句，每语言每类别20条。二者无完全相同文本。',
        '- 留出由同一作者合成，含中英对应及相关语义结构，不是独立人工盲标或生产随机抽样。所谓留出独立仅指不参与提示词选择，不能据此建立生产准确率。',
        '- 第一轮12种候选，第二轮根据开发错误追加8种并先冻结再跑；包括简短、中英、few-shot、noul、顺序及answer角色字段。角色字段/类型变化不是纯措辞单因素。',
        '- 按开发accuracy、较弱语言accuracy、预设序号依次选取。没有对类别阈值调参。selection.json先落盘，才运行所选项和预设baseline的留出验收。没有用留出结果重选模型或追加候选。',
        '- 每个配置跑两轮以检验稳定性；合计2240次样本推理，另有22次warm-up。首轮48或80条计算准确率，不把重复执行视为更多独立样本。',
        '- 固定Vela版本、PyTorch CPU fp32、4线程，复用离线缓存；没有产品改动、服务重启、真实会话上传或新模型下载。','',
        '## 留出集结果','','| 配置 | 正确/80 | 漏报/40问句 | 误报/40非问句 | Precision | Recall | P50 | P95 |','| --- | --- | --- | --- | --- | --- | --- | --- |']
    for label,result in [('基线',baseline),('选定speech-kind',winner)]:
        m=result['metrics'];lines.append(f"| {label} | {m['correct']}/80（{m['accuracy']:.2%}） | {m['fn']} | {m['fp']} | {m['precision']:.2%} | {m['recall']:.2%} | {m['p50_ms']:.1f} ms | {m['p95_ms']:.1f} ms |")
    lines+=['',f"逐例对比：{paired['improved']}条从错变对，{paired['regressed']}条从对变错，{paired['unchanged']}条正确性不变。减少漏报的同时增加了误报。",'', '| 配置 | 中文正确/40 | 英文正确/40 | 两轮预测变化 |','| --- | --- | --- | --- |']
    for label,result in [('基线',baseline),('选定speech-kind',winner)]:lines.append(f"| {label} | {result['by_language']['zh']['correct']}/40 | {result['by_language']['en']['correct']}/40 | {result['flips']}/80 |")
    lines+=['','延迟不含加载和warm-up，包含分词/输出读取；机器不是独占环境。本表只描述本轮观测，不是速度保证。','','## 按开发集选择的提示词','','```json',json.dumps({'type':selection['selected']['kind'],'instructions':selection['selected']['instructions'],'criteria':selection['selected']['criteria']},ensure_ascii=False,indent=2),'```','','这只是开发集胜者，不是通过验收的生产配置。不能把它描述为“90%以上准确率的提示词”。','','## 开发候选全量对照','','| 排名 | 候选 | 正确/48 | 较弱语言准确率 |','| --- | --- | --- | --- |']
    for rank,row in enumerate(selection['ranked'],1):lines.append(f"| {rank} | {row['id']} | {row['metrics']['correct']}/48 | {row['worst_language_accuracy']:.1%} |")
    lines+=['','## 留出误判','','| 输入 | 正确标签 | 预测 |','| --- | --- | --- |']
    for row in selected_rows:
        if not row['correct']:
            text=row['text'].replace('\n',' / ').replace('|','\\|').replace('`','')
            lines.append(f"| {text} | {row['expected']} | {row['predicted']} |")
    lines+=['','## 下一步判断','','仅调整提示词在本轮没有建立足够可靠的问句识别。更值得验证的方向是有独立标注集的专用分类微调，或更强模型；不能承诺任一方向必达90%。若继续调优，本轮留出集必须退役为已见数据，另建新的验收集。','','## 证据','','- [冻结输入哈希](../evidence/frozen-inputs.json)与[第二轮候选哈希](../evidence/frozen-round2.json)','- [开发样本](../evidence/development.json)、[留出样本](../evidence/holdout.json)','- [第一轮提示词](../evidence/prompts.json)、[第二轮提示词](../evidence/prompts-round2.json)','- [选择依据与时间](../evidence/selection.json)、[完整统计](../evidence/summary.json)、[自检](../evidence/self-check.json)',f'- [所选配置留出原始输出](../evidence/holdout-{chosen}.json)、[基线原始输出](../evidence/holdout-baseline.json)','- [真实执行脚本](../evidence/experiment.py)及[第一轮脚本快照](../evidence/history/experiment-round1.py)','- [指标核算与报告生成](../evidence/report.py)','']
    out=ROOT.parent/'reports';out.mkdir(exist_ok=True);(out/'comparison.md').write_text('\n'.join(lines))
    print(json.dumps({'selected':chosen,'goal_met':summary['goal_met'],'baseline':baseline,'selected_result':winner,'paired':paired},ensure_ascii=False,indent=2))


if __name__=='__main__':main()
