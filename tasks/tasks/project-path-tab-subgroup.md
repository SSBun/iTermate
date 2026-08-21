# Project Path group mode shows Tab subgroups

Status: In Progress (2026-08-20 16:26)
Kind: Task

## Target
- [x] T1: In Project Path session list style, sessions of the same project path that live in the same terminal tab are rendered as a labeled, indented subgroup under the project path section
- [x] T2: Existing Window style Tab subsection behavior and settings remain unchanged
- [x] T3: Project Path tab subgroup title shows Tab N (position in its window) instead of the dynamic tab title
- [x] T4: Project Path group header shows a selection effect (accent tint) when a focused session belongs to that group
- [ ] T5: In Project Path mode, each Tab subgroup header is visibly indented relative to its project section title so their parent-child hierarchy is clear
- [ ] T6: 在 Project Path 模式启用 Tab 标题时，即使某个 Tab 在对应 Project Path 分组中只有一个 Session，也显示其 Tab 标题栏

## Scope

- 调整 Project Path 模式中的 Tab 子组标题缩进与单 Session Tab 的标题可见性。
- 不调整 Window 模式、会话行布局或现有折叠与菜单交互。

## Plan

1. 让 Project Path 模式对单 Session Tab 复用现有 Tab 标题栏，并保持既有标题与缩进样式。
2. 保持 Window 模式与现有折叠、菜单和会话行行为不变。
3. 执行不启动 App 的语法、编译与差异检查，并保留用户侧视觉复核项。

## Result

- T2: Window style path unchanged: tabHeaderSessions returns sessions for every tab in window mode, existing test testGroupsSessionsByWindowOrExactPath untouched and still compiles
- T3: tabSubgroupTitle(for:) in iTermateApp.swift returns 'Tab N' from window.tabs index in projectPath style; Window style still uses dynamic tabTitle; header text and accessibility label updated
- T4: groupHeader in iTermateApp.swift tints folder icon and title with accentColor when a focused session (isFocused from Bridge global current session) belongs to the group in projectPath style; custom color and Window style unchanged otherwise
- T1: PanelContent.tabHeaderSessions now returns every tab's sessions whenever Show Tab Headers is enabled, so the existing shared renderer labels and indents every Project Path tab subgroup.
- Review gate: Skipped — 用户未要求独立 Reviewer 审批。

## Verification

- Passed: swiftc -parse、Debug arm64 xcodebuild（CODE_SIGNING_ALLOWED=NO）与 git diff --check 均通过；iTermate 和 Bridge PID 前后未变化；未启动 App，视觉效果待用户复核。
