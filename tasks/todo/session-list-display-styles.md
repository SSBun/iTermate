# 按窗口或项目路径展示全部 Session

Status (2026-07-30 01:19): Completed

## Scope

- 包含：观察每个 iTerm Session 及其父 Window/Tab、同步当前目录、按 Window 或精确当前目录分组展示，并允许点击聚焦 Session。
- 不包含：还原横向/纵向 Splitter 树、按 Git 仓库根目录归组、Session 创建/关闭/拆分或 Screen Streaming。

## Target

- [x] T1：Bridge 快照包含所有 Session、当前目录和其 Window/Tab 父级关系，并随 Layout、Focus 和目录变化更新。
- [x] T2：Window 样式每个真实 Window 只显示一个无歧义的分组标题，其下各行仅显示 Session 标题。
- [x] T3：Project Path 样式以文件夹路径作为 section header，其下各行仅显示在该目录工作的 Session 标题。
- [x] T4：面板提供显示样式菜单并跨启动保存上次选择。
- [x] T5：点击任一 Session 行可选中父 Tab、聚焦对应 pane 并将其 Window 置前。
- [x] T6：协议、模型、分组和动作验证通过，现有 Tab/设置/面板行为不回归。
- [x] T7：精简显示后仍逐一呈现真实快照中的所有 Session，并保留焦点标记和点击激活。
- [x] T8：Window 样式为每个 Tab 显示弱化的小节标题，并将其 Session 缩进列在下方，不使用裸分隔线。
- [x] T9：Basic Settings 提供默认开启的 Tab 标题复选框，修改后面板即时更新并跨启动保存。
- [x] T10：标题栏配置菜单按 Group By、Display、Sections 分区，包含现有分组选择、Tab 标题开关与全部展开/折叠操作。
- [x] T11：Window、Tab 与 Project Path 小节标题支持点击展开/折叠，折叠仅影响当前运行时显示且不丢失 Session。
- [x] T12：标题栏配置菜单的每个可操作项显示与语义匹配的左侧图标，分组选择仍显示独立选中标记。
- [x] T13：iTerm Session 标题变化后，Bridge 在下一次周期快照中发布新标题，面板无需重启即可更新。
- [x] T14：Session 行垂直间距收紧，同时增大 Window/Tab/Project Path 小节之间的垂直留白。
- [x] T15：同一份 Bridge 快照在面板中最多标记一个当前聚焦 Session。
- [x] T16：当前聚焦状态变化后，旧 Session 行不会保留蓝色焦点标记。

## Plan

1. 让 Session 行的 SwiftUI 身份随聚焦状态变化刷新，避免 LazyVStack 保留旧行内容。
2. 通过连续切换 Session 验证 Bridge 快照与面板始终只有一个聚焦行。

## Result

