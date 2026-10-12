# 主动查询并恢复 Pi 会话状态

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-10 19:48) |
| Artifacts | [Artifacts](../artifacts/recover-pi-status-proactively/) |
| Kind | Task |

## Target
- [x] T1: iTermate能通过认证的只读查询从现有Pi集成取得当前权威状态，并准确关联到对应终端会话。
- [x] T2: 启动、唤醒、重连或状态失效后能主动重新同步Pi状态；查询失败保持未知，不猜测完成或空闲，不干扰会话。

## Scope

- 复用Pi集成现有私有发现与认证socket；支持iTerm2与已接入TTY状态的Ghostty。
- 不覆盖安装目录，不启动或重启App、Bridge、Pi，不修改用户会话或调用归档动作。

## Plan

1. 增加认证只读状态快照及能力标记，保留现有归档和事件推送路径。
2. 对缺失Agent状态的会话做有界补查，校验身份、来源序列与接收端状态，阻止迟到结果覆盖已知状态。
3. 构建、语法和授权范围内的验证后进行R2独立审查，说明安装态与运行验证限制。

## Decisions

- 仅补齐缺失Agent状态；已知Agent状态（包括聚焦后idle）不被恢复旧finished覆盖。
- 查询失败、未知子代理活动、旧集成不支持时不猜测状态；查询不触发模型调用或生命周期动作。
- 保留开工前未提交的归档、Pi及其他任务改动；本任务增量单独核对。

## Verification Notes

- 首轮实现已通过TypeScript语法解析、Python语法编译及Xcode Debug build（CODE_SIGNING_ALLOWED=NO，未启动App）。构建日志：/tmp/itermate-recovery-build.log。
- 实现包含supportsStatus能力标记、认证只读status快照、最多4个并发/3秒超时的缺失状态补查、连接代际失效、接收端仅填补未知状态以及来源序列去重。
- 用户已明确允许本轮定向隔离测试，不运行全量测试、不启动App宿主。32项Node集成测试、7项Python恢复测试、6项Swift纯状态测试全部通过；最终Debug构建通过。Swift测试直接使用生产registry和从源文件原样抽取的快照/完成追踪类型，去掉测试文件的@testable模块导入后通过独立XCTestSuite执行，没有启动iTermate。
- 自检补充保护：后台恢复的actionResult不进入用户操作错误提示；旧代际请求在结束前仍占用并发名额；普通Shell fallback转成恢复的Agent finished不产生伪完成事件，Agent与Shell正常同来源完成转换仍保留。
- 安装目录的Pi集成保持开工前SHA256 3cdef3c73b1620c564569204580896e0c92e8f7ad1a45aef394973a042779ff3；未安装、未reload、未启动/重启App或Bridge。现场旧实例尚不支持新status能力，不能声称已完成真实面板恢复验收。
- Swift独立测试最初缺少XCTest overlay路径，后补充Developer/usr/lib与XCTest框架路径并改用XCTestSuite后成功；这是隔离runner配置修正，不是产品编译或功能失败。
- 第01轮期间并行Vela任务改动了Pi模型提问判定与Bridge模型观察，逐文件hash发生漂移，旧审查不能作为当前版本通过依据；未覆盖或回退这些改动。
- TR-1修复后Swift8项（包括8候选前4超时、多轮满额及去重）和Python7项通过，当前Debug构建通过。当前Node32项中26通过、6项模型提问回归失败；相同当前测试在临时目录使用第01轮已冻结Pi源码时32/32通过，确认阻塞与并行模型改动有关。未据旧源码通过结果声称当前工作区通过。

## Block

- Reason: 当前共享Pi集成被并行Vela工作修改，6项模型提问生命周期测试失败；不能在已知回归未解决且源码仍变化时派发最终复审或完成。证据为evidence/node-tests-02-failed.log、node-reviewed-source-02.log及concurrent-model-drift-02.patch；TR-1实现和定向测试已有实质进展，未计为审查停滞。
- Unblock when: 用户已选择等待Vela任务，不在本任务中修复其模型改动。待Vela任务完成、共享源码稳定后，重新执行相关Node测试及Swift/Python/构建验证；通过后刷新快照并派发fresh复审确认TR-1。在收到完成消息前保持Blocked，不轮询或修改Vela范围。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/recover-pi-status-proactively/reviews/round-01.md) | sha256:b68b23d0b00db5baaef8384205de6bbf70d36526b7171a64ccf844f36dc59178 | findings: TR-1；invalidated by drift（Pi模型判定与Bridge模型观察被其他工作修改） |

## Review
- Schema: task-review-ledger/v1
- Pass: 1
- Next finding: 2
- `TR-1` | no-progress=0 | ItermBridge.swift PiStatusRecoveryScheduler.reserve | 已修复满额推进游标并新增真实生产调度类型的八候选反例测试；需fresh复审确认，不自行标为resolved。

## Result

- T1: 认证只读status及归档路径在当前Node执行中对应14项通过，身份/只读断言未失败；但32项全组中6项模型提问测试因并行源码变化失败，当前集成不能整体宣称通过。相同测试在冻结的第01轮Pi源码中32/32通过，仅用于界定回归来源。未安装或重启用户进程。
- T2: TR-1已在生产PiStatusRecoveryScheduler中修复：额度满时不前移，只有预留新请求才推进。第02轮独立Swift8项、Python7项和Debug构建通过，包含八候选前四3秒超时的重复轮转反例；未完成fresh复审。当前Node6项共享模型回归仍失败，按Block等待协调后恢复验证。
- Review gate: Required — R2派发fresh只读task-review，冻结snapshot-01.json列出的任务范围。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 跨Pi认证协议、异步查询、两类接收端与完成事件边界，需独立核验并发、身份与生命周期遗漏。
- Snapshot: sha256:b68b23d0b00db5baaef8384205de6bbf70d36526b7171a64ccf844f36dc59178; tasks/artifacts/recover-pi-status-proactively/evidence/snapshot-01.json
- Evidence: T1/T2 Result；32 Node + 7 Python + 6独立Swift测试通过，最终Debug build通过，git diff --check与Context校验通过；未安装重载或重启用户进程。
- Task fingerprint: dddede8357986e018669b883ff39ba469c3ccce0899abf008ad5e000a99906e7
