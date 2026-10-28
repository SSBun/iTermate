# Codex 原生状态监控

iTermate 被动观察直接运行的原始 `codex` 命令，不需要 `codexm`、启动包装器或 Codex hooks。自动关联当前对话后，从 rollout 和已经运行的 Codex daemon 读取状态及标题输入；无需逐次手动绑定，也不会为此启动 app-server。

## 使用

1. 启动 iTermate。
2. 在 iTerm2 中直接运行 `codex`。
3. iTermate 自动关联对应对话并显示状态；生命周期证据不足时保留 Codex 方框身份和中性活动图标，不推断正在工作或已经成功完成。

Settings → Agents 中 Codex 显示为 **Automatic**，展开 **Precise Conversation Binding** 可查看并复制所需原生标题配置，手动合并到已有 `[tui]` 节；此入口不写入配置，不覆盖无关设置。升级时，iTermate 会从 `~/.codex/hooks.json` 删除自己过去写入、带 `_iTermate` 标记的条目，并保留其他工具的 hooks；旧包装器和标记文件也会被移除。

## 自动匹配与对话切换

共享 daemon 可能持有全部 rollout，CLI 本身没有文件描述符。为准确跟随终端中当前显示的对话，Codex 支持在其配置的已有 `[tui]` 节中设置一次：

```toml
[tui]
terminal_title = ["app-name", "thread-id"]
```

这会改变 iTerm2 原生终端标题；iTermate 不自动修改用户的 Codex 配置。本次只面向未来新开的 Codex，不补救已打开的旧进程。不要用 `-c tui.terminal_title=…` 代替配置文件：固定版本中该覆盖可能触发 embedded 降级，不代表共享 daemon 方案。新启动 Codex 会通过标题输出当前 thread ID，`/new`、`/resume` 选定对话后更新。Bridge 周期读取原始 `terminalWindowName`，仅传递官方格式中的完整 UUID 或 29 字符前缀，不使用装饰过的 Session 名称推断身份。

每次自动查询先通过共享 daemon 的 `thread/loaded/list` 读取完整分页，以标题前缀唯一扩展完整 UUID，再读取并校验根会话来源、精确 ID 与状态。列表只表示已加载，不代表运行中。空白新会话即使尚无 rollout 文件也可建立身份。零匹配、多匹配、无效响应、重复游标、缺页、预算用尽或请求失败均保持未绑定；完整 UUID 也需经过 loaded 列表确认。不根据目录、启动时间、resume 启动参数或残留文件描述符猜测当前对话。

身份绑定覆盖终端 Session ID、TTY、进程 PID／启动时间和当前标题前缀。同一 thread 被多个终端认领时，自动关联保留未知。标题变化、终端复用或进程退出后丢弃旧异步结果；应用活跃结果前重新核对真实前台进程。每轮自动观察重新做完整列表查询，不缓存目录到 thread 的映射。查询失败时撤销自动绑定与 overlay，不复用旧 API 身份；文件仅在已验证 thread 下提供可选的生命周期和标题证据。官方 control socket 的同用户符号链接受支持，最终目标必须为同用户 Unix socket。

## 应急手动绑定

在 Codex 的 `/status` 中取得完整 thread UUID，然后右键点击对应 Session，选择 **Bind Codex Conversation…**，输入 ID 并点击 **Track**。这会把该终端固定跟踪到指定对话；同一对话不能同时绑定到另一个终端。执行 `/new` 或 `/resume` 切换对话后，需要重新绑定新的 ID。选择 **Use Automatic Codex Detection** 可解除绑定并恢复自动检测。

绑定仅在本次 App 运行期间保留，并同时绑定终端 Session、TTY、Codex PID 和进程启动时间；进程退出、终端身份变化或 App 停止会清除绑定。它不是对话切换命令，也不会恢复、启动、订阅或推进 Codex 对话。

