# 评估 Agent 最后回答是否向用户提问

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 18:07) |
| Artifacts | [Artifacts](../artifacts/evaluate-agent-directed-questions/) |
| Kind | Task |

## Target
- [x] T1: 按Agent最后回答是否在向用户提问定义并核查中英文评估样本，排除自问自答、引用及代码中的问句，不把是否暂停或等待授权作为分类标准。
- [x] T2: 使用修正后的统一任务定义实际评估Laya及此前六种候选，报告逐例预测、漏报误报与延迟，明确区分新结果与此前待回应识别结果，不修改产品集成。

## Scope

用户已确认新的完整目标。仅重测向用户提问识别，复用已有模型与隔离环境，不重新下载、不修改集成、不重启服务、不上传会话。保留前次评估为不同任务的历史证据，不覆盖其标签或报告。

## Decisions

- 判断整条Agent最后回答是否实际向用户提问；不要求最后一句是问句，也不要求工作阻塞或有问号。
- 隐含确认陈述为负例；命令/请求句若没有疑问表达也不计为问句。自问自答、引用、代码和已回答的说明标题为负例。
- 使用48条合成样本：中英文各24条，问句及非问句各24条；每类每种语言各12条。冻结标签及定义后不根据结果调参。
- 样本由作者标注，不是独立人工盲标；部分文本沿用但语义标签重建，新旧任务准确率不能当作单因素提示词A/B结果。

## Plan

1. 冻结新样本与判断定义，复用前次已审查的真实模型适配器。
2. 顺序测试Laya choice/noul及六种候选，各跑两轮，记录原始输出和耗时；不测试旧四状态采用门槛。
3. 按首轮48条计算指标，检查两轮一致性及各语义类别，独立复核结果后交付。

## Result

- T1: suite.json在运行前冻结，sha256=52c1ea5d0df4f1eda85b7a2264244dfaf310fac428054b78f741729c2a0e8c47；48条中英文各24，问句与非问句各24，包含隐含确认、命令、引用、代码、自答负例及无问号提问/完成后追问正例；summary检查类别数量及逐例标签。
- T2: run-manifest.json及8个result文件记录768次真实推理、零请求错误，两轮无预测变化；summary-check.log重新推导原始输出与指标一致。首轮正确数Laya choice23/noul20、GLiNER23、GLiClass24、Vela41、Kev27、system-one37、d1 33（各48）。reports/comparison.md记录漏报误报、语言分组和P50/P95，明确新旧分类目标不可直接A/B比较；AST及git diff --check通过。
- Review gate: Passed — 独立fresh Reviewer run 8a05bb6d-c336-4c78-94b6-a2beea2d4e5e，无阻断发现；reviews/round-01.md已保存并链接，768条输出和指标独立核算一致，31文件哈希审查前后及主会话复核匹配。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 用户修正分类语义后重标样本及复用跨模型适配器，需独立核查目标、标签边界和原始输出聚合，避免再次把待回应识别混为问句识别。
- Snapshot: tasks/artifacts/evaluate-agent-directed-questions/evidence/snapshot-01.json sha256:4f1924a19fdfe67023ce4f8f422cab4b24aecdfd3480230aac02e0a199aa7653
- Evidence: self-check.json、run-manifest.json、summary-check.log及comparison.md；768条真实输出与原始预测/冻结样本一致，指标自检和AST通过，界限与未测项明确。
- Task fingerprint: cf07e52379e85989737a00b0b3dd18f6a372218e265d79710f759ac0c55d46c4

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [独立审查](../artifacts/evaluate-agent-directed-questions/reviews/round-01.md) | snapshot-01.json sha256:4f1924a19fdfe67023ce4f8f422cab4b24aecdfd3480230aac02e0a199aa7653 | no blocking findings；fresh oracle载体Reviewer，run 8a05bb6d-c336-4c78-94b6-a2beea2d4e5e；独立复算768条记录及31文件哈希，主会话再次核对一致。 |

## Verification

- Passed: 最终核对snapshot-01全部31个文件字节数与SHA256一致；报告与独立复算结果相符。新语义标签、48条样本及8配置各两轮已核验；未改产品集成，合成标注/延迟/UI未验收限制保留。
