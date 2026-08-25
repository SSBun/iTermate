# 添加 Ghostty 基础支持

Status: Completed (2026-08-24 17:32)
Kind: Task

## Scope

- 包含：Ghostty 1.3+ 的层级快照、工作目录、前台窗口跟随、Terminal 聚焦与关闭，以及与 iTerm2 后端之间的自动切换。
- 排除：Ghostty 普通 Shell 命令状态、Pi/Codex Agent 状态和旧版 Ghostty 兼容。

## Target
- [x] T1: Ghostty 1.3+ 位于前台时，iTermate 面板跟随其前台窗口，并通过现有界面展示 Window、Tab、Terminal 及工作目录。
- [x] T2: 用户可从面板聚焦或关闭 Ghostty Terminal，现有 Window 与 Project Path 分组可用于 Ghostty 数据。
- [x] T3: 现有 iTerm2 支持保持可用，Ghostty 不展示无法从其 API 可靠获得的普通 Shell 或 Agent 活动状态。

## Plan

1. 让共享 Session 状态按当前前台受支持终端选择数据源，同时保留现有 iTerm2 行为。
2. 通过 Ghostty 官方 AppleScript 接口读取层级并执行 Terminal 操作。
3. 将 Ghostty 接入现有面板跟随、分组和权限提示。
4. 完成构建与静态检查，并列出需要用户运行 App 验证的交互。

## Result

- T1: 用户在当前源码构建中确认 Ghostty 面板跟随、Window/Tab/Terminal 层级与工作目录显示通过。
- T2: 用户确认 Window/Project Path 分组、Terminal 聚焦与临时 Terminal 关闭交互通过。
- T3: Debug 构建成功；iTerm2 Bridge 路径继续编译，Ghostty JSON 快照未提供 status、activityKind、exitStatus 或 statusChangedAt 字段。
- Review gate: Skipped — 用户未要求独立 Reviewer 审批。

## Verification

- Passed: 用户完成 Ghostty 运行时验收；Debug 构建、Swift 解析、Info.plist、diff 与 OSA 脚本编译检查均通过；按工作区规则未运行单元测试。
