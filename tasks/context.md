# 工作区上下文

## 工程与组件

- XcodeGen 的 [`project.yml`](../project.yml) 是 Xcode 工程配置的规范来源，生成的 [`iTermComrade.xcodeproj`](../iTermComrade.xcodeproj) 可直接构建；修改 target 或构建设置时应更新 YAML 后重新生成工程。——权威来源：[`project.yml`](../project.yml)
- 首版应用仅负责浮动面板跟随，不包含 Session 数据；`PanelFollower` 通过 Core Graphics 按 iTerm bundle identifier 对应进程筛选最前方窗口，并以 30Hz 更新不激活但接收鼠标事件的 `NSPanel`，因此当前无需 Accessibility 权限。——权威来源：[`iTermComradeApp.swift`](../iTermComrade/iTermComradeApp.swift)；若改为事件驱动窗口监听时复查
- 面板固定宽 260pt、与 iTerm 间隔 8pt且匹配其高度；优先放右侧，空间不足放左侧，再不足则覆盖在可见屏幕内。——权威来源：[`PanelLayout.swift`](../iTermComrade/PanelLayout.swift) 与 [`PanelLayoutTests.swift`](../iTermComradeTests/PanelLayoutTests.swift)
