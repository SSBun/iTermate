# 工作区上下文

## Project Core

### Purpose
- iTermate 是原生 macOS 辅助应用：跟随当前前台 iTerm2 主窗口显示浮动面板，汇总并操作 Window、Tab、Session，以及展示命令或 Agent 的活动状态。

### Global Vocabulary
- Window、Tab、Session 对应 iTerm2 的原生层级；Project Path 是按 Session 当前目录进行的跨层级分组。
- Bridge 指随 App 分发并由其管理的 Python helper；Integration 指 Pi 等 Agent 主动报告生命周期的适配资源；Codex 状态由 App 被动观察原生进程与 Session 数据。

### System Map
- `iTermate/` 包含 SwiftUI/AppKit 应用壳、浮动面板、设置、通知和 Bridge 客户端；`iTermateBridge/iTermateBridge.py` 通过 iTerm2 API采集快照，并经 Unix Socket 与 App 通信。
- `integrations/` 包含 Agent 生命周期适配；`project.yml` 是 XcodeGen 工程配置的规范来源，`iTermateTests/` 覆盖主要纯逻辑与集成边界。

### Global Invariants
- Session 状态必须来自 Bridge 或 Integration 的真实观察路径，不得根据 Session 名称猜测。
- Window、Tab、Session 的语义与操作由 Bridge 提供；面板几何在 Swift 侧跟随前台 iTerm2 可见主窗口。
- Target、资源或构建设置的持久变更以 `project.yml` 为准，并由它重新生成 Xcode 工程。

## CTX-session-list-ui — Session 列表分组与交互
- Scope: 浮动面板中的 Window 与 Project Path 分组、Tab 标题栏、Session 行、状态动画，以及菜单栏 Agent 摘要、收藏项目入口和相关交互。
- Paths: `iTermate/iTermateApp.swift`, `iTermate/ItermBridge.swift`, `iTermate/SessionNotifications.swift`, `iTermate/SettingsViews.swift`, `iTermateBridge/iTermateBridge.py`
- Keywords: Session list, Window, Project Path, Tab header, status animation, status menu, running agents, completion statistics, daily buckets, favorite project, style, color, subgroup, collapse, focus, close
- Authority: `iTermate/iTermateApp.swift`, `iTermate/ItermBridge.swift`, `iTermate/SessionNotifications.swift`, `iTermate/SettingsViews.swift`, `iTermateBridge/iTermateBridge.py`
- Recheck: 分组模式、Tab 标题、状态动画设置或渲染、菜单栏统计与收藏项目动作、终端快照层级、数据源或 Session 操作发生变化时复查。

