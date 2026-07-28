# 实现跟随 iTerm 窗口的浮动面板

Status (2026-07-28 13:15): Completed

## Scope

- 包含：创建可运行的原生 macOS App，让浮动面板跟随当前 iTerm 窗口移动和缩放，并由面板接收其覆盖区域内的点击。
- 不包含：Session 列表、Session 状态和具体点击操作。

## Target

- [x] T1：应用启动后，在当前前台 iTerm 窗口旁显示非激活浮动面板。
- [x] T2：iTerm 窗口移动或缩放时，面板位置与高度随之更新；iTerm 不在前台或没有可见窗口时隐藏。
- [x] T3：项目可由 Xcode 构建，面板布局检查通过。
- [x] T4：点击面板覆盖区域时，事件由面板接收而不是穿透到下方应用。

## Plan

1. 建立最小 macOS App 工程和浮动面板。
2. 读取前台 iTerm 窗口边界并持续同步面板布局。
3. 添加布局验证并运行构建与行为检查。
4. 关闭面板点击穿透并验证鼠标命中行为。

## Result

- T1：运行构建产物后，通过 Core Graphics 窗口快照确认 `iTermComrade` 浮动层与前台 iTerm 窗口保持 8pt 间距；面板为不激活的 `NSPanel`。
- T2：自动修改 iTerm 窗口位置和尺寸后，检查确认面板的横向位置、顶部和高度同步更新；切换到 Finder 后检查确认面板隐藏。
- T3：`xcodebuild ... build test` 构建成功，4 个布局与面板行为测试全部通过；`swiftc -parse iTermComrade/*.swift` 通过；构建产物的 `LSUIElement` 为 `true`。
- T4：删除 `ignoresMouseEvents = true`，聚焦测试确认运行时属性为 `false`，面板不再把点击传递给下方应用。
- Review gate: Skipped — 未涉及关键风险，点击命中修复由聚焦回归测试和完整测试直接验证。
