"""将冻结评估的原始结果汇总为中文报告，不择优筛选单条样本。"""
import json
from pathlib import Path
from summarize import summarize

ROOT = Path(__file__).resolve().parent
selected = [
    ("laya-choice", "Laya：直接choice二分类"),
    ("laya-noul", "Laya：直接noul"),
    ("gliner-retry1", "GLiNER2.5-multi-Decide 287M"),
    ("gliclass", "GLiClass multilingual mini"),
    ("vela", "Vela 2.0 0.3B"),
    ("kev-retry2", "Kev 0.8B"),
    ("system-one", "mpuig/system-one Qwen3 0.6B"),
    ("d1", "Liquid d1-3B"),
]
reports = []
for key, label in selected:
    path = ROOT / f"result-{key}.json"
    report = json.loads(path.read_text())
    assert report['status'] in ['complete', 'blocked'], (key, report['status'])
    reports.append((key, label, report, summarize(report)))
lines = [
    '# 开放决策模型：待用户回复识别实测', '',
    '## 测试范围', '',
    '- 设备：Apple M4，32 GiB统一内存；本机仍有其他应用和既有Laya服务运行，并非独占硬件实验室。',
    '- 48条合成样本：24条待回复、24条普通回答；26条中文、22条英文。16条历史回归加32条新样本，新样本中每种语言、每类各8条。',
    '- 每种配置顺序运行两轮。表中准确率、漏报及误报以第一轮48条计，不把重复样本当成96条独立证据。',
    '- 所有候选使用相同任务语义、输入文本和两类定义；按官方API分别编码标签。choice取最大类，noul固定0.5，不根据输出调提示词、阈值或训练模型。',
    '- 分类目标是当前是否请求或等待用户回应，而非有无问号、是否正在运行。自主执行但不要求回应也属于normal。',
    '- 这是真实推理的集成评估，不是mock单元测试。样本由作者合成标注，无独立人工盲标，不代表真实生产准确率。', '',
    '## 第一轮结果', '',
    '| 配置 | 正确/48 | 待回复漏报/24 | 普通回答误报/24 | 请求P50 | 请求P95 | 后端 |',
    '| --- | --- | --- | --- | --- | --- | --- |',
]
for key, label, raw, summary in reports:
    m = summary['overall']
    if raw['status'] == 'complete':
        lines.append(f"| {label} | {m['correct']}/48（{m['accuracy']:.1%}） | {m['fn']}/24 | {m['fp']}/24 | {m['p50_ms']:.1f} ms | {m['p95_ms']:.1f} ms | {summary['backend']} |")
    else:
        lines.append(f"| {label} | 未完成推理 | — | — | — | — | {summary.get('error')} |")
lines += ['', '延迟包含各适配器的tokenization与结果读取；Laya另含loopback HTTP，其他候选为进程内调用，不能当成同后端纯模型速度排名。P95只基于48个短输入，后台服务和首次形状编译可能造成波动。下载、初始化和独立warm-up均不计入表中请求延迟。', '', '## 语言及新增样本', '', '| 配置 | 中文正确/26 | 英文正确/22 | 新增正确/32 | 两轮预测变化 |', '| --- | --- | --- | --- | --- |']
for key, label, raw, summary in reports:
    if raw['status'] != 'complete':
        continue
    lines.append(f"| {label} | {summary['by_language']['zh']['correct']}/26 | {summary['by_language']['en']['correct']}/22 | {summary['by_split']['new']['correct']}/32 | {summary['prediction_flips']}/{summary['repeated_rows']} |")