### Workflows
- Session 左侧环境标记独立于右侧生命周期：Shell 为8pt圆形、Pi为8pt三角形、Codex为7pt方形，均居中于14pt槽位；像素Canvas静态显示，未聚焦为语义灰色空心、聚焦为用户强调色实心，保留原有行背景及右侧状态动画。`SessionAgentKind` 来自集成明确的 `agentKind`，由 iTerm2 Bridge 传递，Pi 主动恢复也标记 Pi；不根据标题推断。旧通用 Agent 无身份时，界面默认按Pi展示三角形与Pi名称，不显示菱形；原始unknown来源记录仍保留，默认展示不影响状态协议、Codex或Shell判定。身份不因聚焦、完成或工作租约过期而丢失，在 Agent 退出或终端身份复用时清除；右侧状态及统计仍只依赖既有生命周期。权威为 `iTermate/iTermateApp.swift`、`iTermate/ItermBridge.swift`、`iTermateBridge/iTermateBridge.py` 及两类集成；身份协议、清理路径或图标渲染变化时复查。
- 面板可按 Window 平铺其所有 Session，或按 Session 的精确当前目录跨 Window/Tab 分组；Window 或文件夹路径只显示在 section header，Session 行显示标题与状态图标；由 Agent lifecycle 明确确认的 idle 显示低透明度静止 Agent 像素图标，不纳入状态动画设置，finished 在用户重新激活后才转为 idle，普通命令无 idle 图标；Pi 的 `awaitingInput` 默认使用间歇左右摇晃的像素问号，不随聚焦清除、不进入运行/完成耗时展示，且不触发成功通知或完成计数；Status Animation Settings 按 Agent 与普通 Shell 的 Running、Success、Failed、Shell Finished 及 Agent Waiting for Reply 分成八项，独立持久化样式和颜色并显示预览；Waiting for Reply 默认 Question Mark，问号与设置预览共用 TimelineView，每四秒短暂做 ±1pt 水平位移，减少动态效果时停在中间；等待状态固定使用 Question Mark，历史保存的 Alien、Robot、Classic 样式通过可用样式校验回退为问号；默认颜色跟随项目强调色，支持恢复默认颜色；其余七项继续使用原有三种动画样式；Classic 分别使用 `^_`、`^_^`、`x_x` 表达运行、完成与失败，全部偏好由 `AppSettings` 持久化且不改变状态判定；General Settings 可显示/隐藏运行及完成时间，并在按分钟更新的 Compact 与按秒更新的 Detailed 格式间切换。Window 样式默认为每个 Tab 显示弱化小节标题并缩进其 Session，可在 General Settings 中关闭；Project Path 样式同样受该开关控制，启用后每个 Tab 都显示 Tab 子分组标题并缩进，包括在对应 Project Path 组内仅贡献一个 Session 的 Tab；子分组标题显示 "Tab N"（N 为该 Tab 在其 Window 中的位置），不重复动态标题中的路径；焦点只通过选中 Session 行的强调色背景展示，不再为整个 Project Path 分组着色，旧 Focused Section Opacity 设置已移除；section header 使用系统半粗字体并按项目自定义颜色或次要色显示，带明确的 sessions 数量标签（内容宽度不足 240pt 时隐藏可见计数但保留辅助功能描述）；Agent 任务标题使用系统字体，普通终端保留面板字体偏好；General Settings 可选择将没有确认 Agent 身份的普通命令 Session 集中到 Agent 分组之后、Archive 之前的可折叠 Commands 分区，关闭时沿用现有混合分组；Commands 行固定显示当前工作目录的末级名称，并在悬停标题时显示完整工作目录；只有无 Agent 身份、标题前缀与当前目录末级名称一致且带已识别 shell 后缀的默认标题才简写，Project Path 模式显示 Terminal，Window 模式显示目录名，其他自定义标题与 Agent 标题保持原样；完整标题通过悬停提示保留；状态动画紧邻标题，内容宽度不足 300pt 时隐藏时间文字但保留状态图标及其辅助功能标签；同一 Tab 的 Session 在组内聚类相邻；渲染层也按首次出现的 Tab ID 建立独立 VStack 区块，再在区块内列出该 Tab 的 Session，Tab 标题开关不影响区块边界；同区块有多个 Session 时，使用各环境图标的实际布局锚点，在相邻图标之间叠加 1pt 次要色 Canvas 竖线，适应混合行高和缩进，且不跨 Tab 或项目；单行或折叠后无连线，装饰层禁用命中测试并从辅助功能隐藏；普通命令与 Agent 行分别使用 4pt、6pt 上下内边距，关闭按钮区域对应 28pt、32pt；Window/Tab/Project Path 标题保留分组留白，连接线使用更低透明度以弱化装饰。标题栏配置菜单按 Group By、Display、Sections 分区，各操作项使用语义图标且分组项保留原生选中标记；Window、Tab 和 Project Path 标题均可临时折叠，并支持全部展开/折叠；各类 section header 的原生上下文菜单可通过 `Close All Sessions` 请求非强制关闭该 Window、Tab 或精确 Project Path 当前包含的全部 Session。样式与 Tab 标题开关持久化，折叠状态仅保存在当前运行时；点击 Session 会由当前数据源选择父 Tab、聚焦 pane 并将 Window 置前；当前焦点由快照中的 Window、Tab 与 Session 选中关系共同生成，保证每份快照最多一个聚焦 Session；每行的独立关闭按钮默认隐藏；非激活面板以唯一的行与关闭按钮悬停 Session ID 配合 `.activeAlways` AppKit tracking area，仅在指针悬停当前行时显示对应按钮，悬停 `xmark` 本身时显示圆形背景反馈，离开按钮、行或面板时清理，并通过当前数据源请求原生非强制关闭。
- 菜单栏 `MenuBarExtra(.window)` 使用 Live-first 层级显示 iTerm2 的可确认 Agent Running 总数，以及退出状态为0的Agent完成次数；Pi/Codex优先使用稳定完成ID与时间去重，最近最多64条recentCompletions独立于当前running/idle/unknown显示状态，latestCompletion保留兼容，旧集成和普通Shell保留running→finished兜底；首次观察历史完成只建立基线，多轮结束按ID逐条去重，超过留存窗口或未读到的历史不保证补齐。数据源未就绪时Running显示未知而不是零。完成次数按本地自然日聚合并持久化，由同一份每日数据计算Total、当前自然月、当前本地日历周和Today；旧版当天计数首次读取时迁入对应日期；状态菜单以Today作为大号强调指标，并将Running数量作为次要标签；Settings的Statistics标签页以原生分组表单展示四项汇总。Favorite Projects复用按精确路径持久化的现有收藏，按标题排序为“左标题、右完整路径”的单行Cell；点击后由iTerm2 Bridge按Window、Tab、Session顺序读取当前动态路径，激活首个精确匹配Session，否则以该路径为初始目录在当前窗口新建Tab、无窗口时新建窗口；成功后关闭菜单，失败时保留菜单并显示错误。

- Commands 分区按工作目录末级名称进行不区分大小写的字母排序，同名目录再按完整路径排序；相同完整目录的普通命令 Session 跨 Tab 连续显示，目录内保留现有 Tab 区块，悬停整行显示完整路径。

## CTX-pi-session-archives — Pi 实时摘要、归档与恢复
- Scope: 实时Session任务摘要、Session行归档菜单、面板Archive折叠分区、活跃Pi身份发现、私有JSONL快照、归档列表和新终端恢复。
- Paths: `iTermate/PiSessionArchives.swift`, `iTermate/ItermBridge.swift`, `iTermate/iTermateApp.swift`, `iTermate/SettingsViews.swift`, `integrations/pi/iTermate-integration.ts`, `iTermateBridge/iTermateBridge.py`, `docs/pi-session-archives.md`
- Keywords: Pi, task summary, session title, archive, resume, session ID, JSONL, current leaf, private socket, parent PID
- Authority: `iTermate/PiSessionArchives.swift`, `integrations/pi/iTermate-integration.ts`, `iTermate/ItermBridge.swift`, `iTermateBridge/iTermateBridge.py`, `docs/pi-session-archives.md`
- Recheck: Pi SDK会话格式/生命周期接口、私有发现协议、归档目录、面板Archive布局/配色、终端关闭校验或CLI恢复参数变化时复查。

### Vocabulary
- 终端Session ID与Pi原生Session ID不是同一身份。Pi集成提供原生ID、文件、工作目录及进程信息；只接受iTerm2条目并按明确的终端ID唯一匹配，不按TTY、标题或目录猜测。

### Structure
- `PiSessionArchives`负责活跃实例发现、归档元数据读取、摘要与header校验，以及恢复工作副本；归档原生条目由目标Pi进程自己读取SessionManager并写入。私有Unix socket与发现凭据位于用户配置目录的pi-live，归档/恢复副本位于App支持目录。
- JSONL保留完整历史并追加不进入模型上下文的custom锚点，以固定当前分支；原始Pi文件不由App删除，恢复不直接写归档快照。归档不等于工作目录或外部资源备份。

