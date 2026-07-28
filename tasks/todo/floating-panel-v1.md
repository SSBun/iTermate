# 实现跟随 iTerm 窗口的浮动面板

Status (2026-07-28 16:38): Completed

## Scope

- 包含：创建可运行的原生 macOS App，让浮动面板跟随当前 iTerm 窗口移动和缩放，由面板接收点击，并允许用户拖动边缘调整及保存面板宽度。
- 不包含：自由调整面板高度、设置页面或自定义拖拽控件。

## Target

- [x] T1：应用启动后，在当前前台 iTerm 窗口旁显示非激活浮动面板。
- [x] T2：iTerm 窗口移动或缩放时，面板位置与高度随之更新；iTerm 不在前台或没有可见窗口时隐藏。
- [x] T3：项目可由 Xcode 构建，面板布局检查通过。
- [x] T4：点击面板覆盖区域时，事件由面板接收而不是穿透到下方应用。
- [x] T5：用户可拖动面板边缘，将宽度限制在 180–600pt；高度仍匹配 iTerm 窗口。
- [x] T6：结束拖动后保存宽度，应用重新启动时恢复上次宽度。
- [x] T7：宽度变化时面板仍保持 8pt 间距、自动选择左右侧且不超出可见屏幕。

## Plan

1. 让布局接受当前面板宽度并保持原有贴靠规则。
2. 启用原生水平边缘拖拽并保存、恢复宽度。
3. 添加持久化、宽度约束和动态布局验证，并运行真实面板检查。

## Result

- T1：运行构建产物后，通过 Core Graphics 窗口快照确认 `iTermComrade` 浮动层与前台 iTerm 窗口保持 8pt 间距；面板为不激活的 `NSPanel`。
- T2：自动修改 iTerm 窗口位置和尺寸后，检查确认面板的横向位置、顶部和高度同步更新；切换到 Finder 后检查确认面板隐藏。
- T3：`xcodebuild ... build test` 构建成功，4 个布局与面板行为测试全部通过；`swiftc -parse iTermComrade/*.swift` 通过；构建产物的 `LSUIElement` 为 `true`。
- T4：删除 `ignoresMouseEvents = true`，聚焦测试确认运行时属性为 `false`，面板不再把点击传递给下方应用。
- T5：真实鼠标事件把运行中面板从 260pt 拖至 360pt，窗口高度保持 1662pt；测试确认原生 `.resizable` 和 180–600pt 限制。
- T6：结束真实拖动后 `UserDefaults` 保存 360pt；终止并重新启动 App 后 Core Graphics 窗口快照恢复为 360pt，验证后已清理测试偏好。
- T7：重启后的面板与 iTerm 高度一致且保持 8pt 间距；动态宽度和宽度触发左右切换的布局测试通过。
- `xcodebuild ... test` 运行 12 个测试全部通过，`swiftc -parse iTermComrade/*.swift` 与 `git diff --check` 通过。
- Review gate: Skipped — 不涉及关键风险；宽度约束、持久化、布局切换均有确定性测试，原生拖动和重启恢复另经真实运行验证。
