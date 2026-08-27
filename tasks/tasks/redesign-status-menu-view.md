# 重新设计状态菜单视图

Status: Completed (2026-08-26 17:07)
Kind: Task

## Scope

- 包含菜单栏弹出视图的 Agent 统计、收藏项目列表、信息层级、视觉方向与项目点击交互设计。
- 本轮不修改实现代码，也不默认创建独立设计文档。

## Target
- [x] T1: 形成并由用户确认一套可指导后续实现的状态菜单视图重设计方案：展示当前运行中的 Agent Session 数、今日 Agent 完成轮次及用户收藏项目；点击收藏项目时，已有对应 Session 则定位首个 Session，否则新建 iTerm2 Session。

## Plan

1. 明确菜单的首要用途、使用频率与内容约束。
2. 比较两到三种重设计方向及其取舍，并确定推荐方向。
3. 分段确认最终设计及关键状态。

## Decisions

- 首要信息是当前正在工作的 Agent Session 数，只统计 Agent activity 的 Running 状态。
- 完成指标统计 Agent 工作轮次的结束事件，而非业务任务或当前 Finished Session 数。
- 完成次数按本地自然日统计并显示“今天”。
- 采用 Live-first 主指标布局：Running Agents 为视觉中心，Completed Today 为次级指标，连接状态降为标题栏辅助信息；移除 Windows 与 Tabs 统计。
- 菜单增加用户收藏项目列表；复用现有持久化收藏项目数据，不另建收藏体系。
- 点击收藏项目时，已有对应 Session 则定位列表中的首个 Session；否则在前台 iTerm2 窗口的新 Tab 中创建 Session，无窗口时新建窗口。
- 收藏项目使用单行简单 Cell：左侧显示项目标题，右侧显示项目路径；不显示运行中 Session 数量。
- 只有 Session 当前目录与收藏项目路径完全相同时，才视为该项目的已打开 Session。
- 同一路径存在多个 Session 时，按当前 Window、Tab、Session 快照顺序定位首个匹配项。
- 收藏项目按标题稳定排序；操作成功后关闭菜单并聚焦目标，失败时保持菜单打开并显示简短错误，不自动改为创建 Session。
- iTerm2 未运行或没有窗口时，点击无现存 Session 的收藏项目会启动 iTerm2 并创建窗口；连接断开时实时 Agent 数显示未知而非零。
- Agent 统计汇总 iTerm2 与 Ghostty 两个数据源中可确认的状态；收藏项目的定位和创建仍固定使用 iTerm2。
- Completed Today 仅累计从 Agent Running 转为 Finished 且退出状态为 0 的成功工作轮次；失败轮次不计入。
- ItermStore 统一拥有跨 iTerm2 与 Ghostty 的 Agent 汇总和收藏项目动作路由，StatusMenuView 只负责展示与触发。
- 今日完成数持久化为本地日期与计数，跨自然日归零；首次快照只建立基线，重复 Finished 快照不重复累计，也不回溯 App 未运行期间的事件。
- 菜单保持系统弹出材质：顶部为品牌与紧凑连接状态，中部为 Running Agents 主指标和 Completed Today 次指标，随后为收藏列表，底部保留 Settings 与 Quit。
- 收藏列表过长时仅列表滚动；路径单行中间截断。无收藏时显示简短空状态，收藏管理继续使用现有项目上下文菜单。
- 后续实现需验证跨终端统计去重、自然日重置、精确路径与首项选择、新建 Tab 工作目录、失败反馈、长路径及 Light/Dark Mode；真实 App 由用户自行启动验证。

## Result

- T1: 用户已逐段确认视觉层级、收藏项目交互、跨终端统计与数据归属、异常状态及验证边界；设计决策已完整记录。
- Review gate: Skipped — 用户未请求独立对抗审查或 Reviewer 审批。

## Verification

- Passed: 对照确认记录核验：Running Agents、Completed Today、收藏 Cell、精确路径首项定位、新建 iTerm2 Tab、失败反馈与验证边界均有明确且一致的可观察定义。