### Workflows
- 实时Pi任务标题由集成在启动/重载/分支切换后的安全空闲时补生成，并在交互会话成功回复settled后后台直接调用固定回环Ollama的小模型更新，不依赖当前Pi模型；十六元素、标点和数字要求仅作提示词指导；生成及Swift显示要求非空、不含换行且不超过80个Unicode标量，首轮无效时用原对话和草稿调用同一本地模型再摘要一次，第二轮仍无效则失败，保留上一有效标题或终端标题，不机械清洗或截断；有效标题原样保留，仅使用当前分支有界的用户/助手可见文本，不传隐藏思考或原始工具输出；复用私有发现元数据的可选taskSummary，Swift按明确终端身份唯一匹配后优先显示，缺失、过期或不合法时回退终端标题，悬停保留原始标题。摘要不进入状态协议、对话或归档；只读状态查询不调用模型，失败保留旧摘要；AI页持久化的autoFillMissingTitles控制缺失标题补全，关闭不影响已有标题和手动刷新。App发现支持supportsTitleBackfill的空闲实例缺少标题时，可发送独立认证ensureTitle动作；端点仅在缺失时复用自动生成预算，已有标题直接返回；新一轮取消在途请求，Session/分支切换或退出清除，迟到结果须通过请求、会话与leaf核验。缓存仅覆盖当前集成运行期；自动生成对连续未变化的可见对话最多尝试两次，失败后延迟重试且显示脱敏原因，成功内容去重；生命周期取消清理定时器与在途请求，重载和分支切换重置缓存及预算；右键Refresh Session Title仍可手动生成。手动刷新使用声明supportsTitleRefresh/canRefreshTitle的私有认证refreshTitle动作，仅空闲会话可用；绕过自动去重，但保留请求取消与身份/leaf复核，同一会话刷新串行、不锁输入，失败保留标题并反馈；App按端点实例跟踪在途请求，响应后重读发现元数据核对结果。App与集成源码改变仍需用户自行运行新版App并安装/reload集成。
- 右键归档直接执行、不显示确认弹窗，仍要求Pi空闲、没有草稿/排队消息/交互弹窗，且子代理活动可确认安全；先经当前Pi的modelRegistry使用当前模型生成短摘要（无工具、无新CLI，60秒截止），输入是活动分支投影的可见对话与压缩摘要，不含隐藏思考或原始工具输出；生成失败不归档/退出。生成后重新核验身份、分支与空闲条件，写入、校验并发布含summary的归档后请求Pi正常退出。App要求活跃实例声明supportsSummary，旧集成需重载；旧归档summary可缺省并继续恢复。App复核记录、观察目标进程退出，再检查原Shell身份后仅关闭目标分屏，不关闭同Tab其他分屏；iTerm2对退出后的前台状态有短暂刷新等待，发现新存活进程仍拒绝关闭。无法确认安全时保留分屏和已保存的归档。
- 主面板Archive分区默认折叠，使用普通语义颜色（标题为secondary、恢复按钮沿用默认前景），无独立高亮背景；归档行间距不随实时Agent行留白变化，与实时Session共用滚动区域；展开时刷新归档列表，参与现有Expand All/Collapse All，折叠状态仅属于面板生命周期。即使实时数据源连接未就绪或没有当前Session，分区也可显示；展开不触发恢复或删除。
- 主面板 Archive 行提供右键删除菜单，点击直接执行、不显示确认弹窗，由 `PiSessionArchives` 校验 UUID、目录非符号链接及元数据一致性，并将所选归档目录移至系统废纸篓；与归档/恢复共用忙碌状态，结束后刷新列表，失败沿用面板错误提示，不操作原始 Pi 文件、工作目录或恢复副本。
- 面板Archive归档行和Archives设置页共用恢复入口，只有明确点击Resume按钮才恢复，名称/路径/行空白不触发恢复；悬停显示持久化summary，旧归档无摘要时显示缺省提示。在原工作目录的新iTerm2终端使用独立可写副本与明确的`--session-dir`定位原Session ID；路径形态的特殊ID使用明确文件路径。恢复完成由新Pi报告打开了预期副本来确认，单纯创建窗口不算恢复成功。

## CTX-terminal-backends — iTerm2 数据源
- Scope: iTerm2前台识别、面板窗口跟随、Window/Tab/Session快照与操作路由、Agent摘要与状态能力边界。
- Paths: `iTermate/iTermateApp.swift`, `iTermate/SettingsViews.swift`, `iTermate/ItermBridge.swift`, `iTermate/VenomDebugMonitor.swift`, `iTermate/CodexSessionMonitor.swift`, `iTermate/CodexAppServerClient.swift`, `iTermate/AgentIntegrations.swift`, `iTermateBridge/iTermateBridge.py`, `integrations/`, `project.yml`
- Keywords: iTerm2, Bridge, TerminalApp, frontmost, panel setting, snapshot, tty, telemetry, shell hook, focus, close, open project, favorite project, agent summary, completion count, session status, venom-cli, debug monitoring, radar
- Authority: `iTermate/iTermateApp.swift`, `iTermate/SettingsViews.swift`, `iTermate/FinishedSessionShortcut.swift`, `iTermate/ItermBridge.swift`, `iTermate/VenomDebugMonitor.swift`, `iTermate/CodexSessionMonitor.swift`, `iTermate/CodexAppServerClient.swift`, `iTermate/AgentIntegrations.swift`, `iTermateBridge/iTermateBridge.py`, `integrations/`, `project.yml`
- Recheck: iTerm2身份识别、面板启用偏好、快照、Integration安装、前台窗口选择、Agent统计、venom-cli调试子进程结构或Bridge操作路由发生变化时复查。

