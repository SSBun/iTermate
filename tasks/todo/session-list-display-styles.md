# 按窗口或项目路径展示全部 Session

Status (2026-07-28 23:40): Completed

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

## Plan

1. 移除分组标题中容易被理解为 Window 数量的 Session 数字。
2. 将两种样式的 Session 行精简为仅显示标题。
3. 用真实 v2 快照验证 Window 与文件夹 section 层级、焦点和点击行为。

## Result

- T1：通过 iTerm2 Python API 对新 `Bridge.build_snapshot()` 做真实只读执行，观察到 1 个 Window、3 个 Tab、5 个 Session；每个 Session 的 `windowId`、`tabId` 和精确 `path` 与父层级一致。Layout/Focus monitor 保持即时推送，2 秒周期快照覆盖目录变化。
- T2：真实 Window 样式截图只显示一个 `Window` section，无数字计数；其下 8 行分别只显示 Session 标题。
- T3：真实 Project Path 样式截图按 babyfs、babyfs-ios、iTermComrade、Recall、skills 五个文件夹路径创建 section header，每个 section 下只列对应 Session 标题。
- T7：真实 v2 快照验证时为 1 Window、4 Tabs、9 Sessions，Window 列表逐一显示 9 个标题且没有数量歧义；焦点圆点仍正确显示，`store.activate(sessionID:)` 按钮动作保持不变。定向分组测试和完整 Xcode 测试均通过，16 个测试、0 失败；Swift parse 与 `git diff --check` 通过。
- T4：Accessibility 通过标题栏菜单在两种样式间切换；发现并修复 SwiftUI 行复用导致的动态切换陈旧详情，最终 Window→Project Path 即时正确刷新；偏好测试和重启检查确认样式持久化。
- T5：Accessibility 点击 `Recall (zsh)` 行后，mock socket 收到正确 v2 `activateSession` 与 Session ID；Python handler 聚焦测试通过。iTerm2 `Session.async_activate()` 默认同时选择父 Tab、聚焦 pane 并将 Window 置前。
- T6：协议与 Bridge 版本同步升级为 2；旧 v1 snapshot 仍可解码并显示“Restart iTerm2 to update the Bridge”。Python self-test/compile、Swift parse、`git diff --check` 和默认 Xcode 测试通过，共 16 个测试、0 失败；已安装 AutoLaunch 脚本与 App resource 一致。
- 运行时部署：仅热重启 Bridge helper，将真实 Socket 握手从 v1 切换到 v2；重启前后的 8 个 Session ID 完全一致，Socket 权限保持 `0600`。随后启动 App，实测收到 v2 快照：1 Window、4 Tabs、8 Sessions。
- Review gate: Required — 本次变更升级本地 IPC 协议并打破运行中 v1 Bridge 兼容性，且跨 Python/iTerm API、Swift 状态和 UI；真实 iTerm Session 激活动作未端到端执行以避免打断用户当前 pane。
- Review decision: `APPROVED` — 独立 Reviewer 全量检查后无有效 finding；[审查报告](../../reports/adversarial-review/session-list-display-styles.md)。
- Follow-up review gate: Skipped — 本次标题精简修正未请求独立对抗审查。
