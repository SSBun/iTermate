# 修复 Pi 会话未显示 Agent 运行图标

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-14 16:16) |
| Kind | Task |

## Target

- [ ] T1: 正常启动 Codex、使用共享后台服务时，对话开始后的 Agent 状态准确归属于对应终端会话，不串到其他行，并通过运行现场核验。
- [ ] T3: 不要求用户改用额外启动入口或 --no-daemon；首条消息前的普通命令图标作为已接受限制保留。

## Scope

- 仅处理本次会话状态显示问题；不主动重启 App、Bridge 或用户会话，不覆盖用户安装集成，不运行测试套件。

## Plan

1. 已确认目标为 MyTwitter 行并对齐修订目标；只读比较真实进程、上报记录与 Bridge 快照。
2. 已定位共享 Codex daemon 继承旧终端身份；用户要求继续修复该剩余问题。待修订目标对齐后，调查真实客户端与线程的可靠身份映射，不依据目录或进程名称猜测归属。
3. 在不改变启动方式的前提下修复、验证共享后台服务下的状态路由；不能取得可靠身份时明确报告阻塞，不伪造状态。首问前显示保持已接受限制。

## Decisions

- 用户明确拒绝额外的 Codex 启动适配入口，并接受原 T2 所涉及的首问前图标限制；T2 已撤回，不记录为实现通过。
- 此次接受仅针对 SessionStart 延迟，不表示共享 daemon 终端身份误归属问题已修复；此前正确上报的证据来自 --no-daemon 验证会话。

## Observations

- 用户截图圈出 MyTwitter 行。只读 Bridge 快照显示其 ID 为 201B2B75-CBFE-4FDC-AF8D-8D5999501BE6，status=running、activityKind=command，解释了普通命令图标而非 Agent 图标。
- 当前该行对应终端前台进程链为外层 ttys010 → 内层 ttys011 → Codex PID 33249。Codex 启动于 2026-10-14 15:42:14，晚于截图文件时间 15:39:56，因此不能据此断言截图时也为 Codex。
- 当前支持认证 status 查询的运行中 Pi（iTermate D9036859…、skills 441C375D…）均返回 running，且 Bridge 快照均为 running/agent。其他部分 Pi 的发现描述缺少 supportsStatus；尚不能据此认定其正在运行或构成当前问题。
- 未修改产品源码、未安装、未重启、未执行测试。已有其他任务的未提交改动保持原样。
- 修订目标确认后的现场：Codex opt-in marker 已存在且 enabled=true，旧 _iTermate 原生条目数为 0；缓存插件的 7 个 iTermate 内置规则均为 active。不能套用上一任务“尚未启用”的历史结论。
- 决定性证据：codex-iterm-343dddef-3167-4920-9fc1-44c5daefda85.json 的 codexSessionId=01a13958-c950-7782-998e-336bd8d1dd12，Codex threads 表查询该 ID 的 cwd 为 MyTwitter；上报终端却为 343DDDEF-3167-4920-9FC1-44C5DAEFDA85，而不是目标 201B2B75-CBFE-4FDC-AF8D-8D5999501BE6。
- MyTwitter 客户端 PID 33249 的终端环境是正确的 201B2B75…；共享 daemon PID 43081 的终端环境为 343DDDEF…，正与错误上报一致。上报文件的 ownerProcess 是 daemon PID 43023，而非 MyTwitter TUI，证实原有上报依赖宿主进程环境在共享 daemon 下不再代表当前客户端。
- Codex 0.162.1 的本机 --help 明确支持 --no-daemon（不使用共享后台 server，即使其已运行）。plugin_hooks 被标为 removed；该兼容 flag 的 false 不是插件 hooks 被禁用的证据。
- 上游同类问题及终端集成使用 --no-daemon 的规避依据：https://github.com/openai/codex/issues/48500 。本任务的根因以本机映射和进程环境为主要证据，不依赖网页推断。

## Startup Verification

- 新验证会话为 iTermate E1BCB187-8325-469C-9881-B365A313C2B3；Codex 线程 01a13968-785d-7211-b0c8-0bea04e90bef，上报 ownerProcess PID 94207，启动时间 15:55:07。
- 提问后只读上报记录 status=running、lastError=null，itermSessionId 与目标相符；同次 Bridge 快照为 running/agent。表明独立模式下工作状态已送达正确行，不代表启动空闲已修复。
- Codex 0.162.1 共享 app-server 的只读 hooks/list 返回 CSL SessionStart 与 UserPromptSubmit 分发器 enabled=true、trustStatus=trusted。该查询确认当前同项目配置，不等同目标独立进程历史投递结果；没有修改信任或发送启动事件。
- 同版本源码 SessionStart input 含 session_id 与 source，reporter 明确支持 startup/resume/clear → idle。系统日志存在启动时间附近 hook/started，但没有事件名和 payload，无法仅据这些日志断言 SessionStart 未触发；旧版上游延迟到首问的问题仅为候选，不作本机定论。
- 首次只读 app-server 连接按行协议被关闭；查明该版本 Unix socket 使用 WebSocket 后，以正确协议仅执行 initialize 与 hooks/list 成功。没有创建线程、发消息或启动/停止服务。
- 首问已更新覆盖 reporter 当前状态，缺少首问前的状态文件与 Bridge 配对证据。需要用户保留新的未提问现场后继续定位，不凭截图猜改代码。