### Purpose and Boundaries
- 已识别Agent但status为nil时，Session行显示灰色像素呼吸感叹号并标注状态不可用，减少动态效果时静止；普通Shell的nil状态不显示该提示。状态数据保持unknown，不影响等待/完成含义或通知计数；显式行ID区分unknown与idle。权威为`iTermate/iTermateApp.swift`。
- `PanelFollower`只在iTerm2是系统前台应用、存在可见layer-0窗口且面板开关启用时显示；开关默认启用并持久化，关闭仅隐藏面板，不阻断状态采集。按最大窗口排除模态框，无需Accessibility权限。
- iTermate仅支持iTerm2，由Python Bridge提供层级、操作、普通命令和Pi状态；Codex使用原生被动监控。没有独立TTY状态listener或Shell命令hook安装入口，不根据标题、目录或进程名称猜测状态。

### Workflows
- venom-cli 调试雷达由 `iTermate/VenomDebugMonitor.swift` 读取 macOS 原生进程信息确认：iTerm2 Bridge 从动态 `tty` 变量提供真实设备路径；唯一 TTY 的普通 running 命令与该终端前台进程树中仍存活的前台 venom-cli debug build 必须同时成立；通过真实父子关系追踪终端包装器的嵌套 PTY，不按终端名称或相邻 TTY 编号猜测。识别从 debug build 启动即成立，覆盖构建、安装、重建及日志采集阶段，不再等待直接日志子进程出现。共享 Store 每两秒重新观察，仅细化状态图标，不更改命令生命周期、Agent 优先级或完成统计；非 debug build、未知权限或 TTY 不显示雷达。Canvas 绘制青绿色 7×7 雷达，扫描点沿轮廓循环，减少动态效果时静止；实际面板生效仍需用户运行新构建。
- Pi子代理活动通过进程内subagents:rpc:v1:request的status方法读取当前会话Fleet v1 totalActive，区分已知零、已知活动和未知；subagent:child-status只触发即时刷新，不能替代快照，另有约两秒轮询恢复。子代理启动使缓存零失效，过期/失败不推出完成。push与readonly status共用状态派生，父Agent及可确认的子代理活动显示running，明确待回复优先awaitingInput；缺少证据则unknown。布尔hasRunningSubagents仅来自新鲜快照，不解析终端文字或子代理历史。running/awaitingInput中的子代理标记继续使用原像素Canvas分支动画与减少动态效果处理。源码改变不等于已安装新集成，需Agents更新并在Pi中reload。
- Pi待回复仅在交互TUI上报：confirm/select/input/editor事件为明确等待，custom UI不默认视为提问；正常agent_settled后台调用所选本地Ollama模型，不等待模型才返回hook，也不再执行旧Laya/Vela或文本启发式。question为awaitingInput，明确normal且无未决活动才完成；推理中、不可用、超时或无效结果为unknown，不能计为成功。aborted为interrupted，不新增完成证据；明确error保留失败结果。整条分类链十秒截止，新turn、分支/Session切换和退出取消；已确认等待由有限租约续报，不因聚焦清除，心跳不调用模型。权威为integrations/pi/iTermate-integration.ts及Python Bridge。
- App启动时仅在iTerm2已运行时启动其Bridge client；否则在iTerm2首次成为前台终端时启动。
- Pi只有在`TERM_PROGRAM=iTerm.app`且有明确iTerm Session ID时才启用状态报告、发现端点及自动标题生成；其他终端继承的Session ID不可信。普通Shell命令由iTerm2 Bridge原生观察，不需安装独立hook。
- Codex由App每两秒确认可见终端前台进程树中的原生CLI。Bridge读取原始terminalWindowName传递官方当前thread UUID或29字符前缀；只有唯一根metadata匹配才成立，且约束旧FD，信号失效不复活旧启动关联。未启用原生thread标题时兼容唯一可写FD、明确resume UUID及同cwd/启动±30秒匹配，做跨进程冲突检测；后两者无法可靠跟随同进程切换。未映射按1/2/4/8轮持续重试，原生信号改变立即重查。首次1 MiB尾部、后续每轮最多8 MiB增量解析，未追上时unknown；状态由完整生命周期事件决定，不由文件增长决定。非FD自动关联接入现有daemon只读thread/read与最近turns，官方同用户socket符号链接可用；请求失败保留rollout证据，迟到结果不得覆盖新生命周期。手动绑定仅为应急覆盖，不是自动路径前提。权威为iTermate/CodexSessionMonitor.swift、iTermate/CodexAppServerClient.swift、iTermate/ItermBridge.swift、iTermateBridge/iTermateBridge.py及docs/codex-monitoring.md。
- Codex完成查看确认保存在Swift Store展示层，不写回rollout或Bridge生命周期；前台Window/Tab/Session焦点变化、切回终端和面板激活成功后可确认。确认绑定TTY、终端Session ID、进程身份、Codex thread ID及完成ID/时间；相同事件保持idle，新一轮或thread变化不能复用旧确认。latestCompletion与显示状态分离，供完成通知/统计去重；中止不产生成功完成。权威为iTermate/ItermBridge.swift、iTermate/SessionNotifications.swift、iTermateTests/ItermBridgeTests.swift与docs/codex-monitoring.md。
- 标题栏刷新按钮只重启iTerm2 Bridge并重建状态，不重启App或用户的终端Session。
- General 中的全局快捷键由 `FinishedSessionShortcut` 使用系统热键 API 注册，配置由 `AppSettings` 持久化；动作固定路由 iTerm2 Bridge，不依赖当前前台终端或面板分组顺序。App 将与面板同源、已通过 TTY/Session 身份校验的 Codex 状态作为 `codexStatuses` 随单次导航请求传入，包括表示未知状态的 null；Bridge 仅在当前真实 Session 中使用该覆盖，不将其写入生命周期或清理底层 Shell 状态。Bridge 以真实 Session ID 记录本轮已访问项，每次按实时状态过滤候选，只选 `activityKind=agent`；本轮先访问尚未访问的 finished（未查看的已完成结果，包括失败），再访问尚未访问的 awaitingInput（问号）与 idle（后两者同级），同级按实际 Window/Tab/Session 顺序从当前项之后选择；本轮全部候选走完才清空访问记录并重新循环。保留现有完成确认路径；已完成转 idle 后按普通空闲候选参与后续轮次，不在同轮重复抢占，已关闭 Session 从记录移除。running、普通命令、当前项、未知及独立模型推测均不参与。待回复及空闲目标不执行完成状态清理，聚焦不会清除问号。
- 状态菜单打开时刷新iTerm2数据源；`ItermStore`只统计可确认的Agent Running，并只累计退出状态为0的Agent完成。收藏项目操作固定路由到 iTerm2 Bridge；Bridge 在同一动作内用动态 `path` 判断首个精确匹配 Session，只有确认不存在时才通过 `LocalWriteOnlyProfile` 的自定义初始目录创建 Tab 或 Window，并以 `actionResult` 驱动菜单成功关闭或失败提示。

