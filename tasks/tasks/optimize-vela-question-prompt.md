# 评估并优化 Vela 向用户提问识别提示词

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 19:27) |
| Artifacts | [Artifacts](../artifacts/optimize-vela-question-prompt/) |
| Kind | Task |

## Target
- [x] T1: 在已确认的向用户提问语义下对比Vela提示词，开发样本与冻结验收样本分离，保留逐例真实输出及可追溯的提示词选择依据。
- [x] T2: 报告所选提示词在独立留出样本上的accuracy、precision、recall、混淆矩阵与延迟，验证整体准确率accuracy是否超过90%，如未达到明确报告，不以调参集或类别比例失衡换取未披露的高分。
- [x] T3: 复用本地模型及隔离环境，不修改产品集成、不重启用户服务、不上传真实会话。

## Scope

用户已确认目标是整体accuracy严格超过90%，而非precision；允许本地真实测试并如实报告未达标。不承诺通过有限合成样本证明生产准确率。

## Decisions

- 沿用已经确认的问句语义：真实向用户提问为正；等待确认陈述、无疑问表达的请求/命令、引用、代码、自答为负。
- 先冻结此前48条平衡样本为开发集，另建80条留出样本，中英文及正负例各组合20条。留出仍由同一作者合成标注，不是独立盲标。
- 第一轮比较12种预设提示词/输入表达；仅依据开发错误追加冻结8种候选（第二轮），总共20种。覆盖简短、语义、语法、中英、开发集few-shot、noul及answer字段角色框架；留出未用于改写。角色框架和输出类型变化明确记录，不称为纯措辞单因素实验。
- 固定模型版本、CPU fp32、4线程及0.5阈值；按开发集accuracy选择，平分时比较较弱语言表现，再平分按预设顺序。
- 选择结果先持久化，再打开留出集执行所选提示词及预设baseline。验收后不依结果再次调参或更换胜者，避免留出泄漏。两轮仅检查稳定性，不增加独立样本数。

## Plan

1. 冻结数据、候选及选择规则，执行开发集真实推理并检查失败与指标。
2. 固定胜者及依据，执行独立留出验收；报告整体及中英文分组、precision/recall、误判与延迟。
3. 复核证据和结论边界，独立审查后交付可复用提示词；不集成到产品。

## Result

- T1: frozen-inputs.json及frozen-round2.json绑定48开发/80留出与20提示词；20个dev文件各96条真实输出。selection.json按开发accuracy/较弱语言/序号固定speech-kind（43/48），早于两项留出运行并由selection哈希绑定；report.py逐例核对与选择规则重算通过。
- T2: 留出80条：speech-kind为62/80=77.5%，基线61/80=76.25%，均未超过90%；TP35/TN27/FP13/FN5，precision72.92%、recall87.5%，P50约40.3ms。报告明确未达标、9条改善/8条退步，不把开发89.6%或重复执行当验收。2240条原始预测及指标核验、边界单元断言、AST和git diff --check通过。
- T3: 执行仅涉及本任务评估文件及已有隔离Python，HF_HUB_OFFLINE/TRANSFORMERS_OFFLINE和固定revision加载Vela缓存，使用合成文本；未修改产品集成、启动或重启用户服务、上传真实会话。运行脚本及日志可核查。
- Review gate: Passed — 独立fresh Reviewer run f8bd0b54-db84-4d19-992d-a0aa2b5ab00d，reviews/round-01.md无阻断问题；选择流程、2240条样本指标与未达标结论独立核算一致，45文件哈希前后及主会话复核匹配。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨提示词开发选择及冻结留出评估需要独立检查数据泄漏、统计与未达标结论，不能仅凭脚本自检认定可靠。
- Snapshot: tasks/artifacts/optimize-vela-question-prompt/evidence/snapshot-01.json sha256:8e8e1bf5578d4244504d0483e10f3935a182067bf97880867a10e98b8edd6be3
- Evidence: self-check.json、metrics-check.json、report-check.log及comparison.md；2240条样本输出、来源哈希、选择时序与原始预测全部核对，明确77.5%未达90%。
- Task fingerprint: 4cd40001d636ff8494e1e8854d4aec5dd8aab08e03155f411f6c2cdc8039082a

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [独立审查](../artifacts/optimize-vela-question-prompt/reviews/round-01.md) | snapshot-01.json sha256:8e8e1bf5578d4244504d0483e10f3935a182067bf97880867a10e98b8edd6be3 | no blocking findings；fresh oracle载体Reviewer run f8bd0b54-db84-4d19-992d-a0aa2b5ab00d；独立复算2240条记录与选择流程，45文件前后及主会话哈希核验一致；确认未达标结论。 |

## Verification

- Passed: 最终45文件长度/SHA256匹配snapshot-01，审查报告已持久化并索引；开发20候选与冻结留出验收均有真实输出，77.5%未超过90%的负结果及局限如实保留；产品集成未改。