lines += ['', '## 原始产品接口基线', '']
product = summarize(json.loads((ROOT / 'result-laya-product.json').read_text()))['overall']
lines += [f"现有四状态接口及采用阈值：48条中拒判{product['abstained']}条，产生分类{product['classified']}条，正确{product['correct']}条。拒判不等于普通回答，更不能称为48条全部分类错误。此项只模拟模型采用门槛，不运行产品正则回退，也不证明最终UI状态。", '', '## 用户原始反例', '', '> 确认后，我会修改解析逻辑并重新评审。', '', '| 配置 | 预测 |', '| --- | --- |']
for key, label, raw, summary in reports:
    match = next((row for row in raw['rows'] if row['id'] == 'question-zh-screenshot' and row['round'] == 1), None)
    lines.append(f"| {label} | {match.get('predicted', match.get('error')) if match else '未获得结果'} |")
lines += ['', '## 当前判断', '',
    '- 在本轮固定配置和小样本上，system-one（40/48）与Vela（39/48）更值得继续验证；两者均漏报2/24，但仍误报6/24和7/24。差一条样本不足以建立稳定优劣排名。',
    '- Kev误报只有1/24，但漏报9/24；若优先避免漏掉等待确认，它不是本轮最合适的直接替代配置。',
    '- 六种方案均完成真实推理。d1更大，但本轮34/48，并未优于两个较小候选。不能把这推广成所有任务的模型能力结论。',
    '- 不建议仅凭本轮直接替换Laya。下一步应在另行授权下收集独立标注样本，选择可接受的漏报/误报权衡，再评估集成；本任务未改产品采用逻辑。', '', '## 运行边界与失败处理', '',
    '- 未替换iTermate集成、未重启用户App/Pi或Laya服务、未上传会话数据、未调用付费API。只使用合成文本、本地隔离Python环境和公开权重。',
    '- 下载hf_xet路径无进展后终止了本任务下载进程，改用普通HTTP；未终止用户模型服务。',
    '- GLiNER首轮初始化因Hub离线快照检查要求未下载的图片/文档而失败。修复下载与加载的文件选择一致性后，以retry1完整重跑；未改变分类输入。',
    '- Kev首次15分钟进程期限消耗在底座下载，没有推理结果。续传余下权重并验证完整LFS SHA256后，首次重试暴露评估API要求训练标签；改用官方服务编码路径，不传真实或伪造答案标签，以retry2完整重跑。原失败证据保留。',
    '- system-one在Kev下载时另有early轮次，主表固定使用正常队列轮次，不择优；两份完整结果都保留。',
    '- GLiClass与GLiNER基础主题烟测均将NASA火星探测文本识别为space，证明基本API可用；不证明当前待回复提示词已充分优化。',
    '- 运行日志存在第三方类型/弃用警告，全部保留。未进行提示词搜索、微调、量化、长上下文或真实终端UI验收。',
    '- 冷加载数字只作诊断：进程RSS不代表MLX/MPS完整统一内存占用；运行时版本、下载耗时、初始化时间和首个warm-up时间见原始JSON。不能据此宣称生产内存预算或冷启动SLA。', '',
    '## 证据与复现', '',
    '- [冻结样本和任务定义](../evidence/suite.json)',
    '- [模型版本](../evidence/models.json)；[机器和源码版本](../evidence/environment.json)',
    '- [评估脚本](../evidence/benchmark.py)；[指标计算](../evidence/summarize.py)；[所有尝试汇总](../evidence/summary.json)',
    '- [Torch环境](../evidence/torch-requirements.txt)；[MLX环境](../evidence/mlx-requirements.txt)',
]
for key, label, raw, summary in reports:
    lines.append(f"- {label}：[逐例原始输出](../evidence/result-{key}.json)")
lines += ['', '复现顺序：创建隔离环境并安装固定依赖；按models.json下载相应revision；设置benchmark.py中的RUNTIME为该环境目录；运行对应model参数与新的--tag保存新结果，避免覆盖历史证据。Laya需现有本地服务配置。重现时不应再次运行prepare.py覆盖冻结样本或将模型版本更新到main。', '']
folder = ROOT.parent / 'reports'
folder.mkdir(exist_ok=True)
(folder / 'comparison.md').write_text('\n'.join(lines))
print(folder / 'comparison.md')
