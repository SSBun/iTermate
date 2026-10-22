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

| Codex 生命周期事件 | iTermate 状态 |
| --- | --- |
| `task_started` | running |
| `task_complete` | finished |
| `turn_aborted` | interrupted |
| 有界尾部暂无生命周期事件，但已映射的 rollout 持续增长 | running |
| 尚无可确认的生命周期事件 | 仅显示 Codex 身份，不猜测状态 |
| running 中的 Codex 进程消失 | interrupted |
| 其他状态下 Codex 进程退出 | 不再标记为 Codex |

## 能力边界

- Codex 当前保存的 rollout 生命周期没有稳定的通用“等待用户输入”事件，因此 iTermate 不伪造 `awaitingInput`。
- 为限制轮询开销，完成 Session 映射后的状态轮询只读取 rollout 尾部；若长任务把最近一次生命周期事件挤出有界尾部，iTermate 仅用文件长度继续增长这一元数据恢复 running，不读取更早的会话内容。
- 自动标题同样受有界尾部限制；若最近的可见用户/助手消息不在读取范围内，则保留原终端标题。
- 已确认的 Codex 进程允许连续两次进程扫描暂时缺失；第三次仍缺失才中断并清理状态，避免短暂的 macOS 进程 API 竞态把界面切回普通命令。
- 已接受的 Codex 状态同时绑定可见 TTY 与终端 Session ID；同一 TTY 被新 Session 复用时会先移除旧 overlay，再重新观察。
- 显式 `codex resume <session-id>` 可以直接映射；如果交互式恢复无法唯一映射，iTermate 只显示 Codex 身份，不猜测运行状态。
- 监测要求 Codex 位于面板可见终端的前台进程树中；`kiro-cli-term` 等创建的嵌套 PTY 会沿真实父子关系映射回外层 Session。后台 app-server、无可见终端祖先的进程和子代理 rollout 不会被当作独立终端 Session。
- 该方案依赖 Codex 本机 Session 文件中的生命周期事件格式；若上游格式变化，iTermate 会退化为只识别 Codex 身份，而不会解析终端屏幕作为补偿。
