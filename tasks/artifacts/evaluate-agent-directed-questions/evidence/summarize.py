"""独立核对逐例输出并生成新任务报告；不覆盖旧任务。"""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PREVIOUS = ROOT.parents[1] / 'explore-open-system-one-models/evidence'
spec = importlib.util.spec_from_file_location('prior_metrics', PREVIOUS/'summarize.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)


def raw_prediction(model, raw):
    if model == 'gliner':
        return raw['reply']['label']
    if model == 'gliclass':
        return max(raw,key=lambda value:value['score'])['label'].split(':',1)[0]
    answer = raw['answers']['reply']
    if model == 'laya-noul':
        return 'question' if answer['noul'] >= .5 else 'normal'
    return answer['choice']


def main():
    prior.self_check()
    suite = json.loads((ROOT/'suite.json').read_text())
    digest = hashlib.sha256((ROOT/'suite.json').read_bytes()).hexdigest()
    samples = {row['id']:row for row in suite['rows']}
    assert len(samples)==48
    for language in ['zh','en']:
        for expected in ['normal','question']:
            assert sum(row['language']==language and row['expected']==expected for row in samples.values())==12
    names = {'laya-choice':'Laya choice', 'laya-noul':'Laya noul', 'gliner':'GLiNER2.5-multi-Decide', 'gliclass':'GLiClass multilingual mini', 'vela':'Vela 2.0 0.3B', 'kev':'Kev 0.8B', 'system-one':'system-one Qwen3 0.6B', 'd1':'Liquid d1-3B'}
    summary = {}
    for model in names:
        data = json.loads((ROOT/f'result-{model}.json').read_text())
        assert data['status']=='complete' and data['suite_sha256']==digest
        assert len(data['rows'])==96
        for round_index in (1,2):
            rows = [row for row in data['rows'] if row['round']==round_index]
            assert len(rows)==48 and {row['id'] for row in rows}==set(samples)
        for row in data['rows']:
            assert 'error' not in row, (model,row)
            assert all(row[key]==value for key,value in samples[row['id']].items())
            assert row['predicted']==raw_prediction(model,row['raw'])
            assert row['correct']==(row['expected']==row['predicted'])
        result = prior.summarize(data)
        result['categories']={category:prior.metrics([row for row in data['rows'] if row['round']==1 and row['category']==category]) for category in sorted({row['category'] for row in data['rows']})}
        result['examples']={row['id']:{'expected':row['expected'],'predicted':row['predicted'],'text':row['text']} for row in data['rows'] if row['round']==1 and row['category'] in ['implicit-confirmation','permission','optional-followup','self-answered','imperative-confirmation']}
        summary[model]=result
    (ROOT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    lines=['# Agent最后回答是否向用户提问：修正目标后的实测','','## 定义与边界','',suite['annotation_policy'],'',
        '- 正例包含已完成工作后的可选追问，以及没有问号的疑问表达。',
        '- “确认后我再继续”“等待你授权后继续”为负例；“请确认范围”“请选择版本”是请求/命令句，不因需要回应就判为问句。',
        '- 这里不是评估是否等待用户输入，也不是评估终端状态或最终问号UI。',
        '- 全部48条样本为合成数据，中英文各24条，每种语言问句/非问句各12条。每配置两轮；正确率只计首轮48条。',
        '- 标签和提示词在输出产生前冻结，没有根据结果调参；没有独立盲标或真实生产样本。部分文本沿用前次，但标签目标改变，不应把新旧准确率差看作同任务提示词提升。','',
        '## 结果','','| 配置 | 正确/48 | 漏报/24问句 | 误报/24非问句 | 中文正确/24 | 英文正确/24 | P50 | P95 | 后端 | 两轮变化 |','| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    for model,label in names.items():
        result=summary[model]; m=result['overall']
        lines.append(f"| {label} | {m['correct']}/48（{m['accuracy']:.1%}） | {m['fn']}/24 | {m['fp']}/24 | {result['by_language']['zh']['correct']}/24 | {result['by_language']['en']['correct']}/24 | {m['p50_ms']:.1f} ms | {m['p95_ms']:.1f} ms | {result['backend']} | {result['prediction_flips']}/48 |")
    lines+=['','延迟不含下载、初始化和独立warm-up，但含分词/输出读取；Laya还包含本地HTTP开销。M4/32GiB机器不是独占环境，各后端不同，不能当作纯模型速度或生产SLA。两轮一致不是准确性证明。','','## 边界实例','','| 输入 | 正确标签 | Laya choice | Laya noul |','| --- | --- | --- | --- |']
    for ident,item in summary['laya-choice']['examples'].items():
        lines.append(f"| {item['text']} | {item['expected']} | {item['predicted']} | {summary['laya-noul']['examples'][ident]['predicted']} |")
    lines+=['','## 本轮结论','',
        '- 在当前固定定义及样本上，Vela为41/48（85.4%），漏报3条、误报4条；system-one为37/48（77.1%）。小样本不能证明稳定的生产排名。',
        '- Laya choice为23/48（47.9%），noul为20/48（41.7%）；明确提问与非问句边界都存在错误。不能声称当前Laya配置已经可靠解决该二分类，也不能由这一固定配置推出模型所有提示词都无效。',
        '- Vela也会漏掉“文档已经写完。是否还需要我更新示例？”及“Continue?”，并把说明性问句标题或请选择类命令误判为提问；因此尚无可宣称完美的候选。',
        '- 本轮不更换模型、不改问号图标逻辑。后续若要集成，仍需独立标注验证及明确可接受的误报/漏报指标。','', '## 执行与证据','',
        '- 复用上轮已审查的模型适配器，evaluate.py仅替换冻结SUITE/QUESTION和本任务输出目录；旧报告、旧样本与产品源码不变。',
        '- 八个配置都调用真实模型，各96条原始输出；分类函数只接收文本，不传样本expected标签。Kev内部固定占位标签不进入输入token，沿用上轮已审查服务编码路径。',
        '- 所有候选使用离线缓存，未重新下载；Laya仅调用原有loopback服务。未重启用户App/Pi/Laya、未上传真实会话。',
        '- 指标自检、两轮完整性检查、原始输出重新推导预测、样本与SHA256核对通过。未执行产品测试套件或UI验收。',
        '- [冻结样本及定义](../evidence/suite.json)、[评估入口](../evidence/evaluate.py)、[串行执行及源版本绑定](../evidence/run-manifest.json)、[指标和逐类别汇总](../evidence/summary.json)。',
        '- 版本与环境沿用[上轮固定版本](../../explore-open-system-one-models/evidence/models.json)和[机器记录](../../explore-open-system-one-models/evidence/environment.json)；当前每个结果还记录运行时包版本。',
    ]
    for model,label in names.items():
        lines.append(f'- {label}：[原始输出](../evidence/result-{model}.json)')
    folder=ROOT.parent/'reports';folder.mkdir(exist_ok=True)
    (folder/'comparison.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({key:value['overall'] for key,value in summary.items()},ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
