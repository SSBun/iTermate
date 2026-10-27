# 调研 Codex 会话可靠关联与状态恢复的完整修复方案

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-23 14:21) |
| Kind | Plan |

## Target

- [ ] T1: Codex终端可可靠关联当前对话，覆盖共享daemon、恢复及同进程对话切换，身份不明确时不串会话或伪造状态
- [ ] T2: 形成有官方来源依据、兼容边界、实施步骤和验收条件的可执行方案，明确现存会话与未来会话的恢复路径

## Scope

本轮只做只读调研和任务内方案记录，不改产品源码、文档或用户配置，不启动或重启App、Bridge、Codex、daemon或终端，不运行测试。既有实现任务为[修复 Pi 与 Codex 状态监听的准确性和恢复问题](fix-pi-codex-state-monitoring.md)，本记录不改其状态或冒称实现已完成。执行本方案时先明确与既有任务的变更归属，不能同时重复实现。

研究面向本机iTerm2、嵌套PTY及原生Codex TUI。远程Codex后端、SSH、tmux不默认承诺兼容；检测到这些边界必须明确能力，而不是套用本地daemon路径。

## Decisions

1. 根因是终端客户端到当前显示thread的身份通道缺失，不是daemon不可用。需要把“终端/进程身份”“当前显示对话”“对话状态与完成历史”分开建模。不能通过加长启动时间窗口、最新文件、cwd、CPU、屏幕文本或daemon最近活动替代身份。
2. 当前已发布Codex可用的近期路径是TUI原生thread-id标题加现有daemon只读查询；它是兼容过渡，不称为零配置、无副作用或完全根治。用户需明确允许改变原生标题，且真实嵌套终端必须证实能转发。保留共享daemon，不默认改成no-daemon，也不增加另一套状态采集框架。
3. 现有运行会话优先由用户在每个异常Codex里使用`/title`，选择App Name与Thread ID，保存后现场观察。这条路径在0.163源码中立即更新当前TUI并持久化配置，不必先退出Codex或重启iTermate。仅从外部改配置文件不等于其他已运行TUI立即更新。保留原配置，失败可恢复；不得由Agent自动向终端发送输入。
4. 产品侧应把可靠原生身份优先于文件枚举；已取得完整ID时，即使暂时没有rollout，也能建立绑定并尝试daemon只读状态。29字符前缀必须唯一扩展为完整ID并核验metadata，尚无可扩展记录时维持“等待身份确认”，不能猜选。已映射后的新身份、丢失或无效信号必须立即清理旧状态、标题和异步请求。
5. 当前实现把同thread的多个精确终端认领当冲突，是后续兼容缺口；Codex允许零个、一个或多个客户端显示同一thread。精确、各自来源已核验的多终端映射应允许；只有启发式竞争或同终端无法唯一确认才拒绝。完成通知/计数继续按thread/turn稳定ID全局去重，不因多终端重复累计。
6. 真正不占用标题、不受PTY控制序列过滤影响的根治，需要Codex TUI提供本地机器可读的当前显示身份。当前查到的0.163、0.164与main接口没有可直接消费的标准TUI→thread查询；不能虚构`tui.report_thread_id`等配置键已存在。这需要上游支持或明确授权维护一个小型Codex TUI补丁，不是只改iTermate即可无条件完成的能力。
7. 若后续授权长期根治，优先只新增TUI身份发布，不复制Codex完整生命周期。建议最小载体是同用户私有目录中的按TUI实例保存的原子快照，包含完整displayedThreadID、PID、进程启动身份、随机实例代际、递增序列与新鲜度；App继续复用现有daemon只读状态/历史。相较只发一次事件，周期更新的快照可恢复App晚启动、重连和崩溃遗留，也绕过Kiro对OSC的过滤；不需要新常驻服务。该载体是本方案设计，不是上游现有接口。
8. TUI发布源必须是实际已显示的`current_displayed_thread_id()`，覆盖启动、新建、resume、fork及已加载thread间X→Y→X切换；不能在请求切换刚开始时抢先宣告。切换中的无显示身份要明确为空，后台thread活动不得改写前台选择。身份读取需区分根thread与子代理；不把后台子代理虚构为新的终端行，用户主动查看子代理时的展示及完成归属需有明确来源标记，不能沿用当前仅接受root metadata的假设。
9. 原生状态协议可作为将来的辅助显示来源，不能替代完整thread身份、可靠成功/失败和去重完成账本。不能把0.163的idle当finished。源码显示0.164增加done/error，但本机CLI仍是0.163，不能因daemon版本是0.164就声称TUI发出了新版事件。
10. 用户配置、安装态、维护Codex fork或发布上游PR都需要各自的实际授权；本轮不执行。若用户只允许改iTermate且保持当前Codex、配置与标题不变，应明确报告无法保证任意既有daemon会话的准确自动映射，而不是不断叠加猜测。

