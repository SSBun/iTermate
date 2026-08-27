# 实现状态菜单重设计

Status: Completed (2026-08-27 10:52)
Kind: Task

## Scope

- 实现状态菜单、跨终端 Agent 汇总、当日成功完成计数持久化，以及收藏项目的 iTerm2 定位或新建操作。
- 不改变浮动面板、收藏管理入口、Ghostty 项目打开行为或用户安装态。

## Target
- [x] T1: 状态菜单以 Live-first 布局展示 iTerm2 与 Ghostty 中当前运行的 Agent Session 总数，以及本地当天成功完成的 Agent 工作轮次，并在状态未知时避免显示误导性零值。
- [x] T2: 状态菜单按标题列出收藏项目的单行 Cell，左侧为标题、右侧为路径；点击时精确路径已有 Session 则聚焦快照首项，否则在 iTerm2 当前窗口新建以该路径为工作目录的 Tab，无窗口时创建窗口。
- [x] T3: 收藏空状态、长列表滚动、动作失败反馈、Settings 与 Quit 均可用，现有收藏管理与浮动面板行为保持不变。

## Plan

1. 在现有 Store 中汇总两个终端的可靠 Agent 状态，并复用完成转换跟踪持久化本地当日成功次数。
2. 扩展现有 iTerm2 Bridge 动作通路，使收藏路径可激活首个精确匹配 Session 或创建指定初始目录的新 Tab。
3. 按已确认的 Live-first 层级重写状态菜单，并接入空状态、滚动、成功关闭与失败提示。
4. 运行不启动 App 的 Swift/Python 语法检查和 macOS 构建，核对差异后交由用户进行真实交互验证。

## Decisions

- 复用现有 AppSettings 收藏数据、SessionCompletionTracker、ItermStore 双后端缓存和 Bridge actionResult，不新增数据库、收藏模型或独立服务。
- 完成次数使用 UserDefaults 保存“本地日开始时间 + 计数”，不写入用户偏好配置文件。
- 不递增 Bridge 协议版本；App 自管 Bridge 生命周期保证两端源码同步。
- 收藏项目点击由 Bridge 按 Window、Tab、Session 当前顺序读取动态路径并原子决定“激活首个精确匹配项或创建”，避免依赖陈旧 Swift 快照产生重复 Tab。

## Result

- T1: 用户运行截图显示 Connected、1 个 Agents Running 与今日完成指标；用户随后确认 Agent 完成计数行为全部通过。
- T2: 运行截图显示左标题右路径的收藏 Cell；用户确认已有 Session 定位与无匹配时按正确目录新建 Tab 均通过。
- T3: 运行截图确认收藏区与 Settings/Quit 布局；源码核对覆盖空状态、五项以上滚动和失败提示，既有面板与收藏管理未改。
- Review gate: Skipped — 用户未请求独立对抗审查或 Reviewer 审批。

## Verification

- Passed: Swift parse、Python py_compile、git diff --check、arm64 macOS Debug build 与 bundle Bridge 一致性均通过；用户提供真实截图并确认交互全部通过。