## CTX-local-decision-models — 本地小模型与旧决策关闭门
- Scope: Local LLM设置、旧Decision服务暂停、Pi问题类型判断、Pi/Codex实时任务标题及诊断日志。
- Paths: `iTermate/LocalModelService.swift`, `iTermate/CodexTitleDiagnostics.swift`, `iTermate/CodexAppServerClient.swift`, `iTermate/ItermBridge.swift`, `iTermate/PiSessionArchives.swift`, `integrations/laya/`, `integrations/pi/iTermate-integration.ts`, `docs/local-model-api.md`, `docs/codex-monitoring.md`
- Keywords: Laya, Vela, Ollama, Local LLM, decision model, question, task title, Codex, diagnostics, keep_alive, legacyDecisionsEnabled
- Authority: `iTermate/LocalModelService.swift`, `iTermate/CodexTitleDiagnostics.swift`, `iTermate/CodexAppServerClient.swift`, `iTermate/ItermBridge.swift`, `iTermate/PiSessionArchives.swift`, `integrations/laya/iTermate-laya.py`, `integrations/pi/iTermate-integration.ts`
- Recheck: 旧体系关闭门、模型身份、调用路径、标题格式、问句定义、诊断日志边界或热驻留策略变化时复查。

### Structure
- App使用`LocalLLMService`和`LocalLLMSettingsView`提供本地模型选择、固定回环Ollama库存检查和预热；支持模型标签及身份规则以Swift的`LocalLLMModel`与Pi集成为准，不缓存实际库存或选择值到Context。App启动与手动检查仅在回环连接被拒绝时查找已安装运行时并执行`ollama serve`，固定监听回环地址，异步有界等待后检查并预热；已有服务复用，取消请求和退出App不停止共享Ollama。当前分发不内置Ollama二进制，不自动安装或下载模型，不启动Python模型worker、不展示公共API地址或令牌。
- App原子保存独立的`LocalLLM/configuration.json`，包含模型标签和UUID配置revision；Pi每次推理重新读取。仅文件缺失时使用默认2B，错误或不可读配置不回退。常规模型/补全偏好写入先读取最新文件，拒绝覆盖无效配置；AI页可显式确认修复，先保存0600原始副本再重置为2B且关闭补全，不下载或启动模型；不可读、备份失败或修复期间文件变化时不替换。请求前后核对配置身份及所选库存digest，切换时的迟到结果丢弃。标题保留旧值直到后续生成或手动刷新，不因换模型立即清空。
- `LocalModelService`、旧设置视图、Python Decision服务和Pi旧调用实现仍保留，但由编译内关闭门阻止当前入口执行；旧偏好不影响新路径，缓存不删除。恢复旧体系需要明确修改源码，不能通过旧设置开启。
- Pi问题判断与实时标题使用同一所选模型直接访问本机Ollama；2B保留固定revision校验，4B按已安装的同名标签绑定每次请求的合法digest。不用代理或重定向，每次推理请求十分钟空闲驻留，不周期续租。App启动和手动检查会按需启动已安装的Ollama后预热所选模型；驻留过期与内存回收由Ollama负责。

