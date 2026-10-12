# 验证主动查询 Pi 会话状态的可行性

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 18:41) |
| Artifacts | [Artifacts](../artifacts/verify-proactive-session-status/) |
| Kind | Task |

## Target
- [x] T1: 用实际检查与相关测试确认现有iTermate和Pi集成能否主动取得可匹配到终端的权威会话状态，并区分现有能力与尚缺接口。
- [x] T2: 给出有证据支持的可行性结论和覆盖限制，不修改产品行为、不重启或干扰现有会话。

## Decisions

- 结论：可复用现有发现、身份映射与私有socket实现主动查询，但当前协议没有只读状态动作；不能把“可实现”表述为当前已支持。
- 仓库与磁盘安装的Pi集成SHA256同为3cdef3c73b1620c564569204580896e0c92e8f7ad1a45aef394973a042779ff3；磁盘一致不单独证明所有进程加载版本，现场socket响应作为补充证据。
- 实时只读采样：17个iTerm2会话中发现6个新鲜Pi端点，6个均唯一匹配到真实终端Session ID；发现描述文件无status/state/isIdle/isStreaming字段；向各端点发送携带其凭据的action=status，6个均拒绝、无状态返回，查询后6个PID均存活。凭据、Session ID、会话路径不输出或持久化。
- 源码startArchiveEndpoint仅接受action=archive，拒绝发生在closing、摘要与归档写入之前；本次绝不发送archive。canArchive是归档资格，不能区分idle、finished和awaitingInput，false也不等于running。
- 现有24项隔离生命周期/归档测试通过。复用生命周期VM harness额外验证3项：idle成功上报后20秒不重复发送，finished同样不重复发送，running在12秒内持续心跳，全部通过。未真实重启接收端，这些测试证明发送行为，不声称复现截图根因。
- Pi原生RPC文档描述受控子进程的stdin/stdout模式，不是给现有TUI进程自动提供可连接的查询入口；本次没有启动另一份Pi。
- 可行的后续改动：在现有认证socket增加只读status动作，返回由当前集成状态与运行上下文生成的状态快照；iTermate在启动、唤醒、重连或租约失效时补查。当前只做验证，未实现该接口。

## Plan

1. 核对现有发现元数据、socket协议、状态上报和身份映射。
2. 只读查询当前端点，并执行隔离生命周期及补报行为测试。
3. 区分现有能力、可实现方案和未覆盖场景，保留脱敏证据。

## Verification Notes

- 证据位于../artifacts/verify-proactive-session-status/evidence/。
- 现有测试命令：node --experimental-vm-modules --test integrations/pi/subagent-lifecycle.test.mjs integrations/pi/archive-lifecycle.test.mjs。
- 定向测试复现：复制subagent-lifecycle.test.mjs到临时目录，将其读取iTermate-integration.ts的URL替换为仓库绝对路径，追加evidence/republication-test-fragment.mjs；使用node --experimental-vm-modules --test --test-name-pattern='proactive probe:'执行临时文件。
- 未改产品文件、未覆盖安装态、未重启App/Bridge/Pi；未验证尚不存在的status接口，未将查询拒绝视为成功获取状态。

## Result

- T1: live-observation.json：6个新鲜Pi端点均唯一匹配iTerm2真实Session，status查询全部被拒绝且无状态字段；源码端点仅支持archive。lifecycle-tests.log为24/24通过，republication-tests.log为3/3通过；当前可发现和匹配实例，但没有主动查询生命周期状态接口。
- T2: 可在现有私有端点实现只读status查询，无需另启Pi；当前未实现。隔离测试确认idle/finished确认后不周期重报、running保持心跳，说明接收端丢失状态后的恢复存在缺口，但不等于已定位截图根因。未改产品文件或安装文件，未发送archive，未重启进程；6个受查询PID查询后均存活，证据不含凭据。
- Review gate: Skipped — R0只读验证结果，现有协议拒绝与上报行为都有直接证据，无独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 只读验证与相关测试，无产品交付文件变更；仅任务记录及脱敏验证证据。
- Snapshot: sha256:98d242fa333c54f115d2d4ff78662b5b83cdad7db001c35ac3efc92dba63cfe4; tasks/artifacts/verify-proactive-session-status/evidence/snapshot.json
- Evidence: 6个真实端点查询与唯一会话映射；24项现有测试及3项定向测试通过；协议和发送逻辑源码核对；不声称已实现主动查询。
- Task fingerprint: 072bd3f48feb07200f376ac24ca976e3005d731105531d94d9ac0bc1c7364ae2

## Verification

- Passed: 最终重算源码/安装文件/证据hash无漂移，24项与3项日志均fail 0；6个端点的拒绝结果与协议一致，保留现场覆盖和未实现能力边界。
