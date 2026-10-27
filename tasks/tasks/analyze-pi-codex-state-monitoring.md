# 分析 Pi 与 Codex 状态监听的准确性和改进路径

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-22 18:26) |
| Kind | Task |

## Target
- [x] T1: 基于当前源码说明 Pi 和 Codex 状态监听机制、具体问题及更可靠的实现方向

## Scope

分析当前工作树的 Pi/Codex 状态产生、接收、恢复与完成消费；不实现修复，不运行测试，不操作运行中 App、Bridge 或 Agent，不读取用户对话。

## Plan

1. 审计 Codex 被动进程与会话记录监听。
2. 审计 Pi 生命周期、子代理与状态恢复。
3. 检查共享状态消费，核实上游接口并汇总优先级建议。

## Task Summary

没有修改业务代码或项目组件；本任务仅形成源码分析与改进建议。

## Evidence

- 当前源码核对：CodexSessionMonitor.swift:103–110、230–248 的时间近似绑定可将同目录后启动进程绑定至旧 rollout，且成功绑定后不重判；104–106 的15次限制可造成持续未知；134–155 在进程消失后未回读终态；271–332 只识别三类生命周期事件并将无事件的文件增长推断为 running。
- 当前源码核对：Pi integration:1243、1249–1268 忽略 settled.aborted 并等待辅助模型；406–434 含三次顺序HTTP请求，每次10秒；448 超过3000字符直接跳过；1130–1146 与1195–1202 对未知子代理采用不同规则。
- 本机 Pi 1.4.0 types.d.ts:800–804 与 agent-session.js:683–699、1631–1634 确认中止信号存在且异步 settled handler 会延迟下一条 prompt。SessionNotifications.swift:15–25 与 ItermBridge.swift:898–904 确认完成消费依赖相邻running→finished快照和exitStatus=0。
- 本机 Codex 0.163.0 help 与生成schema、https://learn.chatgpt.com/docs/app-server 、https://learn.chatgpt.com/docs/hooks 确认只读thread/read和activeFlags接口；共享daemon覆盖、旁路订阅及TTY↔thread关联仍需受控运行验证。没有读取真实会话或连接daemon。
- 检查范围SHA256：CodexSessionMonitor.swift=ff2cfdd9dba71e3482b3abf26098bc54dd44cdcfeeabddfb41e8616fe60c211a；Pi integration=486943ed2d15dc88d9ce7e07acbc931f56849e77df2765b5e842d035fd8b46b6；ItermBridge.swift=143c3cfc8097e76518aa4ab67a1ac2b0fb557c46e5c28215207a6aabee8c07d3；Python Bridge=1ecda584d13cf0a7360d8b11b944b90051e7beebad8fb4716b2f41997a2541a4；PiSessionArchives.swift=c23cfa491fbca92e5dd1f1a55eab4fee2c0023e68e2f456d2087a68d15d53c02；SessionNotifications.swift=a902d4a2d759e66e3df74b68f5ac101038294e5811bf7d76d6740374fece89be。
- 验证限制：静态源码路径与接口核对，未运行测试、构建或故障复现。当前工具无task_focus能力；使用工作区任务CLI维护归属。

## Result

- T1: 已静态追踪Pi与Codex完整状态链，核实同目录误绑定、Pi中止误成功、分类阻塞、未知子代理分歧及恢复/完成盲区，并对照本机Pi 1.4.0、Codex 0.163.0与官方协议提出分阶段建议；细节及源码哈希见Evidence。
- Review gate: Skipped — R0分析结果；本次为整体机制分析，不额外对分析结果发起独立评审，无业务文件修改。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 只读架构与实现分析，没有请求的交付文件或业务代码变更；并行分项分析已由主Agent核对源码与接口。
- Snapshot: no-file-analysis; source SHA256 manifest in Evidence; Codex 0.163.0; Pi 1.4.0
- Evidence: 主Agent逐项核对核心条件、下游通知计数、本机公开类型与runtime；测试和真实故障复现未执行，已保留限制。
- Task fingerprint: e7868a373a777ec81680af98e93d030be3a891940de923ec68622e1f5fd8cb4c

## Verification

- Passed: 六个审计源码文件最终SHA256与Evidence一致；核心结论已经主Agent复核，官方文档与本机生成协议相互印证；只证明静态路径与接口存在，不声称完成测试或实时复现。