### Decision and Verification Boundaries
- 问题判断仅由Pi agent_settled触发后台分析最后一条完整助手可见回复；回复中面向当前用户的回答、确认、选择、授权或必要信息请求才是question；隐式确认门也须将助手下一步与用户回复相连。单纯交付报告与操作说明是normal，等待QA/CI/reviewer、MR未合并或未测试只属状态事实，不以问号或任务未完成代替判定（权威：`integrations/pi/iTermate-integration.ts`的`classifyReplyWithModel`提示词）。严格二分类JSON之外保留unknown，进行中/失败不推导finished或成功计数；明确运行、UI等待和aborted仍由生命周期决定。整条库存→生成→库存复核共用十秒总预算并支持turn/导航/退出取消。系统prompt与全文UTF-8字节+1024保守余量须≤16384；不再使用3000字符限制，超预算保持unknown而不截断。心跳与只读状态查询不再次推理，不回退旧模型/规则/云端，不扫描屏幕。
- 实时标题不使用当前Pi模型；Pi集成与原生Codex的生成提示词分别位于TS的summarizeTask和Swift的LocalLLMService，两处保持核心目标概括规则与对照示例：提炼最近用户的单一目标，不摘录Markdown任务目标或助手进度，简短确认沿用相关目标，明确目标切换后忽略旧任务。两条链路的最终标题均要求非空、不含任何换行且最多80个Unicode标量；首轮为空、多行或过长时最多再调用一次本地模型，以原对话和草稿重新概括，第二轮仍无效则失败，不发布草稿或机械改写。Codex每次最多生成1024 tokens，Pi保留64输出token和60秒总截止；两条链路首轮length响应都仅作提炼草稿，最终必须完整stop。两轮绑定同一配置和库存身份并检查取消，不改变外层两次尝试预算。Swift共享校验也用于Pi显示与Codex缓存恢复；空格、标点、数字仍不作额外过滤。通信、响应有效性、身份或取消失败仍保留旧有效标题。仅归档时的多句摘要继续使用原有Pi模型路径。
- Pi实时标题生成失败会把脱敏的失败类别写入`~/Library/Logs/iTermate`中由进程唯一拥有、单文件1 MiB轮转的JSONL日志对；不写入对话、模型输出、路径或凭据，写入失败不改变标题回退。写入时清理已退出PID的旧日志对，About设置页提供打开该目录的入口。
- 原生Codex标题由App的LocalLLMService生成；标题与摘录哈希绑定TTY、终端Session ID、PID、启动时间和thread ID持久化，不保存对话原文。原生thread信号改变即取消旧请求和缓存写入；恢复不受缺失补全开关影响，补全要求已关联thread及核实的可见消息，已有标题只在finished更新。自动关联及应急绑定都可使用最终thread/read的path，经本用户普通文件、inode、根metadata及完整UUID核验后复用增量读取器；也可复用相同thread的rollout摘录，不用daemon预览生成标题。共享daemon无CLI文件FD时可通过原生thread标题或兼容启动匹配恢复输入；配置原生信号是准确跟随切换的边界。CodexTitleDiagnostics只记录脱敏失败、取消和过期丢弃；日志轮转与隐私边界不变。权威为iTermate/ItermBridge.swift、iTermate/CodexSessionMonitor.swift、iTermate/CodexAppServerClient.swift及docs/codex-monitoring.md。
- 源码和构建通过不代表新App或Pi集成已运行；需用户自行运行App并安装或reload集成，旧进程不会因源码改动自动停用。

## CTX-pi-status-recovery — Pi 状态主动恢复
- Scope: Pi已存在但Agent状态缺失时的认证查询、iTerm2恢复、乱序防护和旧集成能力边界。
- Paths: `integrations/pi/iTermate-integration.ts`, `iTermate/PiSessionArchives.swift`, `iTermate/ItermBridge.swift`, `iTermate/SessionNotifications.swift`, `iTermateBridge/iTermateBridge.py`
- Keywords: Pi, status, recovery, reconnect, heartbeat, unknown, idle, finished, readonly, supportsStatus
- Authority: `integrations/pi/iTermate-integration.ts`, `iTermate/PiSessionArchives.swift`, `iTermate/ItermBridge.swift`, `iTermate/SessionNotifications.swift`, `iTermateBridge/iTermateBridge.py`
- Recheck: 状态协议、Pi生命周期、私有发现身份、补查调度、连接代际、接收端序列或完成追踪变化时复查。

### Workflows
- Pi私有端点以supportsStatus声明能力；status验证token与原生Session ID，返回实例身份、状态、来源ID/单调序列、子代理标记和可选完成证据；与主动推送共用状态派生，未知分类/子代理不能误报finished。不发布状态、不调用模型、不归档或推进Pi；缓存观测可更新，但不使用canArchive推断空闲。
- Store在既有两秒定时器中扫描缺失Agent状态的会话，最多4个在途请求，每次3秒截止；轮转位置只在实际预留请求后前移，满额轮次保持游标，避免慢端点阻塞后续健康候选；仅用明确iTerm2 Session ID唯一匹配。查回后重新核验实例与当前快照，连接/唤醒/停止代际失效的结果丢弃；iTerm2接收端只填补缺失Agent状态，不覆盖新推送或聚焦后的idle。
- 查询快照与正常Pi推送共用单调序列；接收端拒绝迟到消息并保留detached保护，running/awaitingInput仍有租约。每轮正常/失败finished提供稳定completionId、Unix秒completedAt和exitStatus；recentCompletions保留当前集成运行期最近64条，快照复制数组并跨后续running/idle/unknown保留，latestCompletion继续兼容；通知/统计按ID逐条去重，不要求相邻running→finished采样。首次观察到的历史完成不补发；aborted不生成成功完成；Session启动/重载清空列表，断开期间超过留存上限而被挤出的事件仍无法补齐。Bridge按原生Session ID保存已查看完成ID，只抑制同一完成；异步激活/快捷键/项目入口在等待前捕获身份，迟到回调不确认新结果。旧集成缺少completionId时保留原兜底，缺少supportsStatus不查询，需Agents更新并reload生效。


## 工程与组件

- Session 状态快照以 `activityKind` 保存由真实观察路径确定的 `agent` 或 `command` 类型，UI 不根据 Session 名称猜测；非空状态使用 36×16pt 的 AppKit `NSView` 以 20 FPS 绘制 18×8 点阵动画，Agent 使用外星人、普通命令使用机器人，二者均带状态条并以动作和语义色区分运行、成功、失败及未知结果；点亮像素保持全不透明并通过语义色向白色混合表现亮度，未点亮像素透明，以保证模糊背景上的对比度；由 Agent lifecycle 明确确认的 idle 显示低透明度静止外星人图标，普通命令空闲与未知状态不显示；减少动态效果时所有图标停在静态关键帧。——权威来源：[`iTermateBridge.py`](../iTermateBridge/iTermateBridge.py)、[`ItermBridge.swift`](../iTermate/ItermBridge.swift) 与 [`iTermateApp.swift`](../iTermate/iTermateApp.swift)

