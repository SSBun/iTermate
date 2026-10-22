# Codex 原生状态监控

iTermate 被动观察直接运行的原始 `codex` 命令，不需要 `codexm`、启动包装器、Codex hooks 或专属 app-server。

## 使用

1. 启动 iTermate。
2. 在 iTerm2 或 Ghostty 中直接运行 `codex`。
3. iTermate 自动把该终端前台进程树中的 Codex 状态显示到对应 Session。

Settings → Agents 中 Codex 显示为 **Automatic**，无需安装或信任任何配置。升级时，iTermate 会从 `~/.codex/hooks.json` 删除自己过去写入、带 `_iTermate` 标记的条目，并保留其他工具的 hooks；旧包装器和标记文件也会被移除。

## 数据来源与状态映射

iTermate 每两秒进行一次只读观察：

- 使用 macOS 进程 API 确认终端前台进程树中的原生 Codex CLI；
- 用进程启动时间、工作目录或显式 resume Session ID 映射 `~/.codex/sessions` 中的根 Session；非显式恢复时会读取 rollout 首行的 Session 时间戳、`cwd` 与 `source` 元数据完成映射，不依赖可能延迟的文件系统创建时间；
- 读取本机 rollout JSONL 的有界尾部，使用生命周期事件类型和时间戳判断状态；
- 在一次任务完成后，从同一有界尾部最多选取最近四条用户消息和四条助手消息，每条最多 2,000 个字符，交给 Settings 中已选择的本地 Ollama 模型生成短标题。开发者消息、思考和工具记录不会进入标题输入，数据不会发送到云端。

标题与 Pi 一样只覆盖 iTermate 面板中的 Session 显示名，不改写 iTerm2 或 Ghostty 的真实 Session 标题。生成结果会再次校验 Codex 进程、TTY 与终端 Session ID；终端复用或 Session 切换后，旧请求不能写入新行。失败时最多自动重试一次，原终端标题保持不变。

Codex 标题的每次模型调用最多生成 1,024 tokens，上下文请求仍为 16,384 tokens；输出预算不是标题字数上限，提示词也不再要求固定字数。首轮完整结果超过 80 个字符或包含多行时，会最多再调用一次相同本地模型，根据原对话及草稿提炼标题；80 字符只是触发再次概括的阈值，不是有效性限制。首轮因 token 上限停止时，仅把非空草稿用于这一次提炼，不直接展示截断内容。第二轮必须正常结束，其非空结果原样采用，不再进行长度检查或继续循环。

两轮始终绑定同一模型配置与库存身份，保留取消、HTTP/响应有效性和原有会话身份检查；第二轮失败仍保留原标题并记录诊断。每个自动尝试至多两次模型调用，外层最多自动重试一次，每次 HTTP 调用保留既有超时。此变化只适用于 Codex，不修改 Pi 集成。

已识别的原生 Codex Session 始终可以从右键菜单选择 **Refresh Session Title**，包括 Codex 正在运行时。手动刷新会替换同一 Session 的旧标题请求，并在对话或 Session 身份发生变化时丢弃过期结果；普通 Shell Session 不提供该操作。

| Codex 生命周期事件 | iTermate 状态 |
| --- | --- |
| `task_started` | running |
| `task_complete` | finished；激活对应会话查看后为 idle |
| `turn_aborted` | interrupted |
| 有界尾部暂无生命周期事件，但已映射的 rollout 持续增长 | running |
| 尚无可确认的生命周期事件 | 仅显示 Codex 身份，不猜测状态 |
| running 中的 Codex 进程消失 | interrupted |
| 其他状态下 Codex 进程退出 | 不再标记为 Codex |

完成标记只在查看对应会话后清除：点击 iTermate 的会话行并成功激活，或在前台终端中切换到该窗口、Tab、分屏会话时，显示转为 `idle`。从其他应用切回终端也会确认当前会话；仅后台轮询或在同一会话等待回复结束不会自动清除刚出现的完成标记。

查看确认绑定终端 Session ID、TTY、Codex 进程身份与本次完成时间。同一完成事件再次被轮询到不会恢复完成标记；下一轮完成仍会显示 `finished`。运行、等待回复、中断与未知状态不会因查看而清除。该变化只影响 iTermate 展示，不改写 Codex rollout。

## 标题诊断日志

Codex 标题自动生成、手动刷新失败以及手动刷新缺少可用会话时，App 将脱敏 JSONL 记录写入 `~/Library/Logs/iTermate/codex-titles.log`；可从 Settings → About → **Show Logs in Finder** 打开目录，无需依赖界面错误提示。当前文件达到 1 MiB 后轮转为 `codex-titles.previous.log`，只保留这一对文件，跨 App 启动保留；同时运行的 App 实例使用独立锁文件协调写入和轮转。日志访问失败或锁正忙时会放弃该条记录，不阻断标题或会话操作。

记录包含时间、自动/手动来源、随机请求 ID、App/Codex PID、尝试次数及安全的失败类别；网络失败仅记录数值错误码，HTTP 失败记录状态码，不保存错误描述、URL、路径、对话、生成标题、思考或凭据。`token_limit` 表示模型因生成上限停止，`empty_title` 表示空标题，其他类别区分响应格式、完成状态、模型身份与配置变化。主动取消记为信息级 `session_title_generation_cancelled`；模型已返回但会话身份或状态改变导致不能应用时，记为 `session_title_result_discarded`，不冒充模型故障。

没有记录不代表生成成功：尚未满足完成状态、对话摘录或唯一会话映射条件时，不会发起自动生成，也不会逐次轮询写日志。源码改动需用户自行构建并重新运行新版 App 才能作用于 Codex；不需要 reload Pi，也不会补写旧版运行期的错误。

## 能力边界

- Codex 当前保存的 rollout 生命周期没有稳定的通用“等待用户输入”事件，因此 iTermate 不伪造 `awaitingInput`。
- 为限制轮询开销，完成 Session 映射后的状态轮询只读取 rollout 尾部；若长任务把最近一次生命周期事件挤出有界尾部，iTermate 仅用文件长度继续增长这一元数据恢复 running，不读取更早的会话内容。
- 自动标题同样受有界尾部限制；若最近的可见用户/助手消息不在读取范围内，则保留原终端标题。
- 已确认的 Codex 进程允许连续两次进程扫描暂时缺失；第三次仍缺失才中断并清理状态，避免短暂的 macOS 进程 API 竞态把界面切回普通命令。
- 已接受的 Codex 状态同时绑定可见 TTY 与终端 Session ID；同一 TTY 被新 Session 复用时会先移除旧 overlay，再重新观察。
- 显式 `codex resume <session-id>` 可以直接映射；如果交互式恢复无法唯一映射，iTermate 只显示 Codex 身份，不猜测运行状态。
- 监测要求 Codex 位于面板可见终端的前台进程树中；`kiro-cli-term` 等创建的嵌套 PTY 会沿真实父子关系映射回外层 Session。后台 app-server、无可见终端祖先的进程和子代理 rollout 不会被当作独立终端 Session。
- 该方案依赖 Codex 本机 Session 文件中的生命周期事件格式；若上游格式变化，iTermate 会退化为只识别 Codex 身份，而不会解析终端屏幕作为补偿。
