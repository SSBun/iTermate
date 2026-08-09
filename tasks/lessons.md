# 2026-08-06 — 不得自行启动或重启 iTermate

## Trigger

- 源码改动需要在真实 App 中进行视觉或运行时验证。
- 准备执行 `venom-cli build --run`、`open` 或其他会启动、重启 iTermate 或 Bridge 的命令。

## Rule

- 只执行不会启动或重启 iTermate 的源码检查、构建或测试。
- 需要真实运行验证时，先请用户自行重新构建并运行 App；收到用户确认后再继续观察。
- 不得以验证为由替换用户当前运行的 App 或 Bridge 进程。

## Check

- Agent 执行前后的 iTermate 与 Bridge 进程未被 Agent 主动重启。
- 交付源码改动后明确提示用户自行重新运行 App，而不是代替用户启动。

# 2026-08-06 — 视觉参考中的可识别主体不能被抽象风格替代

## Trigger

- 用户提供包含可识别角色、图标或布局关系的视觉参考。
- 用户要求按参考创建状态组件或动画。

## Rule

- 实现前明确参考中的主体、伴随元素、尺寸关系和状态动作。
- 未经用户确认，不把角色或具象图形替换为仅保留像素、颜色等表面风格的抽象图案。

## Check

- 真实运行截图能辨认出用户指定的主体及伴随元素。
- 状态变化通过已确认的角色动作表达，而不是回退到抽象符号。

# 2026-07-31 — SwiftUI 显式视图身份必须覆盖强制刷新的展示字段

## Trigger

- `ForEach` 或懒加载容器中的行使用显式 `.id` 作为重建边界。
- Store 已收到正确快照，但某个标题或状态只在另一个字段变化后才更新。

## Rule

- 显式视图 ID 必须包含所有依赖“身份变化”来强制重建的可变展示字段；否则应移除该显式 ID。
- Session 行的显式 ID 至少覆盖名称、焦点状态、运行状态与退出码。
- 不把正确 Store 快照当作界面已经重绘的证据。

## Check

- 同步记录同一状态转换的 Bridge 快照和真实窗口截图。
- 只改变 Session 名称而不改变焦点或状态时，行标题仍立即更新。
- 真实窗口截图不需要等待无关状态变化才显示正确标题。

# 2026-07-31 — 动态终端字段不能读取初始化缓存

## Trigger

- Bridge 周期发布 Session 标题、路径或其他运行时可变字段。
- Python API 对象同时提供构造时属性与 `async_get_variable`。

## Rule

- 对运行时可变字段从 iTerm 变量 API 获取当前值。
- 动态值非空时更新；但每个 Tab 的当前 Session 应以 Tab 的动态标题作为最终可见标题，避免激活后仍非空的用户名或 shell fallback 覆盖正确标题。
- 动态值为空时优先沿用该 Session 最近的非空缓存，只有没有缓存时才回退对象属性。
- 周期快照必须覆盖无需 Layout 变化也会更新的字段。

## Check

- 选择 Session 后比较 Session 动态名称、Tab 动态标题与面板行标题；面板必须跟随 iTerm 当前可见标题。
- 快照回归测试让缓存标题与动态标题不同，并断言发布动态标题。
- 修改真实 Session 标题后，面板在周期内更新且无需重启。
- 动态变量读取失败时仍显示已有非空标题。

# 2026-07-31 — 共享配置文件不得用陈旧内存快照整文件覆盖

## Trigger

- 多个 App 进程或设置实例共享同一配置文件。
- 修改任一设置会把实例内的完整配置模型写回磁盘。

## Rule

- 写入设置前重新读取磁盘当前配置，只修改目标字段后原子写回。
- 初始化已有配置时只读取，不用默认值或内存快照重写。
- 读取已有配置失败时不覆盖原文件。

## Check

- 两个先创建的设置实例分别修改不同字段后，两项最终值都保留。
- 重启 Debug App 后配置文件内容和目标字段保持不变。

# 2026-07-30 — 外部权限状态不得覆盖用户持久化偏好

## Trigger

- 用户开关表示希望启用某项能力，而实际生效还依赖系统权限或外部服务状态。
- App 启动时会重新检查外部授权、连接或可用性。

## Rule

- 持久化用户意图与外部能力状态必须分开处理。
- 外部授权失败可阻止执行并记录原因，但不得把用户保存的开关自动改回关闭。

## Check

- 保存为开启后重启 App，即使外部能力不可用，配置文件中的偏好仍保持开启。
- 外部能力不可用时，受限操作不会被错误报告为成功，并留下可诊断信号。

