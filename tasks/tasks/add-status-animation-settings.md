# 添加状态动画设置标签页

Status: In Progress (2026-08-21 10:31)
Kind: Task

## Scope

- Agent Running、Agent Success、Agent Failed，以及普通 Shell 的 Running、Success、Failed、Finished（未知退出码）分别拥有独立的动画样式和动画颜色配置。
- 所有状态均可选择 Alien、Robot 或 Classic；Classic 按结果显示 Running `^_` 闪烁、Success/Finished `^_^` 轻微脉冲、Failed `x_x` 闪烁。
- 每个状态在设置页显示使用其当前样式、结果模式与颜色的实时小型动画预览。
- 每项颜色可独立选择；默认值保持现有语义色：Agent Working 紫色、Command Running 橙色、成功绿色、失败红色、Command Finished 蓝色。
- 默认样式保持 Agent 使用 Alien、Command 使用 Robot；不提供全局颜色覆盖，不改变 Session 状态判定、状态文案或降低动态效果时停止动画的行为。

## Target

- [ ] T1: 状态动画设置标签页分别为 Agent 与普通 Shell 的 Running、Success、Failed，以及 Shell Finished（未知退出码）提供动画样式和动画颜色配置。
- [ ] T2: Alien、Robot、Classic 均可用于任一状态；Classic 分别呈现 Running `^_`、Success/Finished `^_^`、Failed `x_x` 动画。
- [ ] T3: 每个状态显示使用其当前样式、结果模式与颜色的实时小型动画预览。
- [ ] T4: 每项配置只影响对应状态并在重启后保留；默认显示、Session 状态判定与状态文案保持不变。

## Plan

1. 用户自行重新构建并运行 App，确认七行独立配置、实时预览及 Classic 三种结果模式的实际视觉。
2. 重启 App 后确认各状态的样式与颜色仍分别保留，再记录目标证据并完成任务。

## Result

- Review gate: Skipped — 用户未要求独立 Reviewer 审批。

## Verification

- Passed: Swift 解析、Debug build-for-testing 与 git diff --check 均通过；测试未执行，App 未启动，实际预览与重启持久化待用户确认。
