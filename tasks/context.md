# 工作区上下文

## 工程与组件

- XcodeGen 的 [`project.yml`](../project.yml) 是 Xcode 工程配置的规范来源，生成的 [`iTermate.xcodeproj`](../iTermate.xcodeproj) 可直接构建；修改 target 或构建设置时应更新 YAML 后重新生成工程。——权威来源：[`project.yml`](../project.yml)
- 应用 shell 使用 SwiftUI `App`，由 `MenuBarExtra(.window)` 提供 Bridge 摘要与 Settings/Quit，由 `Settings` scene 提供 Basic/About 标签；`AppDelegate` 仅负责启动共享 Store 与浮动面板。macOS 14+ 用 `SettingsLink`，macOS 13 用 `showSettingsWindow:` fallback。——权威来源：[`iTermateApp.swift`](../iTermate/iTermateApp.swift) 与 [`SettingsViews.swift`](../iTermate/SettingsViews.swift)
- 窗口几何与 iTerm 语义分层：`PanelFollower` 在 Swift 侧通过 Core Graphics 以 30Hz 跟随前台 iTerm 窗口，Window/Tab/Session 层级及操作由 Python Bridge 提供，因此当前无需 Accessibility 权限。——权威来源：[`iTermateApp.swift`](../iTermate/iTermateApp.swift) 与 [`ItermBridge.swift`](../iTermate/ItermBridge.swift)；若改为事件驱动窗口监听时复查
- Bridge 作为 App resource 安装到 iTerm2 AutoLaunch，使用文件锁保证单实例，并通过用户私有目录中的 Unix Socket 与 App 交换 versioned JSON Lines；当前协议与 Bridge 版本均为 2，修改协议时必须同步递增/校验 Swift 与 Python 两端。——权威来源：[`iTermateBridge.py`](../iTermateBridge/iTermateBridge.py)、[`ItermBridge.swift`](../iTermate/ItermBridge.swift) 与 [`project.yml`](../project.yml)
- Bridge v2 同步全量 Window/Tab/Session 快照；每个 Session 包含精确当前目录、父 Window/Tab、焦点与 minimized 状态，并由 Layout、Focus 和 2 秒周期更新。唯一写操作是按稳定 `session_id` 激活 Session；Prompt、Screen、发送文本和会话管理尚不在协议中。——权威来源：[`iTermateBridge.py`](../iTermateBridge/iTermateBridge.py)
- 面板可按 Window 平铺其所有 Session，或按 Session 的精确当前目录跨 Window/Tab 分组；Window 或文件夹路径只显示在 section header，Session 行只显示标题与状态图标。样式由标题栏菜单切换并持久化，点击 Session 会选择父 Tab、聚焦 pane 并将 Window 置前。——权威来源：[`ItermBridge.swift`](../iTermate/ItermBridge.swift)、[`SettingsViews.swift`](../iTermate/SettingsViews.swift) 与 [`iTermateApp.swift`](../iTermate/iTermateApp.swift)
- `AppSettings` 是面板宽度的共享权威状态：Basic Settings 滑杆与原生边缘拖拽都可在 180–600pt 之间调整并通过 `UserDefaults` 跨启动保存；默认值为 260pt。面板高度始终匹配 iTerm，与 iTerm 间隔 8pt，优先放右侧，空间不足放左侧，再不足则覆盖在可见屏幕内。——权威来源：[`SettingsViews.swift`](../iTermate/SettingsViews.swift)、[`iTermateApp.swift`](../iTermate/iTermateApp.swift)、[`PanelLayout.swift`](../iTermate/PanelLayout.swift) 与 [`PanelLayoutTests.swift`](../iTermateTests/PanelLayoutTests.swift)
