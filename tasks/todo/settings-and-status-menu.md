# 创建标准设置页与菜单栏状态视图

Status (2026-07-28 17:35): Completed

## Scope

- 包含：使用 macOS SwiftUI Scene 构建带 Basic、About 标签的设置窗口，以及展示 Bridge 摘要和常用操作的菜单栏状态视图。
- 不包含：登录时启动、手动隐藏面板、Bridge 高级控制或新增偏好项。

## Target

- [x] T1：用户可从菜单栏打开原生 Settings 窗口，并在 Basic、About 两个标签间切换。
- [x] T2：Basic 标签可实时调整 180–600pt 面板宽度、恢复默认值，并沿用跨启动持久化。
- [x] T3：About 标签展示 App 图标、名称、版本和版权信息。
- [x] T4：菜单栏状态视图展示 Bridge 连接状态、窗口数和 Tab 数，并提供 Settings 与 Quit 操作。
- [x] T5：功能兼容 macOS 13，原有面板跟随、调整宽度、Tab 同步和点击行为不回归。

## Plan

1. 将应用入口接入 SwiftUI App、Settings 和 MenuBarExtra Scene。
2. 共享面板宽度状态，让 Settings 与边缘拖拽实时同步并持久化。
3. 构建 Basic、About 和状态菜单内容，处理 macOS 13 的设置入口兼容。
4. 添加状态与偏好验证，并运行构建、测试和真实窗口检查。

## Result

- T1：运行构建产物后，MenuBarExtra 的 Settings 控件打开系统 Settings scene；Accessibility 操作确认 Basic、About 标签可切换，窗口使用原生 TabView/Form 外观。
- T2：Accessibility 将 Basic 滑杆从 260pt 调至 320pt 后，Core Graphics 确认面板实时变为 320pt且 `UserDefaults` 同步；Restore Default 恢复 260pt。测试覆盖 180–600pt 限制、持久化与重置。
- T3：About 运行时窗口展示 App 图标、iTermComrade、`Version 0.1.0 (1)` 与当前年份版权信息；版本来自生成的 bundle metadata。
- T4：运行时菜单栏窗口展示 Bridge 状态、错误详情、Windows/Tab 数量和 Settings/Quit；Accessibility 分别触发 Settings 与 Quit 成功。
- T5：工程 deployment target 保持 macOS 13；macOS 14+ 使用 `SettingsLink`，macOS 13 编译到标准 `showSettingsWindow:` fallback。默认 `xcodebuild test` 运行 13 个测试全部通过，`swiftc -parse`、bundle 版本检查和 `git diff --check` 通过；当前环境无 macOS 13 主机进行 fallback 运行时验证。
- Review gate: Required — SwiftUI Scene、AppKit 面板与持久化状态构成跨组件和状态变更；macOS 13 设置入口缺少对应系统的运行时环境，存在验证缺口。
- Review decision: `APPROVED` — 2 次 Reviewer pass 后无未解决 finding；[审查报告](../../reports/adversarial-review/settings-and-status-menu.md)。