## Plan

1. 先验证最小恢复通道：由用户在一个异常现有TUI通过`/title`开启App Name与Thread ID；观察该精确终端的动态terminalWindowName、前缀扩展及对应daemon只读状态。必须观察真实返回信号，不能以保存配置或编译通过代替。若标题没到达外层iTerm2，明确定位为传输/终端能力缺口，停止扩大时间窗口。
2. 在原生通道确实可用后，完善iTermate的身份发现与恢复：明确无进程、已识别但无身份、前缀待扩展、身份冲突、daemon不可达等原因；原生身份优先，按实例失效旧关联；支持有来源证明的同thread多终端显示；状态、标题和完成消费继续复用当前实现。对低置信度cwd/时间结果不得宣称具有切换跟随保证，支持严格模式关闭该类推断。
3. 用下述矩阵验收当前发布版方案。通过真实Kiro转发与无输入thread切换前，不对用户承诺可靠全自动；无法通过时只保留有明确原因的unknown和可逆的临时恢复入口。
4. 若需要不改可见标题且继续共享daemon，另行取得修改/构建Codex TUI或等待上游能力的授权。先完成最小身份快照publisher与iTermate读取器：文件目录仅当前用户可访问，拒绝符号链接/异主/超长及非法内容；同时核验PID+启动时间、真实前台进程树与当前终端Session；旧序列、失效代际、过期快照和旧PID残留全部拒绝。周期新鲜度使用有界窗口，睡眠唤醒后等待新报告；退出尽力清理，但正确性不依赖正常退出。
5. 长期通道必须先通过同目录双终端及X→Y→X、不发prompt的验收，再接入现有只读daemon。不要增加thread/resume、turn/start、审批或输入动作。未知协议/版本退回有解释的unknown，标题通道仅在用户已选择时作为兼容后备，不依赖启动时间推断当前thread。
6. 后续实现主Agent完成按Target的当前内容自检，执行允许的编译/静态检查；自动化测试仅在用户届时明确要求后运行。跨进程身份、异步状态与完成消费的改动按R2准备真正fresh、工具级只读的独立task-review，未完成审查和真实行为验证不得关闭既有修复任务。

- Current artifacts: 本记录的Decisions、源码依据、方案比较及验收矩阵；已有运行诊断保存在既有修复任务的Screenshot Recheck。
- Next action: 后续获授权实施时，先验证一个现有异常Codex的原生标题信号能否穿过Kiro，并选择兼容路径或TUI身份发布路径；本轮不继续修改用户设置。
- Required input: 调研无需更多输入。执行阶段需允许改变原生标题；若要求标题不变且保持daemon，则需允许Codex TUI适配或等待上游提供身份接口。真实界面/切换验收需要用户操作现有会话，自动化测试需另行明确要求。

## Research Findings

### 本机基线与证据边界