- T1：通过 iTerm2 Python API 对新 `Bridge.build_snapshot()` 做真实只读执行，观察到 1 个 Window、3 个 Tab、5 个 Session；每个 Session 的 `windowId`、`tabId` 和精确 `path` 与父层级一致。Layout/Focus monitor 保持即时推送，2 秒周期快照覆盖目录变化。
- T2：真实 Window 样式截图只显示一个 `Window` section，无数字计数；其下 8 行分别只显示 Session 标题。
- T3：真实 Project Path 样式截图按 babyfs、babyfs-ios、iTermComrade、Recall、skills 五个文件夹路径创建 section header，每个 section 下只列对应 Session 标题。
- T7：真实 v2 快照验证时为 1 Window、4 Tabs、9 Sessions，Window 列表逐一显示 9 个标题且没有数量歧义；焦点圆点仍正确显示，`store.activate(sessionID:)` 按钮动作保持不变。定向分组测试和完整 Xcode 测试均通过，16 个测试、0 失败；Swift parse 与 `git diff --check` 通过。
- T8：真实 Window 样式为 4 个 Tab 分别显示弱化图标与 Tab 标题，Session 缩进排列在对应标题下；同一 Tab 的多个 Session 保持连续，不再显示裸分隔线。Project Path 样式不显示 Tab 标题。
- T9：Basic Settings 运行截图确认 `Show tab headers in Window view` 原生复选框默认选中；关闭并重启后 Tab 标题与缩进消失，重新开启后恢复。设置持久化单测通过。
- T8/T9：定向 2 个测试和完整 Xcode 测试通过，共 17 个测试、0 失败；Swift parse 与 `git diff --check` 通过。
- T10：运行截图确认配置菜单按 Group By、Display、Sections 分区，Window/Project Path、Show Tab Headers、Expand All/Collapse All 均可直接操作；AX 实际切换 Tab 标题后持久化值同步变化。
- T11：AX 逐项验证 Window 标题、单个 Tab 标题可折叠并重新展开；Project Path 的 5 个路径小节可由 Collapse All 一次折叠，Expand All 可恢复。折叠仅改变 `@State` 中的显示状态，Bridge 快照和 Session 激活动作未改变。
- T10/T11：定向 2 个测试和完整 Xcode 测试通过，共 17 个测试、0 失败；Swift parse 与 `git diff --check` 通过。
- T12：运行截图确认 Window 使用窗口图标、Project Path 使用文件夹图标、Show Tab Headers 使用 Tab 图标，Expand All/Collapse All 保留展开与折叠图标；原生 Picker 继续显示当前分组选中标记。AX 实际切换 Project Path→Window 后持久化值正确更新。完整 Xcode 测试通过，共 17 个测试、0 失败；Swift parse 与 `git diff --check` 通过。
- T13：Bridge 周期快照改为通过 `session.async_get_variable("name")` 读取当前标题，失败或为空时回退 `session.name`，Tab 回退标题复用同一动态值。Python self-test 使用 `Cached title` 与 `Current title` 验证动态值胜出；编译通过。热重启 Bridge 后 9 个 Session ID 全部保留，实时快照标题与 iTerm 动态 `name` 变量 9/9 一致，面板截图显示最新 `dashboard API`、`config path`、`REFRESH_LOGIC` 等标题，无需重启 App。
- T13 verification note：完整 Xcode 测试在编译阶段被并行、无关的未完成修改阻塞：`AgentIntegrations.swift:300` 的 ShapeStyle 类型错误及 `AgentIntegrationManagerTests.swift:97` 的 escaping closure 捕获 mutating self；本次 Python Bridge 改动的 self-test、py_compile、`git diff --check`、热部署和真实运行验证均通过，未修改上述无关文件。
- T4：Accessibility 通过标题栏菜单在两种样式间切换；发现并修复 SwiftUI 行复用导致的动态切换陈旧详情，最终 Window→Project Path 即时正确刷新；偏好测试和重启检查确认样式持久化。
- T5：Accessibility 点击 `Recall (zsh)` 行后，mock socket 收到正确 v2 `activateSession` 与 Session ID；Python handler 聚焦测试通过。iTerm2 `Session.async_activate()` 默认同时选择父 Tab、聚焦 pane 并将 Window 置前。
- T6：协议与 Bridge 版本同步升级为 2；旧 v1 snapshot 仍可解码并显示“Restart iTerm2 to update the Bridge”。Python self-test/compile、Swift parse、`git diff --check` 和默认 Xcode 测试通过，共 16 个测试、0 失败；已安装 AutoLaunch 脚本与 App resource 一致。
- 运行时部署：仅热重启 Bridge helper，将真实 Socket 握手从 v1 切换到 v2；重启前后的 8 个 Session ID 完全一致，Socket 权限保持 `0600`。随后启动 App，实测收到 v2 快照：1 Window、4 Tabs、8 Sessions。
- Review gate: Required — 本次变更升级本地 IPC 协议并打破运行中 v1 Bridge 兼容性，且跨 Python/iTerm API、Swift 状态和 UI；真实 iTerm Session 激活动作未端到端执行以避免打断用户当前 pane。
- Review decision: `APPROVED` — 独立 Reviewer 全量检查后无有效 finding；[审查报告](../../reports/adversarial-review/session-list-display-styles.md)。
- Follow-up review gate: Skipped — 本次标题精简修正未请求独立对抗审查。
- Tab divider review gate: Skipped — 本次 Tab 小节样式与设置修正未请求独立对抗审查。
- Section folding review gate: Skipped — 本次配置菜单扩展与折叠功能未请求独立对抗审查。
- Menu icon review gate: Skipped — 本次菜单图标调整未请求独立对抗审查。
- Session title refresh review gate: Skipped — 本次动态标题修正未请求独立对抗审查。
- T14：Session 行垂直 padding 从 7pt 收紧到 5pt，列表元素 spacing 从 6pt 收紧到 2pt；Window/Project Path 与 Tab 标题的顶部留白统一增至 10pt。运行构建产物并裁切实际面板截图，确认同组 Session 更紧凑、相邻 section 边界更明显；Swift parse、`git diff --check` 与完整 Xcode 测试通过，25/25 测试成功。
- Cell spacing review gate: Skipped — no explicit user request.
- T15：Bridge 快照改为从当前 Window 的当前 Tab 读取唯一全局当前 Session ID，不再把每个 Tab 的局部 `current_session` 都标记为 active；Python self-test、`py_compile` 与 Xcode 测试（29/29）通过。重启运行中的 Bridge 后 Socket 握手为 v5，连续 4 份真实快照的聚焦候选数均为 1；重建并重启 App 后实测面板只显示一个蓝色聚焦行。
- Focus uniqueness review gate: Skipped — no explicit user request.
- T16：Session 行身份加入 `item.isFocused`，令 LazyVStack 在焦点变化时重建受影响行。真实 Bridge 激活后又发生后续 Session 切换，运行中面板截图始终只显示最新 Session 的一个蓝色焦点行，先前的 `Sparkle integration` 与 `session time settings` 行均未残留；全新 Derived Data 的完整 Xcode 测试通过，31/31 成功。
- Focus refresh review gate: Skipped — no explicit user request.