自动关联或应急绑定后，App 只连接当前用户已经运行的 Codex daemon 的本地 control socket，使用 `thread/read` 和有界的最近 turn 列表 `thread/turns/list` 读取状态，并在返回前再次读取 thread 状态。`waitingOnApproval`、`waitingOnUserInput` 显示为 `awaitingInput`；其他已知活动状态、完成和中止按下表展示。每次请求有三秒总截止；loaded 列表每页最多 100 项、最多 32 页，触及预算仍有后续页则失败而不是采用部分结果；缺少 socket、返回的 thread ID 与请求不匹配、请求失败或未知状态时，不启动 daemon、不把其他对话套到该终端。请求不批准工具、不提交输入；响应中的预览等对话字段不用于标题、不保留或记录。最终 `thread/read` 若提供该 thread 的 rollout 路径，App 会在后台核对本用户所有的普通文件、设备号/inode、根会话 metadata 与精确 thread UUID，再复用有界增量读取器提取可见消息用于标题。路径缺失、格式变化或校验失败不影响已成功读取的状态。

## 数据来源与状态映射

iTermate 每两秒进行一次只读观察：

- 使用 macOS 进程 API 确认终端前台进程树中的原生 Codex CLI；
- 自动身份以原生标题与共享服务完整列表为准；可选 `rollout-*.jsonl` 仅在精确 thread ID 一致时提供证据，核对文件设备号、inode、首行根 Session 身份和 `source`；
- 首次映射从最多 1 MiB 的尾部建立状态，随后保存读取位置并解析新增的完整 JSONL 行；每轮最多读取 8 MiB，长追加尚未追上时保持中性显示，内部生命周期为空，后续轮询继续追赶。截断、文件替换和已读取边界变化会重建读取状态；生命周期事件的类型和时间戳才决定运行／完成，文件变大本身不是运行证据；
- 在初始尾部和后续增量中保留最近四条用户消息和四条助手消息，每条最多 2,000 个字符；根据下述补全／更新规则，交给 Settings 中已选择的本地 Ollama 模型生成短标题。开发者消息、思考和工具记录不会进入标题输入，数据不会发送到云端。

可选 rollout 查找按 1、2、4、8 个扫描周期退避，此后每八轮重试；标题变化立即重查。这不阻止每轮直接通过 daemon 识别没有文件的空白会话。已有文件仍需重新核验当前信号，不追逐最近修改的文件。

标题与 Pi 一样只覆盖 iTermate 面板中的 Session 显示名，不改写 iTerm2 的真实 Session 标题。生成结果会再次校验 Codex 进程、TTY、终端 Session ID 与 Codex thread ID；终端复用或 Session 切换后，旧请求不能写入新行。失败时最多自动重试一次，原终端标题保持不变。

Settings → **AI** → **Automatically Fill Missing Titles** 控制缺失标题的自动补全，默认开启，重启后保留设置。开启时，已识别并唯一映射到对话、且有可见内容的会话可以补全，包括运行中或生命周期状态未知的会话。标题补全不改变状态；已有有效标题仍只在任务完成后自动更新。关闭后仍保留已有有效标题、手动刷新及已有标题随新任务完成而更新的行为。共享配置损坏时，AI 页会提供 **Repair Saved Configuration…**；显式确认后先保存私有原始副本，再重置模型为 2B、关闭自动补全，不下载或启动模型。不可读文件或备份失败时不替换原文件。

成功生成的 Codex 标题保存到 App 的本地偏好，绑定 TTY、终端 Session ID、Codex PID、进程启动时间与 Codex thread ID；重开 App 时，即使正在运行、没有当前摘录或关闭自动补全，也会恢复同一会话的标题。缓存只保存标题和摘录摘要哈希，不保存对话原文；不同会话复用 TTY/PID，或同一进程切换 thread，均不会沿用缓存。自动关联或应急绑定时优先使用 daemon 为该 thread 返回且通过文件与身份校验的 rollout 摘录；也可复用自动获得且 thread ID 一致的摘录。没有经过校验的文件时保留原名称，不使用 daemon 的 preview 或 name 代替对话输入。旧版只在内存中的标题无法追溯恢复，开启补全后会在满足条件时重新生成。

