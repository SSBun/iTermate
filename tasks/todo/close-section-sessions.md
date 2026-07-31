# 从 Section 上下文菜单关闭相关 Sessions

Status (2026-07-30 21:33): Completed

## Scope

- 包含：为 Window、Project Path 与 Tab section header 添加原生 SwiftUI 上下文菜单。
- 包含：上下文菜单中的破坏性操作关闭该 section 当前包含的全部 Session。
- 不包含：强制关闭、自定义批量确认弹窗或新的 Bridge 批量协议。

## Target

- [x] T1：右键任一 Window、Project Path 或 Tab section header 时显示带垃圾桶图标的 `Close All Sessions` 操作。
- [x] T2：操作只向现有 Bridge 发送该 section 当前包含的 Session ID；Project Path 可跨 Window，Tab 只包含对应 Tab。
- [x] T3：继续使用 iTerm 原生非强制关闭行为；单个 Session 关闭按钮、折叠和激活行为不回归。
- [x] T4：相关单测、Swift 解析、完整 Xcode 测试与最新 App 构建通过。

## Plan

1. 在 section 分组模型提供最小的 Tab Session 筛选能力并增加聚焦测试。
2. 复用现有 `store.close(sessionID:)`，给顶层与 Tab section header 添加同一破坏性上下文菜单项。
3. 运行解析、完整测试、构建与最新 App 启动验证。

## Result

- T1：Window、Project Path 与可见的 Tab section header 均使用标准 SwiftUI `.contextMenu`，包含带 `trash` 图标和 destructive role 的 `Close All Sessions` 操作。真实 Debug App 中已分别右键 Project Path 与 Tab 标题确认菜单出现。
- T2：顶层 section 直接使用 `SessionListGroup.sessions`；Tab 通过新增的 `sessions(inTab:)` 只筛选同一 Tab 的 Session。聚焦测试验证单 Session Tab 与双 Session Tab 的 ID 列表，Project Path 跨 Window 分组继续由既有测试覆盖。
- T3：菜单逐个复用 `store.close(sessionID:)`，未增加批量协议、强制关闭或自定义确认；Bridge 继续调用 iTerm 原生 `async_close()`。为保护当前真实终端工作，运行时只验证菜单呈现，未点击破坏性操作。
- T4：Swift parse、`git diff --check`、聚焦分组测试、完整 Xcode 测试与 Debug build 均通过；完整测试 32/32 成功。临时切换的 Window/Tab 显示配置已精确恢复，最新 App 正在运行。
- Review gate: Skipped — no explicit user request.
