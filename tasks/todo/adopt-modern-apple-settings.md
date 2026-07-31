# 恢复顶部标签式设置窗口

Status (2026-07-30 16:39): Completed

## Scope

- 包含：撤销侧边栏式 Xcode 26 设置布局，恢复由标准 SwiftUI `TabView` 提供的顶部 General、Agents、About 标签。
- 包含：保留字体、Session、通知、Agent integration 与更新检查等现有设置功能。
- 包含：移除本轮视觉验证引入的隐藏标题栏、统一工具栏与环境变量自动打开设置入口。
- 不包含：继续模仿 Xcode 侧边栏、重做设置内容或新增配置项。

## Target

- [x] T1：设置窗口使用标准顶部 `TabView` 标签，不包含 `NavigationSplitView`、sidebar List 或 `.sidebarAdaptable`。
- [x] T2：General、Agents、About 三页及全部现有设置行为保持可用。
- [x] T3：App 不包含 `ITERMATE_OPEN_SETTINGS_ON_LAUNCH` 调试入口、隐藏标题栏或强制 unified toolbar 样式。
- [x] T4：macOS 13 deployment target 构建通过，完整自动化测试无回归。

## Result

- T1：`SettingsView` 已恢复为单一标准 `TabView`，General、Agents、About 通过 `.tabItem` 显示在窗口顶部；源码检查确认不存在侧边栏或 navigation container。
- T2：General 的字体、字号、Session、路径标题和通知设置，Agents integration 管理及 About 更新检查均保留原绑定和行为。
- T3：已删除视觉迭代过程中加入的 hidden title bar、unified toolbar 以及 `ITERMATE_OPEN_SETTINGS_ON_LAUNCH` launcher；最新 DerivedData App 已按精确 PID 重启。
- T4：Xcode 26.2 / macOS 26.2 SDK 以 `macOS 13.0` deployment target 完成 34/34 测试；`swiftc -parse` 与 `git diff --check` 通过。
- Review gate: Skipped — no explicit user request.
