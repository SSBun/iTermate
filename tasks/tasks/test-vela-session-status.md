# 验证 Vela 会话状态判定

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-12 14:19) |
| Artifacts | [Artifacts](../artifacts/test-vela-session-status/) |
| Kind | Task |

## Target
- [x] T1: 使用 Vela 实测 iTermate 会话状态判定接口，报告预期与实际状态、准确率及误判案例，区分接口测试与真实 UI 验收。

## Task Summary

**状态评估**（[任务产物](../artifacts/test-vela-session-status/)）：新增48条双语状态样本、真实 Vela 隔离执行脚本、两轮输出及分析报告；未修改产品代码。

## Result

- T1: 真实 Vela 48条各两轮；实际 Handler与Bridge方法隔离运行，原始正确36/48、采纳16条正确15条，等待状态采纳0/12；协议测试退出0。报告 reports/results.md 与原始 result.json；未启动服务或UI，合成样本不能外推生产。
- Review gate: Passed — 独立只读 oracle 3a5a1250-49fc-4081-8bbc-a00e4498b713，round-01 无问题；独立重算全部指标，主会话复核10文件哈希一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 真实模型评估涉及多头阈值和统计结论，需独立复核
- Snapshot: tasks/artifacts/test-vela-session-status/evidence/snapshot.json
- Evidence: 原始输出逐项重算，实际产品方法路径检查；报告明确拒判与分类准确率不同
- Task fingerprint: c79e103acc911735a373db1214964a7e9262b1f5d5621ac41ea43bf1e6c08863

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/test-vela-session-status/reviews/round-01.md) | sha256:14a9c8ebdce1ed901a50637d26bba1f3fdb1b78a3744718d864e48487eeb5d24 | no blocking findings |

## Verification

- Passed: 审查后快照SHA及10文件哈希均一致；48条两轮原始正确36/48，Bridge采纳16条正确15条、等待输入0/12；六项协议测试通过。未做真实网络或UI验收。