Codex 标题每次模型调用最多生成 1,024 tokens，上下文为 16,384 tokens。最终标题必须非空、不含任何换行且最多 80 个 Unicode 标量；空格、数字及标点不另行强过滤。首轮为空、过长、多行或达到 token 上限时，最多再调用一次同一本地模型，根据原对话和草稿重新概括，不直接发布草稿或机械截断。第二轮必须正常结束并再次通过相同校验，否则保留上一有效标题或原终端标题。缓存恢复也使用相同校验，不恢复旧的多行或过长结果。

两轮始终绑定同一模型配置与库存身份，保留取消、HTTP/响应有效性和原有会话身份检查；第二轮失败仍保留原标题并记录诊断。每个自动尝试至多两次模型调用，外层最多自动重试一次，每次 HTTP 调用保留既有超时。Pi 集成采用相同的短单行校验与最多一次再摘要；两条链路均保留现有外层重试预算。

已识别的原生 Codex Session 始终可以从右键菜单选择 **Refresh Session Title**，包括 Codex 正在运行时。手动刷新会替换同一 Session 的旧标题请求，并在对话或 Session 身份发生变化时丢弃过期结果；普通 Shell Session 不提供该操作。

| Codex 生命周期事件 | iTermate 状态 |
| --- | --- |
| `task_started` | running |
| `task_complete` | finished；激活对应会话查看后为 idle |
| `turn_aborted` | interrupted |
| rollout 增长但没有新的已识别生命周期事件 | 保留已确认状态；没有时保留内部空值并中性显示 |
| 自动关联或应急绑定的 daemon `waitingOnApproval` / `waitingOnUserInput` | awaitingInput |
| 增量读取未追上文件末尾、映射失败且无可确认状态 | 生命周期为空，中性显示，不改变 Codex 身份 |
| daemon 自动身份查询失败 | 撤销自动绑定与 overlay，生命周期为空；应急手动绑定仍只使用其明确指定的身份 |
| 尚无可确认的生命周期事件 | 显示 Codex 身份与中性活动图标，不猜测状态 |
| running 中的 Codex 进程消失 | interrupted |
| 其他状态下 Codex 进程退出 | 不再标记为 Codex |

完成标记只在查看对应会话后清除：点击 iTermate 的会话行并成功激活，或在前台终端中切换到该窗口、Tab、分屏会话时，显示转为 `idle`。从其他应用切回终端也会确认当前会话；仅后台轮询或在同一会话等待回复结束不会自动清除刚出现的完成标记。

查看确认绑定终端 Session ID、TTY、Codex 进程身份、Codex thread ID 与本次完成身份／时间。同一完成事件再次被轮询到不会恢复完成标记；下一轮完成仍会显示 `finished`。运行、等待回复、中断与未知状态不会因查看而清除。该变化只影响 iTermate 展示，不改写 Codex rollout。

完成通知和成功计数优先使用稳定的完成身份与完成时间去重，而不是要求刚好观察到相邻两张 `running → finished` 快照。已观察到的最近最多 64 条完成证据通过 `recentCompletions` 传递，`latestCompletion` 保留单条兼容；它们与当前 running、idle 或 unknown 状态分离，可覆盖采样之间连续完成多轮后又开始下一轮的情况。失败有独立结果，中止不生成成功完成。自动 rollout 只有确认 `task_complete.error` 或已核实新版完成格式时才区分失败／成功；旧版或格式不明仍显示 finished，结果为未知，不计入成功次数。App 首次观察的历史完成不会补发通知或补计，普通 Shell 和旧集成仍使用状态转换兜底。这是有界观察记录：首次尾部之前的历史、尚未追上的增量、daemon 返回窗口之外及超过 64 条留存后被挤出的事件均不保证补齐，不是完整任务历史账本。

## 标题诊断日志

