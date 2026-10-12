# 将回复状态判定简化为 idle 与 awaitingInput

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-12 14:58) |
| Artifacts | [Artifacts](../artifacts/binary-response-status/) |
| Kind | Task |

## Target
- [x] T1: 回复状态仅区分 idle 与 awaitingInput；需要用户回答、确认、选择、授权或补充信息时归为 awaitingInput，否则归为 idle。
- [x] T2: 每次回复结束并判定 idle 后先显示高亮空闲图标，用户点击一次后变为灰色非活跃图标；下一次 idle 回复重新高亮。
- [x] T3: awaitingInput 始终显示问号，点击不清除等待状态；保留执行期间真实运行状态。

## Scope

修改回复判定与状态展示，不自动安装模型、启动或重启应用及服务。本次未获新的测试执行授权，采用源码、类型及构建检查，不声称运行测试。

## Plan

1. 核查回复分类、状态传递及点击确认路径，区分语义状态与未读高亮。
2. 将模型回复判定统一为二分类，同步高亮与问号保持行为。
3. 检查相关回归覆盖与非测试验证，完成独立审查。

## Task Summary

**本地模型协议**（[integrations/laya](../../integrations/laya/)）：会话接口改为用户参与二分类，复用问句接口的语义定义，移除第二概率输出，补充协议回归源码。

**Bridge**（[iTermateBridge](../../iTermateBridge/)）：采纳二分类，移除双门槛，记录模型回复已读状态，仅显式激活清除 Agent 完成高亮，补充隔离回归源码。

**原生面板**（[iTermate](../../iTermate/)）：回复完成复用协议 finished 标记显示高亮空闲，点击后灰显；模型等待显示像素问号，Ghostty被动焦点变化不清除Agent高亮。

**API说明**（[docs](../../docs/)）：说明二分类及高亮语义；辅助模型仅靠屏幕变化，文本完全相同且无生命周期事件时无法识别新轮次。

## Result

- T1: SESSION_QUESTIONS仅idle/awaitingInput，共享用户参与提示词；Bridge移除第二概率过滤；Pi既有二分类保留。AST及Debug构建通过，未运行测试或真实模型。
- T2: Agent finished作为未读传输标记映射高亮Idle，显式点击清为idle；被动焦点保留高亮。模型辅助路径按最新屏幕文本跟踪已读，不能识别无事件的完全相同新文本。Swift构建通过，未做视觉验收。
- T3: 原生awaitingInput清除函数不处理，面板固定问号；辅助估计waiting同样问号且点击不改变模型状态；原生running优先路径未变。新增回归源码未执行，AST通过。
- Review gate: Passed — 独立只读oracle 3340db1e-17f3-4208-ad85-659aae47d612，round-01无阻断；主会话再次核对11文件哈希一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨模型协议、Bridge与UI的回复状态及已读交互修改
- Snapshot: tasks/artifacts/binary-response-status/evidence/snapshot-01.json
- Evidence: Debug BUILD SUCCEEDED、Python AST及diff check通过；限定差异scoped.diff；测试及真实UI未运行
- Task fingerprint: 8a23d49c3cbe9bfdeba11e473b1c108588877d70407018527ef9c705a1fa2820

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/binary-response-status/reviews/round-01.md) | sha256:ab9f008b7b8570eaed377cfdb3ca14cf622b3c94ba7aa9ca94230d9bb94d4cb7 | no blocking findings |

## Verification

- Passed: 审查后11文件与快照一致；二分类、原生高亮点击清除及等待保持通过源码核查，Debug构建及AST检查通过；未运行测试或UI。辅助路径无生命周期且文本相同不能识别新轮次，已披露。
