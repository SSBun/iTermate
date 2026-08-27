# 添加 Statistics 设置标签页

Status: Completed (2026-08-27 14:08)
Kind: Task

## Target
- [x] T1: Settings 新增 Statistics 标签页，以汇总数字展示成功 Agent 工作轮次的 Total、当前自然月、当前本地日历周与当天完成次数。
- [x] T2: 现有设置标签页、状态菜单统计与 Session 行为保持正常。
- [x] T3: 状态菜单以当天成功完成次数作为主要高亮数字，正在运行的 Agent 数量降为次要信息。

## Scope

- 仅统计 Agent 从 Running 进入 Finished 且退出码为 `0` 的工作轮次。
- 仅展示四个汇总数字，不增加记录列表、图表、数据库或新依赖。
- 迁移现有当天完成次数，避免升级后统计归零。

## Plan

- [x] P1: 将单日计数持久化升级为每日聚合数据，并计算总计、本月、本周与当天汇总。
- [x] P2: 在 Settings 中加入原生分组表单风格的 Statistics 标签页。
- [x] P3: 执行语法、构建与差异检查，确认现有行为未受影响。
- [x] P4: 调整状态菜单统计区的视觉层级并重新验证构建。

## Decisions

- D1: 使用每日聚合桶存储，而不是维护四套周期计数器或保存逐条完成记录。
- D2: Statistics 使用一个原生分组表单，按 Total、This Month、This Week、Today 顺序展示。
- D3: 状态菜单的大号主数字改为 Today 完成次数，Running 作为下方次要标签展示。

## Result

- T1: Statistics 标签页已接入共享 ItermStore，展示 Total、This Month、This Week、Today；每日聚合数据持久化并迁移旧当天计数。
- T2: 保留现有完成事件口径及 completedAgentTurnsToday 接口；Swift 语法检查、git diff --check 与 arm64 Debug 构建通过。
- T3: 状态菜单已将 Today 完成次数改为 40pt 主数字与强调色，Running Agent 数量改为下方次要标签。
- Review gate: Skipped — 用户未要求独立 Reviewer；已核对视觉层级、未知 Running 状态与单复数文案。

## Verification

- Passed: SettingsViews.swift 语法检查、git diff --check 与 arm64 Debug xcodebuild 均通过；按规则未启动或重启 iTermate，未运行测试套件。