- 本轮只读读取已安装包元数据：iTerm2 3.7.1、Codex npm CLI 0.163.0。此前同一调研线程的进程路径显示daemon为0.164.0，前后端版本必须分开判断。未运行Codex来取得版本，未改变会话。
- 此前现场诊断：两个未关联CLI没有rollout FD、resume UUID或启动±30秒内同目录候选；原生标题配置为空数组。详情在既有修复任务的Screenshot Recheck；这些只是该次运行的观察，不是长期固定的会话数量。
- 仓库`iTermateBridge/iTermateBridge.py:35-49`只解析严格的`codex | <完整UUID或29字符前缀...>`格式并带可选标题生成spinner；每快照从动态terminalWindowName读取，而非Session展示名。
- `iTermate/CodexSessionMonitor.swift:426-550`处理冲突、标题约束、FD、resume及cwd/时间匹配；现有精确标题仍先要求找到根rollout，且多个同等级精确认领会被移除。
- `iTermate/ItermBridge.swift:1411-1467`拒绝同thread多个手动绑定，并过滤重复自动绑定；`iTermate/SessionNotifications.swift:33-53`已经按稳定完成ID跨pane、数据源去重。这两处语义需要一起考虑，不能只删一个冲突判断。
- 不把上游Issue中的其他平台复现当作本机已复现。Kiro标题阻断的公开报告在WSL/Windows Terminal上，本机macOS的实际转发效果仍未验证。

### 方案比较

| 方法 | 对当前问题的价值 | 结论 |
| --- | --- | --- |
| 扩大启动时间窗口、最近更新文件、cwd | 可增加碰巧匹配比例，同目录并行或旧会话恢复容易串台，不能观察无新prompt切换 | 不作为可靠方案 |
| 只列daemon loaded threads、订阅thread事件 | 得到对话集合或活动，不知道哪一个TUI在显示哪一个thread；订阅集合也不等于当前选择 | 不解决缺失的映射 |
| hooks/notify + ITERM_SESSION_ID或父进程 | 共享daemon执行hook时可能使用最初客户端的环境；thread ID正确但终端身份错误 | 不能作为daemon场景的身份来源 |
| 原生thread-id标题 | 来源于当前TUI，现有代码已能消费；0.163截为29字符加省略号，依赖唯一metadata扩展、标题配置和转发 | 近期优先验证的兼容路径，不是无条件根治 |
| `/status`人工绑定 | 可救急，但不自动跟随以后切换 | 不作为T1完成条件 |
| `codex --no-daemon` | 绕开共享daemon及其环境归属问题，需重新启动会话，影响共享服务和remote control；hooks仍不等于每次显示切换 | 可选降级，不默认全局关闭daemon，不保证单独彻底修复 |
| 新版OSC 7501/21337 | TUI直接报告粗状态，归属在收到它的终端；不带完整thread ID，0.163仅idle/working/blocked | 辅助方向，不能代替完整关联、标题和完成统计 |
| TUI直接发布完整当前thread身份 | 源头准确，可覆盖无prompt切换、App晚启动与多客户端，不依赖daemon归属猜测 | 长期根治；现有标准接口未提供，需上游或小型TUI补丁 |

### 容易误判的兼容细节

- Codex 0.163的`/title`已存在；保存由TUI本地事件处理，成功后立即调用setup_terminal_title与refresh_terminal_title。此前“只能重开才能生效”的表达过强，应改为：外部改配置未必热加载，但可用每个TUI自己的`/title`即时应用。
- `thread-id`/`session-id`是同一个标题项的别名，不是`thread`或`thread-name`；后两项可能变成自然语言标题，不能用来绑定。
- 0.163把thread-id项限制为32个字符，36字符UUID显示29字符加`...`。本次查阅的0.164对应代码仍保留32字符截断；不能把升级当作已解决完整UUID发布。
- 不应通过`codex -c 'tui.terminal_title=...'`包装启动来暗中“解决”：0.163的daemon_startup配置覆盖白名单不包含该项，可能让CLI转为embedded模式，掩盖真正daemon兼容问题。使用受支持的本地TUI设置并现场确认后端模式。
- iTerm2 3.7.1源码具备OSC 21337设置状态，但未包含master新增的ProgramStatus实现、get_session_status内置函数与session get-status入口；不能照抄master文档，声称本机已可读到完整原生状态。需进行版本/能力探测后才能启用。
- Codex 0.163的OSC 7501状态为idle/working/blocked，不区分任务成功、失败或完成；0.164新增done/error及blocked kind。它们都没有输出完整thread ID，故无法替代现有按thread/turn读取的完成历史。
- 同一thread可以被多个TUI显示。终端→thread必须唯一，但thread→终端可以是集合；“重复thread一定串台”的假设不成立。后台订阅、子代理活动不等于当前显示选择。
- TUI身份发布中的PID/序列只是本机同用户通信校验，不能宣称能防御同UID恶意进程。持有当前进程身份及终端祖先证据仍是拒绝陈旧、错误路由的必要条件。

