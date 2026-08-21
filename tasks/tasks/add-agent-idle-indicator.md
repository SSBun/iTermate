# 添加低干扰 Agent 空闲状态图标

Status: In Progress (2026-08-21 13:00)
Kind: Task

## Scope

- Bridge 显式保留由 Agent lifecycle 确认的 idle 状态；不根据 Session 名称或进程猜测。
- Agent idle 使用现有像素角色的低透明度静止帧与说明，不加入状态动画设置。
- 保留完成状态直至用户重新激活 Session；普通命令及 Agent 的运行、成功、失败反馈不变。

## Target

- [ ] T1: 等待用户输入的 Agent Session 显示低干扰的静态空闲状态图标与说明
- [x] T2: 空闲状态不持续动画，现有运行、完成及普通命令状态反馈保持不变

## Plan

1. 由用户重新构建并运行 App，确认 Agent idle 图标的实际视觉与状态切换。

## Result

- T2: idle 使用 animates=false 的 30% secondary 静止像素帧；现有 SessionStatusAnimation 七种状态与普通命令路径未改动
- Review gate: Skipped — 用户未要求独立 Reviewer 审批

## Verification

- Passed: Debug xcodebuild、Python py_compile 与 git diff --check 通过；未启动 App，未执行测试，视觉效果待用户确认