# 2026-07-30 — 源码实现不得擅自覆盖用户安装态

## Trigger

- 任务要求修改随 App 分发的 Bridge、hook 或 agent integration 源码。
- 用户未明确要求安装、启用或覆盖用户目录中的运行时副本。

## Rule

- 只修改仓库源码和构建产物，不直接写入 `~/.pi`、`~/.codex` 或 iTerm AutoLaunch 等用户安装目录。
- 运行时验证使用临时目录、受控 mock 或 App 自有安装入口；需要改变用户安装态时先取得明确许可。

## Check

- 完成前确认用户安装目录未因源码实现被直接覆盖。
- 交付说明将“源码已构建”与“用户已安装/启用”明确区分。

# 2026-07-30 — Bridge 协议版本在 App 自管生命周期下不需要运行时校验

## Trigger

- App 从 bundle 安装常驻 Bridge 并杀死旧实例再启动新实例。
- 为新增协议消息或字段而递增协议版本号。
- 在 Swift 或 Python 端添加版本号常量、握手校验或向后兼容列表。

## Rule

- 确认 App 生命周期是否保证两端同版本：App 重启 → 安装 → 杀旧 → 启动新。
- 若架构保证两端同版本，则不添加协议版本检查；仅对独立更新的路径（如集成脚本）保留格式兼容。
- 协议版本号应该是一个固定的常量，只在需要拒绝格式不兼容的旧集成请求时使用，不为 App↔Bridge 通信增量。
- 不要为每轮内部重构递增版本号——消息字段可以自由增删，只需保证集成脚本的已知格式仍然通过验证。

## Check

- 源码中协议版本常量没有在 App↔Bridge 握手或每消息中被检查。
- 移除版本检查后，Swift 和 Python 的全量测试通过。
- 唯一保留的版本感知是为不随 App 更新的集成请求保留的格式兼容白名单。

# 2026-07-30 — Apple 新版界面必须优先使用原生容器

## Trigger

- 用户以 Xcode、系统设置或 Apple 最新设计作为界面参考。
- 当前实现通过自绘卡片、背景、圆角或固定尺寸模仿系统界面。

## Rule

- 先核对最新 Apple HIG、SDK 与参考应用，再选择界面结构。
- 设置页优先使用 `Settings` + `.sidebarAdaptable` `TabView`，不要用 `NavigationSplitView` 或自定义包装器模拟系统设置界面。
- 删除会覆盖系统材质、间距或交互状态的自定义视觉效果；仅在原生组件无法表达功能时增加最小自定义效果。

## Check

- 使用最新 SDK 构建，并在最新系统运行时检查侧边栏、工具栏、表单和控件外观。
- 界面跟随系统强调色、侧边栏尺寸及降低透明度等辅助功能设置。
- 标准容器可表达的区域不存在手工 Liquid Glass、自定义导航背景或硬编码系统外观。

# 2026-07-30 — SwiftUI Settings 入口必须验证真实窗口创建

## Trigger

- 菜单栏或 `LSUIElement` App 通过 selector、`SettingsLink` 或环境动作打开 SwiftUI `Settings` scene。
- 构建通过，但点击 Settings 没有创建或置前窗口。

## Rule

- macOS 14+ 使用 `openSettings` 环境动作，并在调用前激活后台 App。
- 不把 `NSApplication.sendAction` 成功编译或按钮 action 触发当作 Settings scene 已打开。
- 修改所有 Settings 入口后，分别验证每个入口的真实构建产物。

## Check

- 运行进程路径指向本次构建产物，避免 LaunchServices 启动同 bundle ID 的旧副本。
- 点击每个入口后，Accessibility 能观察到 Settings 窗口创建且窗口可见。

# 2026-07-30 — 悬停操作必须使用唯一且可兜底清理的状态

## Trigger

- 非激活面板的每个列表行各自保存悬停布尔值。
- tracking exit 因视图更新、复用或窗口边界而遗漏后，隐藏操作仍残留显示。

## Rule

- 父视图只保存一个当前悬停行 ID；新行进入时替换，离开时仅清理匹配 ID。
- 面板级 tracking 在指针离开整个面板时无条件清空悬停 ID。
- 隐藏的鼠标操作同时关闭 hit testing，不能只把 opacity 设为零。

## Check

- 面板外不显示关闭按钮；进入一行时只显示该行按钮，跨行时按钮跟随。
- 离开面板后所有关闭按钮立即隐藏。
- 不可见按钮不能接收鼠标点击。

# 2026-07-30 — App 重启不会自动重启常驻 Bridge

## Trigger