## Acceptance Matrix

以下为后续实施的验收条件，均未在本轮运行或标为通过。

| 场景 | 必须观察到的结果 |
| --- | --- |
| 两个相同cwd的TUI共享一个daemon | 分别准确关联自己的当前thread，不按时间或最新活动抢占 |
| 恢复任意历史thread、启动选择器等待很久 | 取得TUI身份后关联，不受进程启动与thread创建时间差限制 |
| 同一TUI执行new/resume/fork | 原终端行切到新ID，旧标题/状态/迟到daemon响应不能覆盖 |
| 已加载thread间X→Y→X、不提交新prompt | 每次实际显示选择均更新；hook无事件不影响准确性 |
| 后台thread及子代理继续运行 | 不改变另一前台thread的身份；子代理来源清楚，不产生虚构终端行 |
| 两个TUI显示同一thread | 两行均可显示同thread状态，单次完成只通知/计数一次 |
| App晚启动、Bridge重连、睡眠唤醒 | 可恢复当前身份；失效代际或未恢复的新鲜度显示未知，不冒报空闲 |
| TUI崩溃、正常退出、PID/TTY复用 | 清理旧实例归属；残留文件/变量不能污染新的终端或CLI |
| 标题路径遇到Kiro、用户自定义标题、无效/冲突前缀 | 检测出通道不可用或歧义，说明原因，不能偷偷回退为错误绑定 |
| 短前缀暂时没有rollout、完整ID但文件未落盘 | 前者等待唯一身份；后者可只读查询daemon，不把文件存在设为全部状态的前提 |
| daemon中断、返回旧ID、乱序响应 | 不启动/推进其他thread，拒绝过时或错ID数据，保留有效证据或明确unknown |
| running/审批等待/用户提问/成功/失败/中止/查看完成 | 状态语义保持区分；只有可靠完成证据计成功，unknown及原生idle不算完成 |
| 模型标题生成及缓存恢复 | 只有已核验thread的可见消息可进入本地模型，旧thread异步标题不污染新行 |

## Sources

版本固定源码优先于移动文档；Issue是公开问题/设计讨论的证据，不代表修复已经发布。核查日期：2026-10-23。

