# 2026-07-29 — Companion 面板可见性必须跟随目标应用前台状态

## Trigger

- 浮动面板使用 `.floating` 或 `orderFrontRegardless()` 跟随另一个应用。
- Core Graphics 仍能找到目标应用的屏幕窗口，但其他应用已经置前。

## Rule

- 同时验证目标应用是系统前台应用且目标窗口可见。
- 目标应用失去前台时隐藏 companion 面板，重新置前时恢复。
- 不要把“窗口仍在屏幕上”当作“窗口位于最前”。

## Check

- 其他应用置前时面板不覆盖该应用。
- 切回目标应用后面板恢复原有跟随位置。
- 目标窗口最小化或不存在时面板仍保持隐藏。

# 2026-07-29 — 长驻 Agent 状态必须使用 Agent 生命周期

## Trigger

- Pi、Codex 等交互式 Agent 进程长期驻留在终端中。
- Shell Integration 将外层 Agent CLI 持续标记为命令运行中，但 Agent 实际已等待用户输入。

## Rule

- Pi 使用 `agent_start` 与 `agent_settled`，Codex 使用 `UserPromptSubmit` 与 `Stop` 作为工作/完成边界。
- Agent 生命周期状态优先于 Shell Integration；Shell Integration 只作为普通命令的 fallback。
- Agent 退出后显式释放状态所有权，使后续普通 shell 命令恢复由 PromptMonitor 观察。

## Check

- Agent CLI 进程仍存活但已等待输入时，不显示运行动画。
- 新一轮 agent turn 开始时显示运行动画，settled/Stop 后显示完成图标。
- Agent 退出后运行普通 shell 命令，PromptMonitor 状态仍可更新。

# 2026-07-29 — UI 图标缩放必须验证可见绘制边界

## Trigger

- 用户反馈图标或控件仍然过大/过小。
- 只调整外层 frame 或 layout 数值后没有直接检查资源的实际绘制边界。

## Rule

- 同时检查容器尺寸和图像内容的非透明/非空白边界。
- 对矢量资源优先调整 viewBox 或内部留白，不能只依赖小幅 frame 变化。
- 使用渲染预览或实际构建产物确认变化可见，再向用户报告完成。

## Check

- 记录修改前后的可见绘制边界或缩放比例。
- 在目标背景上查看最终渲染预览。
- 运行相关构建或资源编译验证图标仍可加载。

# 2026-07-28 — 分组列表只在正确层级展示信息

## Trigger

- 设计按 Window、Workspace 或路径分组的列表。
- 分组标题包含未标明单位的数字，或行内重复分组信息。

## Rule

- 分组元数据只放在 section header，列表行只展示用户要求的主标识。
- 不显示可能被误解为分组数量的无标签计数。
- 不用 Tab、路径等上下文重复挤占 Session 标题行，除非用户明确要求。

## Check

- Window header 不会把 Session 数量表现成 Window 数量。
- Workspace header 显示文件夹路径，其下仅列 Session 标题。
- 每个 Session 仍只出现一次且可执行原有操作。

# 2026-07-28 — 升级常驻 Bridge 时同步替换运行实例

## Trigger

- 修改常驻 Bridge、daemon 或 AutoLaunch helper 的协议或版本。
- 磁盘脚本已更新，但旧进程可能继续持有 socket 或单实例锁。

## Rule

- 明确区分磁盘安装版本与运行中版本。
- 在不终止用户终端会话的前提下，优先重启 helper 本身并完成运行时升级。
- 仅重启 Bridge 服务时，使用下面的流程，不重启整个 iTerm：
  ```bash
  SOCKET="$HOME/Library/Application Support/iTermate/bridge.sock"
  SCRIPT="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/iTermateBridge.py"

  PID="$(lsof -t "$SOCKET" 2>/dev/null || true)"
  [ -z "$PID" ] || kill "$PID"
  rm -f "$SOCKET"

  /Applications/iTerm.app/Contents/Resources/it2run "$SCRIPT"
  ```
- 若无法安全重启 helper，必须在完成前获得用户接受，不要把仅替换磁盘文件表述为升级完成。

## Check

- 从真实 socket 握手验证运行版本等于源代码和安装文件版本。
- 确认旧 helper 进程已退出且新 helper 接管 socket。
- 确认 iTerm2 主进程未被重启。
- 验证 App 能连接新协议并收到快照。

# 2026-07-28 — 视觉方向变化后先确认提示词再生成

## Trigger

- 用户提供新的图标风格参考或否定上一轮视觉方向。
- 下一步图像生成会消耗配额或产生多个候选。

## Rule

- 先把参考图拆解为可复用的视觉语言，并明确不得复制的主体元素。
- 先提交修订后的提示词或概念供用户确认，再调用图像生成工具。
- 不要把用户的风格反馈直接解释为立即批量生成许可。

## Check

- 用户已明确确认当前提示词或概念方向。
- 提示词分别列出继承的视觉特征和禁止复制的参考元素。
- 确认前未调用图像生成工具。

# 2026-07-28 — 不默认启用浮动面板点击穿透

## Trigger

- 新增或调整覆盖其他应用的 `NSPanel`。
- 用户未明确要求鼠标事件穿透面板。

## Rule

- 不要设置 `ignoresMouseEvents = true`。
- 展示型面板也应默认接收其覆盖区域内的点击，除非用户明确要求 click-through。

## Check

- 运行时确认面板的 `ignoresMouseEvents` 为 `false`。
- 点击面板覆盖区域不会命中下方应用。