- 面板标题栏的手动状态刷新按钮只重启 Bridge helper，不重启 App、iTerm 或任何 Session；Bridge 内存状态因此归零，普通 Shell running 由新 Bridge 的命令观察器初始同步恢复，真实工作的 Pi 由后续 heartbeat 恢复。该入口是睡眠后 stale 状态的手动兜底，不代表自动唤醒根因已解决。——权威来源：[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`ItermBridge.swift`](../iTermate/ItermBridge.swift) 与真实 PID/面板验证

- 本项目的本地构建并启动入口是在 workspace 根目录执行 `venom-cli -p "$PWD" build --run`；该入口使用 iTermate scheme 与 My Mac arm64 destination，构建 `project.xcworkspace` 后启动 DerivedData 中的 Debug App，可用于需要真实运行窗口和 Bridge 安装链路的验证。——权威来源：用户确认与成功的本地命令验证；venom-cli 行为或工程入口变化时复查

- 设置窗口由 SwiftUI `Settings` scene 承载，并使用标准顶部 `TabView` 在 General、Agents、Status Animation、Statistics、About 之间切换；不使用侧边栏、隐藏标题栏、强制 window toolbar 样式或手绘系统外观。各页继续使用 grouped `Form`、`Section` 与标准 SwiftUI 控件，窗口固定为 520×420pt 的旧式顶部标签布局；各设置 `Form` 使用标准 `.scrollIndicators(.hidden)` 隐藏滚动指示器，同时保留滚动行为。——权威来源：[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`SettingsViews.swift`](../iTermate/SettingsViews.swift) 与 [`AgentIntegrations.swift`](../iTermate/AgentIntegrations.swift)