## Initial State Findings

- 用户保留新启动、尚未提问的现场；PID 37191 于 16:05:10 启动，进程命令含 --no-daemon，ITERM_SESSION_ID 正确指向 E1BCB187-8325-469C-9881-B365A313C2B3。
- 同期 Bridge 对该行仍给出 running/command；上报状态文件仍是旧 PID 94207 于 16:05:04 写入的 detached、sequence=22，没有新进程的 SessionStart idle 记录。
- Codex 日志将新线程 01a13971-bcb1-7e83-b683-024491ea655d 关联到 process_uuid pid:37191:a9c2e1d6-a48e-4251-ae40-a0f60b17c441；该进程启动后没有 hook/started 或 hook/completed 日志，只有 hooks/list 和 thread/start 等初始化记录。
- 对应版本上游源码 https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/core/src/session/turn.rs 第 322 行在 turn 执行中调用 run_pending_session_start_hooks；https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/core/src/hook_runtime.rs 中该函数取出 pending source 并分发 SessionStart。与本机首问前无上报、首问后正确运行的证据一致。
- 结论：不是 Canvas 未刷新，也不是 App 已收到 idle 后显示错误；欢迎界面尚没有生命周期 hook 上报，因此仍回退普通命令状态。单改现有 reporter 的 SessionStart 映射不能使未触发的 hook 提前发生。
- 不采用进程存活推断工作/空闲，也不伪造 SessionStart、手工修改 Bridge 状态或要求用户发无意义问题来掩盖。若必须首问前显示 Agent idle，需要显式启动适配信号（含真实终端身份、与正式生命周期的交接及异常退出清理），或等待上游提供启动时事件。

## Shared Daemon Investigation

- 用户要求正常启动并保留共享后台服务，不增加启动入口、不依赖 --no-daemon；已确认该修订目标。
- 核对 Codex rust-v0.162.1 的 hooks/src/schema.rs：SessionStart、UserPromptSubmit、工具等输入含 thread/session_id，但没有客户端 PID、客户端 TTY 或触发客户端的终端环境字段。不能用 daemon 继承的 ITERM_SESSION_ID 替代缺失身份。
- 同版本 app-server-protocol/src/protocol/common.rs 与 v2/thread.rs 未提供可用于本需求的本地 TUI 客户端到当前线程的查询；thread/loaded/list 只列出已加载线程。server/diagnostics 只有进程 ID、内存和 gauges，不提供客户端/终端绑定。
- 只读检查本机三个共享模式 TUI 的日志元数据，process_uuid 可识别进程，但 thread_id 列均无值，不能据此可靠建立映射。未使用聊天内容、目录相同、最近活动或焦点猜测绑定。
- 上游 https://github.com/openai/codex/issues/48500 记录共享 daemon 的跨终端环境误归属；https://github.com/openai/codex/issues/44902 提议传入客户端环境；https://github.com/openai/codex/issues/48880 请求客户端当前线程信号，关闭原因为 duplicate，非修复合入证据。
- 当前核验范围内没有可靠的端到端修复路径；仅在 iTermate 拒绝不可信的 daemon 终端身份可以防串线，但不能实现目标行正常显示 Agent 状态，不得将其冒充完整修复。

## Task Summary

尚未修改产品代码或用户安装配置；已定位共享宿主终端身份误归属和 SessionStart 延迟两个独立原因。独立模式提问后上报已验证，首问前显示限制已获接受；共享模式正确归属仍受上游身份信号缺失阻塞。

## Block

- Reason: Codex 0.162.1 的共享 daemon hooks 不携带触发客户端的可靠终端身份；已核对的公开协议和本机日志元数据也不能建立客户端与线程的唯一绑定。在保持共享服务、不改启动方式的约束下，无法实现准确路由。
- Unblock when: 上游提供可验证的客户端/线程/终端绑定，或用户明确接受缩减为防串线降级（身份不可确认时不报告 Agent 状态），或授权改变运行方式/修改 Codex 宿主。
