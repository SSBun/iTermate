# 优化 Vela 状态分析与图标显示

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-12 15:38) |
| Artifacts | [Artifacts](../artifacts/optimize-vela-status-icons/) |
| Kind | Task |

## Target
- [x] T1: iTermate 根据 Vela 对最新回复的 idle/awaitingInput 判定展示对应图标，保持空闲未读高亮及点击灰显、等待问号保持行为。
- [x] T2: 旧回复的分析结果不覆盖新状态，保留执行期间真实运行状态及已有 Laya 切换选择。

## Scope

不安装模型、不启动或重启用户应用及服务，不改已保存模型选择。本次不运行测试；检查回归源码及静态类型、语法。辅助屏幕路径没有原生轮次事件时仍无法识别完全相同的新回复。

## Plan

1. 核查 Pi 最新回复、模型请求身份和 UI 状态映射。
2. 加固屏幕辅助识别的输入新鲜度和二分类响应校验，保留原生状态优先级。
3. 补充隔离回归源码，进行非测试验证和独立审查。

## Task Summary

**终端 Bridge**（[iTermateBridge](../../iTermateBridge/)）：模型返回后复读屏幕并检查会话存活、模型身份和原生状态，拒绝陈旧结果；输入变化清理旧估计；校验二分类类型、两类概率及选择一致性。补充屏幕变化、原生状态竞争、会话关闭及非法概率回归源码。

## Result

- T1: 核查默认Vela、显式provider参数、Pi完整回复/question与Bridge/session二分类、问号与高亮idle映射。现有链路保留；Debug构建通过且bundle Bridge字节一致，未运行模型或UI。
- T2: 推理返回后复读输入、检查session对象仍存活及原生状态/模型身份；严格两类概率与choice校验。新增回归源码未执行，AST及node语法检查、diff check通过；用户偏好未修改。
- Review gate: Passed — 独立只读oracle 98a11058-68f6-47b9-b676-b987f8c96210，round-01无问题；主会话复核12项快照一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 异步推理、实时屏幕与状态竞争需独立核查
- Snapshot: tasks/artifacts/optimize-vela-status-icons/evidence/snapshot-01.json
- Evidence: 限定差异、Debug构建、AST与bundle一致性；未运行测试/模型/UI
- Task fingerprint: 20ebe8853993f336d049689505d3636d00055230f45db8fd69b5f35e1c0e54cb

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/optimize-vela-status-icons/reviews/round-01.md) | sha256:d1e0370e30b904ff5a94ded71c4fb2aa132682dcf1847a25748166d91da62031 | no blocking findings |

## Verification

- Passed: 审查后12项哈希一致；保留Debug构建、AST、bundle一致证据；旧屏幕/身份/会话结果丢弃及原生状态优先经静态核查。未运行测试、真实模型或UI。