- App 通过固定为 2.9.4 的 Sparkle SPM package 提供应用级 `SPUStandardUpdaterController`；正常启动时启用 updater，About 设置页只调用标准检查入口。`project.yml` 生成包含 HTTPS GitHub Pages feed URL 与 EdDSA 公钥的 Info.plist，私钥仅存于本机 Keychain 的 `SSBun.iTermate` account；更新资产由 `SSBun/iTermate` GitHub Releases 承载，基线 appcast 位于 `docs/appcast.xml`。——权威来源：[`project.yml`](../project.yml)、[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`SettingsViews.swift`](../iTermate/SettingsViews.swift) 与 [`appcast.xml`](../docs/appcast.xml)
- 菜单栏入口与浮动面板标题共用 `iTermate/Assets.xcassets/StatusIcon.imageset/status-icon.png` 中用户指定的 `terminal-icon.png` 高分辨率转换资源；源图保留 554×549px、可见边界约 475×412px，二者通过预设 `NSImage.size` 为 18pt 高的 `Image(nsImage:)` 控制运行时大小，再使用 template rendering 适配浅色/深色外观；资源说明记录在 [`THIRD-PARTY-NOTICES.md`](../THIRD-PARTY-NOTICES.md)。——权威来源：[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`StatusIcon.imageset`](../iTermate/Assets.xcassets/StatusIcon.imageset) 与 [`project.yml`](../project.yml)
- XcodeGen 的 [`project.yml`](../project.yml) 是 Xcode 工程配置的规范来源，生成的 [`iTermate.xcodeproj`](../iTermate.xcodeproj) 可直接构建；修改 target 或构建设置时应更新 YAML 后重新生成工程。——权威来源：[`project.yml`](../project.yml)
- 应用 shell 使用 SwiftUI `App`；`MenuBarExtra(.window)` 提供 iTerm2 的 Agent Running 与今日成功完成摘要、收藏项目快捷入口及 Settings/Quit，浮动面板左下角的齿轮入口和 `Settings` scene 提供 General、Agents、Status Animation、Statistics、About 设置页面；`AppDelegate` 启动共享 Store、浮动面板与完成通知控制器。面板和菜单栏 Settings 入口在 macOS 14+ 共用 `OpenSettingsButton`，先激活后台 App 再调用 SwiftUI `openSettings` 环境动作；macOS 13 保留 `showSettingsWindow:` fallback，不设置持续浮动层级。——权威来源：[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`ItermBridge.swift`](../iTermate/ItermBridge.swift)、[`SettingsViews.swift`](../iTermate/SettingsViews.swift)、[`SessionNotifications.swift`](../iTermate/SessionNotifications.swift) 与 [`iTermateBridge.py`](../iTermateBridge/iTermateBridge.py)
- 窗口几何与 iTerm 语义分层：`PanelFollower` 在 Swift 侧通过 Core Graphics 以 30Hz 跟随 active iTerm 的可见窗口；`ItermWindow.frontmost()` 要求 iTerm 为系统前台应用，并从可见 layer-0 候选中选择最大窗口，以排除 Close Tab 等模态提示框。iTerm 失去焦点或没有可见窗口时面板隐藏。Window/Tab/Session 层级及操作由 Python Bridge 提供，因此当前无需 Accessibility 权限；若需要多个主 iTerm 窗口的精确前台识别，应改用窗口 ID/Accessibility 并复查。——权威来源：[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`PanelLayoutTests.swift`](../iTermateTests/PanelLayoutTests.swift) 与 [`ItermBridge.swift`](../iTermate/ItermBridge.swift)
- Bridge 作为 App resource 安装到 iTerm2 AutoLaunch，使用文件锁保证单实例，并通过用户私有目录中的 Unix Socket 与 App 交换 JSON Lines；App 启动流程负责替换并重启 Bridge，因此 App↔Bridge 不做运行时协议版本校验。独立安装的 integration 可继续携带版本元数据，Bridge 只校验当前操作所需字段和值，不按版本号拒绝请求。——权威来源：[`iTermateBridge.py`](../iTermateBridge/iTermateBridge.py)、[`ItermBridge.swift`](../iTermate/ItermBridge.swift)、[`integrations`](../integrations) 与 [`project.yml`](../project.yml)
- Bridge同步全量Window/Tab/Session快照、命令状态与转换时间；标题和路径每两秒读取。Pi由生命周期集成主动上报并支持认证补查；Codex自动路径核验前台CLI实际打开的唯一可写根rollout FD，不按cwd/时间/argv resume猜测；首次1 MiB尾部、后续每轮最多8 MiB增量，生命周期事件驱动状态，不以文件增长判断running。手动Bind Codex Conversation固定thread后只读现有daemon状态，明确等待标记可显示awaitingInput；无socket、ID不匹配或未知状态保留unknown，不启动daemon。绑定随App运行期、终端及进程身份有效，/new或/resume后须重绑。——权威来源：`iTermateBridge/iTermateBridge.py`、`integrations/pi/iTermate-integration.ts`、`iTermate/CodexSessionMonitor.swift`、`iTermate/CodexAppServerClient.swift`与`iTermate/ItermBridge.swift`
- `SessionNotificationController` 对Pi/Codex优先消费recentCompletions中最近最多64条完成证据并按稳定ID去重，latestCompletion单条兼容，旧集成/普通Shell使用`running → finished`转换兜底；首次观察的历史完成只建基线，重复结果不通知，超过来源/留存窗口的历史不保证补齐；全局开关默认关闭，开启时请求 macOS 通知权限，后续启动也会重新确认当前 App bundle 的授权，并对普通 shell 与 agent 完成都发送带 Session 名称和结果的原生通知。初始 finished 快照与重复 finished 快照不会通知；通知携带 Session ID，用户点击后复用 Bridge 激活请求选择对应 Session 并将 iTerm 置前；系统明确拒绝授权会阻止通知投递并写入日志，但不会覆盖 `~/.iTermate/config.toml` 中持久化的用户开关；只有无技术错误且未获授权时，General Settings 才使用标准 SwiftUI Alert 引导至 macOS Notifications 设置页。通知运行验证必须使用代码签名 identifier 与 `CFBundleIdentifier` 一致的单一 App 实例；`CODE_SIGNING_ALLOWED=NO` 产物即使复用 bundle ID，也不代表系统设置中的已授权 App 身份。——权威来源：[`SessionNotifications.swift`](../iTermate/SessionNotifications.swift)、[`SettingsViews.swift`](../iTermate/SettingsViews.swift)、[`iTermateApp.swift`](../iTermate/iTermateApp.swift) 与 [`iTermateBridge.py`](../iTermateBridge/iTermateBridge.py)
- Agents Settings 列出 Claude Code、Codex、OpenCode、Cursor CLI、Kimi Code、Pi 与 omp；Pi 开关管理 `~/.pi/agent/extensions/iTermate-integration.ts`，Codex 显示 Automatic 且无需安装资源。App 启动时会从 `~/.codex/hooks.json` 删除带 `_iTermate` 标记的旧 entries，保留第三方 hooks，并清理旧包装器与标记；不再提供独立Shell状态资源或安装入口。Pi 更新后已有 Session 需 `/reload`，Codex 直接运行原始命令即可。——权威来源：[`AgentIntegrations.swift`](../iTermate/AgentIntegrations.swift)、[`CodexSessionMonitor.swift`](../iTermate/CodexSessionMonitor.swift)、[`Pi integration`](../integrations/pi/iTermate-integration.ts) 与 [`project.yml`](../project.yml)
- `AppSettings` 是面板宽度、字体、背景样式、Session 列表样式、Project Path section title 样式、Tab 标题、时间显示开关及格式、完成通知开关，以及按精确项目路径保存 Pin、Favorite 与颜色的共享权威状态：全部配置从用户 `~/.iTermate/config.toml` 读取并写回，不使用 `UserDefaults` 或旧配置迁移；初始化已有文件时只读取而不重写，每次修改会重新读取磁盘当前配置并只合并目标字段，避免多个 Debug App 或设置实例用陈旧内存值覆盖其他设置；面板字体默认系统 13pt，General Settings 通过标准 SwiftUI `Picker` 选择 `NSFontManager.availableFonts` 提供的任一本机已安装字形，并用数字 `TextField` 输入字号，保存其 PostScript 名称与字号，字体不可用时回退到同字号系统字体；Background Style 提供 System/Dark/Light 与 Blur/Opaque 的六种预设，默认 System Blur：Blur 使用系统 `.regularMaterial`，Opaque 使用语义窗口背景，Dark/Light 同步覆盖整个面板的文字、图标和控件配色，System 跟随 macOS 外观；Project Path section title 可选择完整路径或最后一级文件夹名，默认完整路径；项目文件夹标题的上下文菜单可切换并持久化 Pin、Favorite 与系统颜色选择器的自定义颜色，Pin 文件夹优先排序，Favorite 显示星标，颜色同时着色文件夹图标与标题，Unknown Path 不提供这些操作；面板仍可通过原生边缘拖拽在 180–600pt 之间调整，左右边缘通过带 `.activeAlways` 的 `NSTrackingArea` 显示水平调整光标；默认宽度为 260pt。面板高度始终匹配 iTerm，与 iTerm 间隔 8pt，优先放右侧，空间不足放左侧，再不足则覆盖在可见屏幕内。——权威来源：[`SettingsViews.swift`](../iTermate/SettingsViews.swift)、[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`PanelLayout.swift`](../iTermate/PanelLayout.swift) 与 [`PanelLayoutTests.swift`](../iTermateTests/PanelLayoutTests.swift)
