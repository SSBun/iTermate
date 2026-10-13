# 调查 Codex 会话误显示命令运行图标的原因

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-12 18:37) |
| Artifacts | [Artifacts](../artifacts/investigate-codex-command-icon/) |
| Kind | Plan |

## Target
- [x] T1: 基于代码与可获得的运行证据，解释截图中 Codex 会话显示普通命令运行图标而非 Agent 图标的原因，区分已证实结论与未验证假设。
- [x] T2: 研究修复方案，给出有证据支持的推荐路径、必要改动点和验证条件，说明剩余不确定性。
- [x] T3: 实施 Codex 状态上报确认、有界重试与恢复，正确处理启动、压缩、中断和结束，隔离会话及轮次，避免旧事件覆盖新状态。
- [x] T4: 不修改 Kiro、通用进程识别或 Pi 逻辑，不覆盖用户安装配置、不启动或重启应用、不运行测试；交付可构建源码并披露运行验证限制。

## Scope

- 已获用户明确实施授权：仅 Codex 集成及其必要协议接收支持；不得修改 Kiro、通用进程识别、Pi、用户安装配置。不启动或重启 App/Bridge，不运行测试。

## Decisions

- 已确认直接原因是上游分类为 command，而不是 SwiftUI 将 agent 图标画错。两次 Bridge socket 观察中，目标 Session 4BBC8646-7E82-4002-BCC4-5E1E7F36B2DC 均为 running/command；另一个 Codex Session 343DDDEF-3167-4920-9FC1-44C5DAEFDA85 已为 idle/agent。不能把原截图视为所有 Codex 永久无法识别。
- iTerm2 API 对这两个 Session 均返回无最近 Prompt，jobName 为截断的 zsh (kiro-cli-te，commandLine 为带引号的 zsh (kiro-cli-term)，shell 为 zsh。真实 Codex PID 99669 与 80878 分别在内层 ttys011、ttys031，外层 Session TTY 为 ttys010、ttys030；Codex 环境中的 iTerm Session ID 分别精确对应上述 Session。
- Bridge current_foreground_job 将包装器 jobName 与 shell 比较，因名称不相等判为运行中；is_agent_command 仅接受首个可执行文件 basename 为 pi/codex，无法识别这里的 Kiro 包装器。因此在没有 Agent 状态所有权时，foreground fallback 把包装器标成普通 command。
- Agent 图标依赖 setSessionStatus 生命周期上报产生 activityKind=agent。Codex 的四个 iTermate hooks 已存在；已安装 status 脚本与仓库 SHA-256 一致，已安装 Bridge 文件与仓库一致。未发现需要直接重装的证据；磁盘一致不单独证明运行进程加载内容一致。
- iTerm 路径 report_iterm 是单次上报，没有 Ghostty/TTY 分支的持续 heartbeat；exchange 会吞掉连接/超时错误，且不校验返回的 actionResult。因而漏报或状态丢失不具备同等恢复能力。但目前没有目标 turn 的 hook 执行日志，不能断言本次是 hook 未执行、传输失败还是状态后来被清理。
- Swift SessionStatusAnimationTarget 按 activityKind 选择图标，缺失时也回退为 command。排查重点应是上报和状态恢复，而不是替换图标样式。

## Plan

1. 先补 status reporter 的协议确认与最小诊断：按 requestId 等待 actionResult.ok，跳过 hello/snapshot，设置整体截止时间且小于现有 3 秒 hook timeout；记录事件名、路由身份、阶段及错误，不记录 prompt、回答或完整环境。路由选择与投递成功分开；iTerm Bridge 失败不能直接改投内层 TTY。
2. 解析 Codex stdin 的结构化事件，不再读后丢弃。保留 Codex session_id、turn_id 与 iTerm Session UUID 的不同语义。SessionStart 的 startup/resume/clear 初始化身份；compact 不重置正在进行的 turn；未支持 source 不猜测。Interrupt 清除当前 turn 的 running，但不作为成功完成。SessionEnd 释放对应身份与发送任务。
3. 为 iTerm 路径增加有界补发和状态恢复，复用现有状态脚本/Bridge 协议与 Pi 已采用的 ACK、reporterId、sequence、generation 模式，不另建通用服务。只有 ACK 确认后才续租；失败重发当前完整转换而非永远发可能被拒绝的 heartbeat。跨 hook 进程用同一实例及 turn 代际、锁和序号串行化发送；旧 turn Stop/worker 不能覆盖新 turn。复用现有 worker 机制前必须增加真实实例身份、PID 生存与启动身份校验和有界退出，不能把当前六小时超时当作充分防护。
4. 明确心跳边界：worker 活着只证明传输存活，不证明模型仍工作。漏掉 Stop/Interrupt 时，单靠缓存续租仍可能永远 running；缺乏新鲜生命周期证据时降为未知，不伪造 finished/idle。Bridge 重建后，只在当前身份仍有效且当前状态可确认时恢复；idle/finished 不无限重放，避免撤销用户已读状态或重复完成统计。必要时增加窄范围、身份约束的恢复协议，但不让旧 reporter 覆盖当前 owner。
5. 用户已排除 Kiro 与通用进程识别改动：仅修复 Codex 生命周期上报。不得将 shell 名称加入 Agent 判断，不新增进程扫描式身份发现或图标。
6. 经后续实现授权后，修改范围优先为 integrations/status/iTermate-status.py、AgentIntegrations.swift 的事件安装表及对应 Bridge 必要的状态所有权校验；不改 unrelated Pi 逻辑。安装时维持现有 hook 位置和非 iTermate 内容，提示用户用 /hooks 审核变更，不写入 trusted_hash 或绕过信任。
7. 验证矩阵：两个并行 Codex 会话；开始/结束/中断；compact 中途继续；Stop hook 继续执行；Bridge 暂断与重建；ACK 前插入快照；连接失败/拒绝 ACK；旧 Stop 和 heartbeat 乱序；未信任 hook；普通 shell/Pi 不回归。当前仅写回归覆盖、执行语法检查与隔离构建，不运行测试。真实 UI/故障注入留待用户运行新构建，明确不能据编译成功声称现场已修复。

## Remediation

- 第 01 轮三个发现均已核实并整改：同 session 的新生产者按 PID/启动身份重新绑定；未 ACK 的 claim 保存最近已确认 owner，补发采用 compare-and-swap 而非无条件抢占；终态补发不再要求退出中的生产者存活。新增对应回归用例但未执行。
- 补充旧 Codex worker 在其他 Agent detached 后仍不可重占的 tombstone；延迟 SessionEnd 只释放 Agent 所有权，保留随后已观察到的普通命令状态。
- 第 02 轮确认 TR-1/TR-3 解决、TR-2 有实质进展但跨终态仍有遗漏；整改为同 session 的 pending claim 持续到 ACK，Stop/Interrupt/SessionEnd 不再无条件丢弃，补充三种终态的回归覆盖（未运行）。

## Implementation Boundaries

- 用户随后明确要求实施上述 Codex 专项方案；不涉及 Kiro、通用终端识别或 Pi。增强恢复限定当前问题所在的 iTerm 通路，Ghostty 继续使用原有 TTY 上报（同时忽略 compact/tool 刷新事件并接受中断 idle）。
- iTerm 续报只维持最近五分钟内真实 hook 观察且 Codex 生产者进程身份仍存活的 running；没有新观察时停止续租，Bridge 八秒租约到期后状态未知，不伪造完成。无法确认生产者时只做有界投递，不用持续心跳猜测。hook 只检查自己的 Codex 祖先进程 PID/启动时间作存活校验，不扫描或识别 Kiro/终端进程树。
- 非运行状态失败补发最长十五秒；收件端拒绝时不强行覆盖 owner。已成功的 finished 重试按事件身份去重，保留用户已读 idle。当前无 turn/completed 权威通知，因此 Stop 后其他 hook 要求继续仍依靠后续 UserPromptSubmit 更新，不承诺消除所有短暂状态转换。
- 本轮交付源码，不直接安装或启动。测试已新增但不执行；现有构建与语法检查只能证明源码可构建，不能证明用户现场已经恢复。

## Task Summary

**Codex 状态集成**：[/Users/caishilin/Desktop/personal/iTermate/integrations/status](file:///Users/caishilin/Desktop/personal/iTermate/integrations/status) 增加匹配 ACK、有界状态续报、生命周期解析、会话轮次隔离与回归用例。

**Bridge**：[/Users/caishilin/Desktop/personal/iTermate/iTermateBridge](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge) 增加 Codex 专属 owner/事件校验及幂等结束上报，避免旧 worker 覆盖新 Agent 或重复恢复已读图标；补充回归用例。

**集成安装器**：[/Users/caishilin/Desktop/personal/iTermate/iTermate](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 识别旧版安装并补齐 Codex 工具观察与中断 hook，保持既有 hook 索引位置。

**安装回归覆盖**：[/Users/caishilin/Desktop/personal/iTermate/iTermateTests](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests) 增加事件升级、索引保持与卸载覆盖。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/investigate-codex-command-icon/reviews/round-01.md) | sha256:a271eadf8183b67fac3a27158b65b7884d57029fa7bd2bd57d2cf9fc2d216cfd | findings: TR-1, TR-2, TR-3 |
| 02 | [Round 02](../artifacts/investigate-codex-command-icon/reviews/round-02.md) | sha256:5d6ad67a52df1ce8fd6f20e57d8ba700058383d75a00785889bc13002ec8fd29 | findings: TR-2；TR-1/TR-3 resolved |
| 03 | [Round 03](../artifacts/investigate-codex-command-icon/reviews/round-03.md) | sha256:a1db41d169a2d63121947eb3fea0c8bea7434f334cb999164ad06940c9241b40 | no blocking findings；TR-1/TR-2/TR-3 resolved |

## Research Findings

- 推荐先修复现有 Codex hook 通路，不通过终端文字/模型判断 Agent 类型，也不将包装器一律标成 Agent。最小修复能解决可靠投递与已知生命周期误映射；不能声称仅加心跳已保证所有故障下的精确状态。
- npm 安装元数据版本为 0.162.1；已对照相同 rust-v0.162.1 tag 的 hook 源码，而不仅引用 main。SessionStartSource 包含 Compact，source 的 matcher 是官方机制；当前无 matcher 的 SessionStart→idle 确有中途压缩误重置风险，但未证明它造成原截图。
- 官方文档明确 hooks 在执行前必须被用户信任；本机 features.hooks=true，四个 iTermate hook 对应 key 均有 trusted_hash 且无 enabled=false。仍不能仅凭 hash 存在确认运行会话当前加载的定义已匹配；应由 /hooks 显示的当前 trusted/modified 状态核实。
- 官方 Stop 是可阻止停止并要求继续的检查点，而非不可逆的完成通知；其他 Stop hook 可并发执行。应检查继续生成的 UserPromptSubmit 及 turn_id 顺序，避免永久停在 finished。若要求完全避免短暂误报完成，hooks 单独不能证明其他 hook 的最终决定，应使用真实 turn/completed 事件源；不以任意延迟冒充确定性。
- 官方提供独立 Interrupt，当前四事件安装表未覆盖；SessionStart compact 也不能简单发 idle。接入身份/turn 元数据后再定义状态机，防止旧事件覆盖新轮。
- app-server 的 turn/completed 和 thread 状态属于更强事件源，但本项目目前不是这些 CLI 会话的协议拥有者。未证实能只读订阅既有 TUI 的同一后端，不建议为本次修复启动第二个 Codex/app-server 或接管用户会话。读取 transcript 作为主状态源同样不推荐：官方明确其格式不稳定。
- 限定查询本地日志数据库最近 80000 条中的 iTermate-status 或 hook WARN/ERROR，没有匹配记录；这不证明 hook 从未执行，也不能作为某一丢失环节的根因证据。

## Sources

- https://developers.openai.com/codex/hooks — hook 信任、并发、stdin、SessionStart compact、Stop continuation、Interrupt、transcript 稳定性边界。
- https://raw.githubusercontent.com/openai/codex/rust-v0.162.1/codex-rs/hooks/src/events/session_start.rs — 相同发行版的 source 与 matcher 行为。
- https://raw.githubusercontent.com/openai/codex/rust-v0.162.1/codex-rs/hooks/src/events/stop.rs — 相同发行版 Stop 实现。
- https://raw.githubusercontent.com/openai/codex/rust-v0.162.1/codex-rs/hooks/src/events/interrupt.rs — 相同发行版 Interrupt 实现。
- https://raw.githubusercontent.com/openai/codex/rust-v0.162.1/codex-rs/hooks/src/engine/discovery.rs — source/event/group/handler 组成 key，当前归一化定义 hash 必须匹配信任记录。
- https://developers.openai.com/codex/app-server — 更强生命周期事件源，非当前最小接入路径。
- 本地：integrations/pi/iTermate-integration.ts 的 report/sendHeartbeat；iTermateBridge/iTermateBridge.py 的 handle_command/set_agent_status；iTermate/AgentIntegrations.swift 的 installCodex/codexConfigurationIsInstalled；iTermate/VenomDebugMonitor.swift 的真实进程关系发现。

## Investigation Evidence

- 2026-10-12：只读真实 socket 两次，目标 command 状态不变；只读 iTerm2 API 得到两会话 Prompt/前台字段。
- 只输出 Codex TERM_PROGRAM、ITERM_SESSION_ID、TERM_SESSION_ID、CODEX_HOME 等限定环境字段，确认 Session 路由一致；未输出其他环境或凭据。
- 来源：iTermateBridge/iTermateBridge.py 的 is_agent_command、current_foreground_job、monitor_session_foreground_job、set_agent_status；integrations/status/iTermate-status.py 的 report_agent、report_iterm、exchange；iTermate/iTermateApp.swift 的 SessionStatusAnimationTarget 初始化。
- App PID 2875 与 Bridge PID 3000 调查后仍为原进程，启动时间分别为 16:11:29 与 16:11:31。未修改产品、安装配置或执行测试；仅维护当前调查任务记录。

## Result

- T1: 先前只读 iTerm API/Bridge 快照已确认 command 分类与缺失生命周期状态；调查证据与未证实环节见 Investigation Evidence。
- T2: 对照官方 hooks 文档及 rust-v0.162.1 源码形成专项修复方案，保留信任、Stop continuation 与未运行现场验证的边界。
- T4: task-owned diff 仅 Codex reporter、必要 Bridge 接收、安装器及回归覆盖；未修改 Kiro/通用进程识别/Pi，未写用户安装态、未启动或重启、未运行测试。隔离 Debug 构建通过。
- T3: snapshot-03.json/diff：静态检查 ACK、事件/轮次隔离、恢复与幂等逻辑；针对第02轮 TR-2 保留未确认 claim 到终态 ACK，并新增三种终态链路覆盖。AST/Swift parse/隔离 Debug build 通过，bundle 脚本与源码一致；测试未运行，真实用户现场未验证。
- Review gate: Passed — 独立只读 run 95535aa6-02da-4d3e-906a-bb67f3c9c92b，round-03.md 无阻塞发现，TR-1/TR-2/TR-3 resolved；主会话已重算七文件哈希全部匹配 snapshot-03，报告已持久化索引。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: Codex 跨进程 owner/事件补发及原 Required 义务；针对终态前置链路刷新复审。
- Snapshot: sha256:a1db41d169a2d63121947eb3fea0c8bea7434f334cb999164ad06940c9241b40
- Evidence: Result T3；snapshot-03.json/diff；AST/Swift parse/隔离构建通过；资源匹配；回归未执行，现场未验证。
- Task fingerprint: 80fe833796d24641f80aa52bd02c56794ca5a777f609a1afd42914d57274e05a

## Verification

- Passed: 终态核验七文件 SHA-256 全匹配 snapshot-03；四 Python AST、两 Swift parse、scope diff-check、Context validate 均通过，构建 bundle 两 Python 资源与源码一致，三轮报告链接均存在。独立复审无阻塞发现；未运行测试/未部署/现场未验证，交付范围为源码。
