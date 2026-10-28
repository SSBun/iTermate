# 修复新启动 Codex 被识别为普通终端的问题

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-27 17:50) |
| Kind | Task |

## Target

- [ ] T1: 今后新创建的Codex会话无需逐个手动绑定，即可与所在终端精准自动关联，不依赖cwd或创建时间差猜测；确认当前thread后复用真实状态与标题链路。
- [ ] T2: 保留普通终端与其他Agent的识别行为；unknown仅表示Agent身份不明确，不作为回复类型。
- [ ] T3: 不补救或重新配置已打开的Codex会话，不要求它们执行/status或/title，不重启或向其注入输入。

## Scope

用户最新明确只要求后续新建Codex会话精准自动绑定，排除已经打开的会话补救。处理未来会话的准确身份来源与关联路径，不根据终端名称、最近文件、cwd或时间窗口猜归属。不发布、不运行测试、不重启App/Bridge/Codex、不向现有终端注入输入、不覆盖安装态。Codex当前显式关闭原生标题；改变该偏好会影响未来终端的可见标题，需要明确接受这一副作用，不把范围澄清当作已接受标题变更。

## Plan

1. 用户已排除旧会话补救，不再要求/status、手动Bind或对现有TUI执行/title。
2. 优先采用未来一次性原生标题配置：之后仍直接运行codex并保留共享daemon，TUI自己提供当前thread身份；短前缀必须唯一核验，不能据目录或时间绑定。
3. 用户接受未来可见标题改变后，再在授权范围内配置一次，并完善启动时fail-closed关联，避免原生信号尚未到达时回退时间误配。新会话真实信号还需验证Kiro转发；不启动嵌套Codex CLI。
4. 若未来标题也必须不变，需另行选择并授权no-daemon启动方式或TUI身份publisher，不能暗改后端或shell。完成源码后执行允许的编译/静态核验与fresh只读R2审查，不以编译代替真实新会话绑定证据。

- Current artifacts: 本记录Diagnosis、Resume Evidence与Future Sessions Scope；本任务尚无产品源码、配置或安装态变更。
- Next action: 明确是否接受仅对之后新启动Codex生效的原生标题含App Name与Thread ID这一副作用。
- Required input: 用户对未来可见终端标题变化的选择；旧会话无需配合。

## Diagnosis

- 用户截图中的蓝色方框已表示 Codex 身份，不能把保留 shell 标题等同于未检测到 CLI。源码身份与对话关联是两个阶段，权威为 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/CodexSessionMonitor.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/CodexSessionMonitor.swift) 的 observations、codexProcess 与 resolveMatch，以及 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift) 的 Codex overlay/标题链路。
- 2026-10-27 只读真实 Bridge socket 快照：MyTwitter 外层 TTY012 的 codexThreadIDPrefix 为 nil；8个其他可见终端也没有 thread 标题信号。Bridge 对该行只上报外层普通命令，Codex 身份由 Swift 原生 overlay 补入，不能仅凭原始 Bridge 的 activityKind=command 判定 App 识别失败。
- 唯一原生交互 Codex PID2343 在内层 TTY013，祖先链为2343→2233(node)→45659(zsh)→45650(kiro-cli-term，外层TTY012)。Darwin proc_pidinfo 的136字节proc_bsdinfo给出精确启动时间15:14:47.842285（本地时区）。其启动参数仅有可执行文件，没有resume参数；lsof未发现rollout文件描述符。
- 仅读取当日根会话首行元数据：同目录最近候选创建于15:15:17.963，距CLI启动30.120715秒，超过resolveMatch现有30秒兼容窗口。其他当日同目录候选相距一个多小时。这个时间差解释兼容路径为何不匹配，但不能证明该候选就是当前前台thread，故不扩大窗口或强行绑定。
- 只读取 Codex 配置相关两行，确认 tui.terminal_title=[]。原生thread标题路径因该偏好关闭而无信号。未读取或输出对话正文、完整thread UUID、凭据或原始日志。
- 仓库与安装App内的Bridge SHA256均为2592aa918fe7fdbe39b3f7c13f022804ad09c6ab0e7d8bc0578141bdb75e4a56，不是Bridge副本落后。App PID70525保持运行，未主动重启任何进程。
- 对照既有取消任务与Blocked任务，扩大时间窗口不满足可靠归属边界，启用原生thread标题的许可仍未获得。本轮不复活旧任务、不改变其Required审查义务。
- Context完整元数据索引已复核；CTX-terminal-backends既有内容已经覆盖30秒兼容窗口、原生标题信号、嵌套PTY和未知状态语义。本轮没有新稳定事实需要写入Context；现有“工程与组件”未索引警告保持不动。

## Resume Evidence

- 2026-10-27用户在请求提交本次回复语义优化后追加“continue to fix the codex status issue”。先完成限定提交7710b3f（10个优化文件，不含点击图标功能、不推送），再恢复本任务。提交任务及本任务独立，不把提交当作Codex状态修复。
- 本轮只读重新观察到三个原生交互Codex（PID88889/8053/353），均无resume参数，均无rollout文件FD；原PID2343已由用户运行环境变化退出，未由Agent终止。Bridge当前13个终端的原生codexThreadIDPrefix全为nil，原生标题设置仍为[]。
- 仅读取npm包元数据确认CLI当前为0.164.0，不再沿用历史0.163假设。对两份logs_2.sqlite采用mode=ro连接，检查schema及五种精确PID字段格式；三个CLI均未匹配到显式PID日志元数据，不能据此构造process_uuid→thread映射。此结论仅限查询格式，不声称穷尽全部日志或所有潜在上游能力；未输出日志正文、凭据或完整thread ID。
- 固定版本官方源码已重新获取：[0.164 event_dispatch.rs](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/tui/src/app/event_dispatch.rs) 的AppEvent::TerminalTitleSetup将选择保存后立即调用chat_widget.setup_terminal_title；[0.164 slash_command.rs](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/tui/src/slash_command.rs)包含/title。故当前TUI内可应用设置，不必先重启；但不能保证Kiro实际转发，仍需现场信号证明。
- 本轮没有改Codex配置、源码或安装态，没有注入终端输入、运行测试、调用模型或重启任何进程。已确认需要的是准确thread归属，不是把生命周期空值重新定义成unknown回复。
- 已加载相关Context Pack并复核权威。/title原地应用是操作恢复条件，暂记本任务；现有Pack已覆盖原生thread信号边界，本轮无新的产品源码事实需要改写Context。已有未索引章节保留。

## Future Sessions Scope

- 用户最新原话：“不需要补救已经打开的codex，但是后续codex新创建的session需要被精准绑定”。该范围替代此前现有TUI的/title恢复计划，旧会话无需操作。
- 已核对AgentIntegrationManager：Codex显示Automatic，但setInstalled对Codex不配置，updateInstalledIntegrations只清理旧hooks，不修改terminal_title。因此未来启动尚不会自动获得所需原生身份信号。
- 当前最小路径是一次设置原生标题信号，保留原始codex命令和daemon，不需逐会话手动绑定；它会改变未来可见终端标题，尚未取得对这一副作用的明确选择。不得虚构用户禁止标题，也不得虚构已经接受。
- 固定版本status_surfaces.rs与daemon_startup.rs已获取，方案仍需真实Kiro转发证明。未修改配置、安装态或产品源码，未执行测试；相关Context已经覆盖原生信号边界，本轮无新增稳定事实需要写入。

## Task Summary

本任务仅完成Codex对话关联缺口及未来新会话范围的只读诊断，没有修改产品源码、构建产物、Codex配置或用户安装态。
