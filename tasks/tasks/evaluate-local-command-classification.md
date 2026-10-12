# 验证本地模型对运行命令类型的分类能力

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 11:15) |
| Artifacts | [Artifacts](../artifacts/evaluate-local-command-classification/) |
| Kind | Task |

## Target
- [x] T1: 使用本机现有模型实测命令执行、服务运行、持续监控及信息不足的终端样本，并报告实际分类和错误。
- [x] T2: 根据实测证据说明该模型是否适合接入运行类型识别；本任务不修改产品实现、不启动或重启 iTermate 或 Bridge。
- [x] T3: 在相同问题与选项下对比 venom 完整输出与最新监控行，报告上下文截取对分类的实际影响。
- [x] T4: 使用事先固定的新样本，对比完整片段、最后四个非空行和最后一个非空行的自动截取效果，并披露失败边界。

## Result

- T1: 现有本机服务完成20样本×3方案共60次推理；详细四分类7/20，简短10/20；输入和完整响应见 artifacts/evaluate-local-command-classification/evidence 两个JSON，报告见 artifacts/evaluate-local-command-classification/reports/results.md。
- T3: context-ablation.json保存两套原问题×三种上下文×三次重复共18次响应；完整输出均误判，截短均选monitor；简短问题保留命令信息时monitor概率93.40%。逐项验证问题未变、三次一致；报告明确单样本与手工截取局限。
- T4: 请求前固定16样本和三种方法；window-evaluation-results.json中48次成功响应绑定fixtures哈希；完整8/16、末四行10/16、末行8/16。问题一致性、响应完整性与统计复核通过，报告记录tail观察者混淆与venom监控提示被后续日志挤出窗口的失败。
- T2: 累计126次本地调用：模型能识别明确监控行，但固定窗口不足以自动可靠分类，末四行新样本仅10/16；状态化阶段保持只是未验证候选。产品实现、设置、App和Bridge均未修改或重启，未运行项目测试。
- Review gate: Skipped — R1：本地评估证据与报告可直接核对，产品未变，无独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 只新增固定样本与API响应证据，更新限定结论的报告。
- Snapshot: sha256:6a41070854417e47a17ea02f59f31aee16e3ef84cf9f5ff65b6ed912f4f213cc
- Evidence: 48次响应完整性、16样本唯一性、fixture哈希、问题与原简短组一致性已校验；三组命中及阈值统计从响应重算。
- Result clarity: 比较预固定文本窗口，不承诺解决语义阶段提取。
- Bounded impact: 仅本任务证据和报告，无产品消费者。
- Low risk: 请求仅送现有loopback服务，不变更运行态、不上传或保存令牌。
- Sufficient verification: 各组16次响应与预设标签直接比较，报告覆盖错误例及人工样本局限。
- Task fingerprint: 0032739bf6b68cba30ae80df19ff72d898a018850e5752bb178b962f3e581870

## Verification

- Passed: 证据及报告聚合身份sha256:��48次新增模型调用无HTTP错误，命中数8/10/8与报告一致。未运行项目测试或修改产品。