Codex 标题自动生成、手动刷新失败以及手动刷新缺少可用会话时，App 将脱敏 JSONL 记录写入 `~/Library/Logs/iTermate/codex-titles.log`；可从 Settings → About → **Show Logs in Finder** 打开目录，无需依赖界面错误提示。当前文件达到 1 MiB 后轮转为 `codex-titles.previous.log`，只保留这一对文件，跨 App 启动保留；同时运行的 App 实例使用独立锁文件协调写入和轮转。日志访问失败或锁正忙时会放弃该条记录，不阻断标题或会话操作。

记录包含时间、自动/手动来源、随机请求 ID、App/Codex PID、尝试次数及安全的失败类别；网络失败仅记录数值错误码，HTTP 失败记录状态码，不保存错误描述、URL、路径、对话、生成标题、思考或凭据。`token_limit` 表示模型因生成上限停止，`empty_title` 表示空标题，其他类别区分响应格式、完成状态、模型身份与配置变化。主动取消记为信息级 `session_title_generation_cancelled`；模型已返回但会话身份或状态改变导致不能应用时，记为 `session_title_result_discarded`，不冒充模型故障。

没有记录不代表生成成功：尚未满足可生成状态、对话摘录、自动补全偏好或唯一会话映射条件时，不会发起自动生成，也不会逐次轮询写日志。源码改动需用户自行构建并重新运行新版 App 才能作用于 Codex；不需要 reload Pi，也不会补写旧版运行期的错误。

退出已自动关联或应急绑定 daemon 的 Codex 进程时，App 会在清除关联前做最后一次三秒截止的只读历史查询；即使 thread 已 notLoaded，也只回收已持久化的完成事件，不把历史当作当前运行状态。终端身份变化、解绑或重新绑定会丢弃旧查询。

## 能力边界

- rollout 没有稳定的通用“等待用户输入”事件，不凭助手文本或工具名称猜测 `awaitingInput`；自动关联或应急绑定的 daemon 返回明确等待标记时才显示。
- 首次 1 MiB 尾部之前的事件与消息不会被追溯；初始状态可能未知。后续增量保留已观察状态，单次读取 8 MiB、单行 8 MiB 的预算限制仍可能造成延迟或跳过超长行，不能保证所有上游记录均被识别。
- 面板左侧方框表示已识别的 Codex Agent，三角表示 Pi，圆圈表示普通命令；只有 Agent 身份无法判断为 Pi 或 Codex 时，左侧显示呼吸像素感叹号并标注“Unknown Agent”，减少动态效果时静止。已识别 Agent 缺少生命周期数据时，右侧仅作中性显示，内部仍保留空值，不新增运行、待回复或成功完成证据。unknown 是身份类型，不是第三种回复类型。
- 共享 daemon 持有 rollout 时，CLI 本身可能没有文件描述符；身份由原生标题与只读 loaded 列表建立，不依赖文件存在。标题尚未更新、转发失败或服务不可读时，保留 Codex 身份与中性活动图标，不启动新的 daemon。
- 自动标题受初始尾部与已追上的增量范围限制；没有可用的可见用户／助手消息时保留原终端标题。缺少生命周期事件本身不阻止已识别 thread 的标题补全；没有匹配的 rollout 摘录时不根据项目名或 daemon 预览猜测标题。
- 已确认的 Codex 进程允许连续两次进程扫描暂时缺失；第三次仍缺失才中断并清理状态，避免短暂的 macOS 进程 API 竞态把界面切回普通命令。
- 已接受的 Codex 状态同时绑定可见 TTY 与终端 Session ID；同一 TTY 被新 Session 复用时会先移除旧 overlay，再重新观察。
- 同目录并行会话不共享目录级身份缓存，不按文件时间、启动参数或启动时间认领 thread；重复认领同一完整身份保持未知。
- 监测要求 Codex 位于面板可见终端的前台进程树中；`kiro-cli-term` 等创建的嵌套 PTY 会沿真实父子关系映射回外层 Session。后台 app-server、无可见终端祖先的进程和子代理 rollout 不会被当作独立终端 Session。
- 该方案依赖 Codex 本机 Session 文件中的生命周期事件格式；若上游格式变化，iTermate 会退化为只识别 Codex 身份，而不会解析终端屏幕作为补偿。