- 用户只重启 Swift App，但 Bridge 进程仍由 iTerm2 AutoLaunch 常驻。
- Bridge 内存中的 Session 状态会跨越 App 客户端重连继续存在。

## Rule

- 分别验证 App 客户端生命周期与 Bridge helper 生命周期，不把 App 重启当作状态重置。
- Bridge 接受新的 App 连接后，在发送首个快照前按当前 Prompt 重新验证 running 状态。
- 无法确认已结束的 Agent 状态时同时释放 Agent 状态所有权，避免后续 Shell 状态被永久屏蔽。

## Check

- 重启 App 后新的 Bridge 连接不会继续展示已结束 Session 的旧 running 状态。
- 仍为 RUNNING 的 Prompt 保留 running，已结束 Prompt 被清理。
- Socket 握手、安装脚本与运行中 Bridge 版本一致。

# 2026-07-30 — 系统唤醒后不能继续信任内存中的 running 状态

## Trigger

- Bridge 通过内存字典保存 Agent 或命令的 running 状态。
- macOS 睡眠期间可能错过 Agent settled、PromptMonitor 或 Socket 事件。

## Rule

- 用墙上时钟检测事件循环跨越睡眠的长时间间隔。
- 唤醒后清除无法重新确认的 running 状态，保留 finished 状态。
- 对普通 Shell Session 用当前 Prompt 状态恢复仍在运行的命令，不根据 Agent 进程仍存在就猜测状态。

## Check

- 模拟唤醒刷新时，Agent running 状态被清除。
- Prompt 仍为 RUNNING 的普通命令被恢复，已结束 Prompt 不再显示 running。
- 运行快照不再长期保留睡眠前的错误 running 状态。

# 2026-07-30 — 命令状态监控必须先同步当前状态

## Trigger

- 仅在订阅 `PromptMonitor` 后等待 `COMMAND_START`/`COMMAND_END` 事件。
- Bridge 启动或重连时，Session 中的命令可能已经开始运行。

## Rule

- 建立事件监控前先读取 Session 的最近 Prompt 状态。
- 最近 Prompt 为 `RUNNING` 时立即发布 running 状态，再继续监听增量事件。
- 没有 Shell Integration 或读取失败时保持未知，不根据进程名称猜测运行状态。

## Check

- 启动或重连期间已有普通命令的 running 状态可恢复。
- 新启动和结束的普通命令仍由 PromptMonitor 更新。
- 未启用 Shell Integration 的 Session 不伪造状态。

# 2026-07-29 — Bridge 焦点标记必须来自全局当前 Session

## Trigger

- Bridge 快照为每个 Tab 分别读取 `current_session` 并把结果直接发布为焦点状态。
- 面板按 Window 或路径跨 Tab/Window 合并 Session 行。

## Rule

- 先从 iTerm 当前 Window 的当前 Tab 读取唯一当前 Session ID，再为快照中的 Session 生成焦点标记。
- 不要把每个 Tab 的局部 `current_session` 都发布为全局聚焦状态。
- 保持快照中最多一个 Session 具有全局焦点标记。

## Check

- self-test 使用两个 Tab 断言只有当前 Tab 的 Session 标记为 active。
- 真实 Socket 快照连续检查的聚焦候选数为 1。
- 运行面板截图只显示一个聚焦 Session 行。

# 2026-07-29 — MenuBarExtra 自定义图像必须显式设置 NSImage 尺寸

## Trigger

- SwiftUI `MenuBarExtra` 使用自定义 PNG/PDF/asset image 作为 label。
- 即使 label 内有 `.frame(width: 16, height: 16)`，运行时图标仍按资源原始尺寸显示。

## Rule

- 不要依赖 SwiftUI label 的 frame 约束自定义状态栏图像。
- 保留高分辨率资源，并在 `NSImage` 层按目标点高设置尺寸后再创建 `Image(nsImage:)`。
- 按原始宽高比计算宽度，不要拉伸图像。

## Check

- `assetutil` 确认 bundle 仍包含高分辨率资源。
- 运行时截图确认图标可见高度约为目标 `16pt`，而不是源 PNG 的像素尺寸。

# 2026-07-29 — macOS 本地通知必须验证系统实际投递

## Trigger

- 新增或修改 `UNUserNotificationCenter` 本地通知。
- 源码、构建和状态转换测试通过，但用户看不到通知。

## Rule