1. [Codex 0.163.0固定版本](https://github.com/openai/codex/tree/83086188ae0614bd882818ff1aa23f3194962012)：本机CLI对应版本；[ClientInfo与初始化协议](https://github.com/openai/codex/tree/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/app-server-protocol)，本机已生成ClientInfo仅有name/title/version、ThreadLoadedListResponse仅ID列表与分页，没有TUI PID/TTY→当前显示thread映射。
2. [共享daemon归属问题#48500](https://github.com/openai/codex/issues/48500)：维护者解释hooks运行在server，不掌握客户端当前显示；多个终端工具复现环境错归属。
3. [当前显示thread信号请求#48880](https://github.com/openai/codex/issues/48880)：要求无prompt的X→Y→X及多客户端正确归属，状态为duplicate关闭，未链接修复PR，不能视为已实现。
4. [hook客户端环境提案#44902](https://github.com/openai/codex/issues/44902)：本次读取仍开放；[请求元数据提案#44774](https://github.com/openai/codex/issues/44774)关闭是因为采用受限部署，并非提供了通用client→thread协议。
5. [0.163 slash_command.rs](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/slash_command.rs)：Title命令用于配置终端标题；[event_dispatch.rs L3297-L3324](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/app/event_dispatch.rs#L3297-L3324)、[status_controls.rs L168-L179](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/chatwidget/status_controls.rs#L168-L179)：保存后立刻刷新当前TUI。
6. [0.163 status_surfaces.rs L966-L970与L1118-L1132](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/chatwidget/status_surfaces.rs#L966-L970)：thread-id截断；[0.164对应源码](https://github.com/openai/codex/blob/6aaac694803004a63c6f393d153c96d22521a6b9/codex-rs/tui/src/chatwidget/status_surfaces.rs#L963-L965)仍限制32字符。
7. [0.163 thread_routing.rs L194-L200](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/app/thread_routing.rs#L194-L200)：实际当前显示thread的权威方法；[session_flow.rs](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/chatwidget/session_flow.rs)、[session_lifecycle.rs](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/app/session_lifecycle.rs)：会话建立及切换的本地界面链。
8. [0.163 daemon_startup.rs L94-L129](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/daemon_startup.rs#L94-L129)：命令行配置覆盖可能排除daemon；[TUI no_daemon参数](https://github.com/openai/codex/blob/6aaac694803004a63c6f393d153c96d22521a6b9/codex-rs/tui/src/cli.rs#L87-L89)：显式单CLI降级，不需停止整个共享daemon。
9. [Codex App Server官方文档](https://developers.openai.com/codex/app-server)：thread/read、thread/turns/list为不resume/不subscribe的读取；loaded/list不提供终端对应关系；[Hooks官方文档](https://developers.openai.com/codex/hooks)：session_id语义与事件覆盖。
10. [Kiro标题转发问题#3862](https://github.com/aws/amazon-q-developer-cli/issues/3862)：公开WSL复现及绕过wrapper后恢复，不作为本机macOS已确证故障。
11. [0.163 terminal_program_status.rs](https://github.com/openai/codex/blob/83086188ae0614bd882818ff1aa23f3194962012/codex-rs/tui/src/terminal_program_status.rs)、[0.164版本](https://github.com/openai/codex/blob/6aaac694803004a63c6f393d153c96d22521a6b9/codex-rs/tui/src/terminal_program_status.rs)：OSC 7501/21337的输出、粗状态及版本差别。
12. [iTerm2 v3.7.1固定源码](https://github.com/gnachman/iTerm2/tree/47a7e066a75d4f7e3f577715b1cc098b98fac70e)、[v3.7.1状态函数](https://github.com/gnachman/iTerm2/blob/47a7e066a75d4f7e3f577715b1cc098b98fac70e/sources/Language/BuiltInFunctions/SetStatusBuiltInFunction.swift)：只有set_status及background task读取；[master的状态函数](https://github.com/gnachman/iTerm2/blob/7f4ff739721f95d0b93003d8701c4523a7edf261/sources/Language/BuiltInFunctions/SetStatusBuiltInFunction.swift)、[ProgramStatus](https://github.com/gnachman/iTerm2/blob/7f4ff739721f95d0b93003d8701c4523a7edf261/sources/VT100/iTermProgramStatus.swift)：新API能力需与本机区分。
13. [iTerm2变量文档](https://iterm2.com/documentation-variables.html)、[转义协议](https://iterm2.com/documentation-escape-codes.html)：terminalWindowName来自OSC 0/2；SetUserVar是单独的user变量，不必改变可见标题，但需要TUI真正发送并被外层转发。

## Limitations

本轮为源码、官方协议与公开Issue调研，不是实现或真实行为验收。未修改配置、未注入控制序列、未运行任何自动化测试、未重启或启动App/Bridge/Agent；没有证明本机Kiro能转发新标题，也没有证明未发布的TUI身份快照已可用。可见标题兼容路径与长期上游适配均需后续授权及实测。计划保留Pending，不勾选实现Target，不记录不存在的Review Passed或完成证据。
