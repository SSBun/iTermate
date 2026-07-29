# 实现跟随 iTerm 窗口的浮动面板

Status (2026-07-29 14:15): Completed

## Scope

- 包含：创建可运行的原生 macOS App，让浮动面板跟随当前 iTerm 窗口移动和缩放，由面板接收点击，并允许用户拖动边缘调整及保存面板宽度。
- 不包含：自由调整面板高度、设置页面或自定义拖拽控件。

## Target

- [x] T1：应用启动后，在当前前台 iTerm 窗口旁显示非激活浮动面板。
- [x] T2：iTerm 窗口移动或缩放时，面板位置与高度随之更新；iTerm 不是前台应用或没有可见窗口时隐藏。
- [x] T3：项目可由 Xcode 构建，面板布局检查通过。
- [x] T4：点击面板覆盖区域时，事件由面板接收而不是穿透到下方应用。
- [x] T5：用户可拖动面板边缘，将宽度限制在 180–600pt；高度仍匹配 iTerm 窗口。
- [x] T6：结束拖动后保存宽度，应用重新启动时恢复上次宽度。
- [x] T7：宽度变化时面板仍保持 8pt 间距、自动选择左右侧且不超出可见屏幕。
- [x] T8：iTerm 窗口仍可见但其他应用置前时面板隐藏；切回 iTerm 后面板恢复。
- [x] T9：光标悬停在面板左右边缘时显示水平调整光标，并与原生宽度拖拽一致。
- [x] T10：前台判断不依赖 Accessibility 权限，且不改变面板跟随、点击、调整宽度和 Session 状态行为。
- [x] T11：iTerm2 的模态退出提示窗口出现时，面板仍跟随主 iTerm 窗口，而不是提示窗口。
- [x] T12：光标悬停在面板左右边缘的实际可命中区域时，显示水平双向调整光标。

## Plan

1. 复现面板边缘悬停时光标不变的问题，并确认当前 AppKit 光标矩形的生命周期和命中范围。
2. 只调整面板边缘的光标处理，保留原生 `.resizable`、宽度限制和拖拽行为。
3. 增加可重复的回归检查，运行相关构建与测试。

## Result

- T1：运行构建产物后，通过 Core Graphics 窗口快照确认 `iTermComrade` 浮动层与前台 iTerm 窗口保持 8pt 间距；面板为不激活的 `NSPanel`。
- T2/T8：`ItermWindow.frontmost()` 现在同时要求 iTerm 的 `NSRunningApplication.isActive` 为真。真实前台切换验证：iTerm2 前台时面板 `visible`，Google Chrome 或 Finder 前台时为 `hidden`，切回 iTerm2 后恢复 `visible`。
- T10：前台判断使用 AppKit `NSRunningApplication.isActive` 与原有 Core Graphics 可见窗口查询，不引入 Accessibility 权限；完整 Xcode 测试 17 个全部通过，Swift parse 与 `git diff --check` 通过。
- T9/T12：非激活浮动面板改用左右各 8pt 的 `NSTrackingArea`，选项包含 `.activeAlways`；进入或移动时设置 `NSCursor.resizeLeftRight`，离开时恢复箭头，且保留原生 `.resizable` 拖拽。回归测试先复现原实现的 0 个边缘 tracking area，修复后通过；完整 Xcode 测试共 25 个全部通过。
- T3：`xcodebuild ... build test` 构建成功，4 个布局与面板行为测试全部通过；`swiftc -parse iTermComrade/*.swift` 通过；构建产物的 `LSUIElement` 为 `true`。
- T4：删除 `ignoresMouseEvents = true`，聚焦测试确认运行时属性为 `false`，面板不再把点击传递给下方应用。
- T5：真实鼠标事件把运行中面板从 260pt 拖至 360pt，窗口高度保持 1662pt；测试确认原生 `.resizable` 和 180–600pt 限制。
- T6：结束真实拖动后 `UserDefaults` 保存 360pt；终止并重新启动 App 后 Core Graphics 窗口快照恢复为 360pt，验证后已清理测试偏好。
- T7：重启后的面板与 iTerm 高度一致且保持 8pt 间距；动态宽度和宽度触发左右切换的布局测试通过。
- `xcodebuild ... test` 运行 12 个测试全部通过，`swiftc -parse iTermComrade/*.swift` 与 `git diff --check` 通过。
- Review gate: Skipped — 不涉及关键风险；宽度约束、持久化、布局切换均有确定性测试，原生拖动和重启恢复另经真实运行验证。
- Follow-up review gate: Skipped — no explicit user request。
- T11：根因是 `ItermWindow.frontmost()` 按 Core Graphics 返回顺序直接采用了 iTerm2 的模态退出提示窗口。现在收集所有可见的 layer-0 iTerm 窗口并选择面积最大的主窗口；新增 `testItermWindowSelectionIgnoresSmallerModalAlert` 回归测试通过。App build、Swift parse、`git diff --check` 通过；将未跟踪的 `AgentIntegrationManagerTests.swift` 临时替换为空测试后，完整其余测试通过并已恢复原文件哈希。正常全量测试仍被该未跟踪文件自身的 `escaping closure captures mutating 'self' parameter` 编译错误阻塞。
- Review gate: Skipped — 用户未要求独立审查；这是局部窗口选择修复，不涉及关键风险，回归测试和构建验证已覆盖核心行为。
- Frontmost visibility review gate: Skipped — 本次前台可见性修正未请求独立对抗审查。
- Cursor follow-up review gate: Skipped — 用户未请求独立对抗审查。