- `add` 必须提供 completion handler 并记录系统返回的发送错误。
- 使用真实运行 App 触发完整状态转换，并检查 `usernoted` 是否接受、投递和展示通知。
- 验证前只保留一个 App 实例，并确认代码签名 identifier 与 `CFBundleIdentifier` 一致；不要使用 `CODE_SIGNING_ALLOWED=NO` 产物验证通知授权。Debug App 在运行期间被重新构建或签名后，先重启再验证。

## Check

- App 日志显示通知请求 `hasError: 0`。
- `usernoted` 日志显示 `Delivering` 和 `Presenting ... as banner`。
- 发送失败时日志包含 `iTermate notification failed` 及系统错误。

# 2026-07-29 — 高分辨率菜单栏光栅图标不能先降采样

## Trigger

- 用户提供高分辨率 PNG 作为菜单栏图标。
- 为适配资源画布或增加留白时，准备先把源图缩放到 24px 或更小。

## Rule

- 保留源 PNG 的原始像素分辨率，不要通过降采样解决菜单栏显示尺寸问题。
- 只在运行时 frame 或高分辨率画布中控制显示尺寸；需要模板化时仅转换颜色/透明度，不降低源分辨率。

## Check

- `file` 或 `sips` 确认资源像素尺寸仍与用户源文件一致。
- Xcode 构建产物加载的是高分辨率资源，菜单栏 frame 独立控制视觉大小。

# 2026-07-29 — macOS SwiftUI 滚动指示器必须做运行时验证

## Trigger

- macOS SwiftUI 页面使用 `.scrollIndicators(.hidden)` 隐藏滚动指示器。
- 用户仍能在运行时截图中看到原生滚动条。

## Rule

- 不要仅凭源码修饰符或构建通过就判定滚动指示器已隐藏。
- 优先使用 `ScrollView` 的 `showsIndicators: false` 初始化参数，并重新启动实际构建产物验证。

## Check

- 运行时设置页截图中右侧不再出现滚动指示器。
- 内容仍能在超出窗口高度时滚动。

# 2026-07-29 — 长驻 Agent 状态必须使用可靠的 Agent 生命周期

## Trigger

- Pi、Codex 等交互式 Agent 进程长期驻留在终端中。
- Shell Integration 将外层 Agent CLI 持续标记为命令运行中，但 Agent 实际已等待用户输入。

## Rule

- Pi 使用 `agent_start` 与 `agent_settled`，Codex 使用 `UserPromptSubmit` 与 `Stop` 作为工作/完成边界。
- Agent 生命周期状态优先于 Shell Integration；Shell Integration 只作为普通命令的 fallback。
- Agent 退出后显式释放状态所有权，使后续普通 shell 命令恢复由 PromptMonitor 观察。
- Lifecycle handler 返回前必须等待 Bridge 确认状态或达到有界超时，不能 fire-and-forget。

## Check

- Agent CLI 进程仍存活但已等待输入时，不显示运行动画。
- 新一轮 agent turn 开始时显示运行动画，settled/Stop 后显示完成图标。
- Agent 退出后运行普通 shell 命令，PromptMonitor 状态仍可更新。
- Handler 返回可等待结果，smoke check 观察到 `running → finished` 已由 Bridge 确认。

# 2026-07-30 — 非激活浮动面板的悬停反馈必须使用 Always tracking

## Trigger

- companion panel 使用 `.nonactivatingPanel`，而另一个应用仍保持系统前台。
- 边缘光标或逐行控件依赖 SwiftUI `.onHover`、`addCursorRect` 或普通 tracking，但反馈缺失或出现在错误行。

## Rule

- 悬停区域使用带 `.activeAlways` 的 `NSTrackingArea`，不要仅依赖 SwiftUI `.onHover`。
- 重复列表行各自保存悬停状态；tracking view 覆盖整行且不拦截原有点击。
- 边缘 tracking 回调负责设置和恢复调整光标，原生 `.resizable` 负责拖拽。

## Check

- 回归测试断言 tracking area 包含 `.activeAlways`。
- 目标应用保持前台时，实际验证边缘光标反馈。
- 指针依次移过两行及面板外，确认仅悬停行显示控件，移出后全部隐藏。

# 2026-07-29 — 新应用不主动兼容未要求的历史配置

## Trigger

- 新应用或新模块更换配置文件路径、格式或持久化方案。
- 旧版本配置是否需要迁移未被用户明确要求。

## Rule

- 只实现当前约定的配置路径和格式，不为未要求的历史配置增加读取、迁移或兼容分支。
- 只有用户明确要求保留旧配置时，才增加迁移逻辑并单独验证迁移边界。

## Check

- 源码不读取未要求的旧配置路径。
- 测试只覆盖当前配置路径和当前格式。

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
