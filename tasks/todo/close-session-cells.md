# 为 Session 单元格添加关闭按钮

Status (2026-07-30 22:04): Completed

## Scope

- 包含：在每个 Session 单元格中提供独立关闭操作，并通过现有 Bridge 关闭目标 iTerm Session。
- 不包含：强制关闭、批量关闭或自定义确认弹窗。
- 本次修正包含：消除指针已离开 Session 行后仍残留的关闭按钮。

## Target

- [x] T1：每个 Session 单元格显示可访问的关闭按钮，关闭操作不触发行激活，原有点击激活行为保持不变。
- [x] T2：关闭操作携带正确 Session ID，Bridge 使用 iTerm 原生非强制关闭并回传结果；失败信息仍显示在面板中。
- [x] T3：Swift/Python 协议版本保持同步，相关自动化检查与构建通过。
- [x] T4：关闭按钮默认不可见，指针悬停对应 Session 行时显示，移出后再次隐藏，其他行不会残留关闭按钮。
- [x] T5：面板只允许当前指针所在的 Session 行显示关闭按钮；指针离开该行或整个面板后立即隐藏。
- [x] T6：指针悬停关闭按钮本身时，在 `xmark` 后显示圆形反馈；离开按钮后圆形立即消失。

## Plan

1. 复用 `.activeAlways` tracking，为关闭按钮维护唯一的悬停 Session ID。
2. 仅在该 ID 匹配时于 `xmark` 后绘制圆形背景，并在按钮、行或面板离开时兜底清理。
3. 重建实际 App，验证圆形悬停反馈，再运行解析与完整测试。

## Result

- T1：Session 行拆为独立的激活按钮与尾部 `xmark` 关闭按钮；两者具有各自的 accessibility label，激活按钮继续占满关闭按钮之外的行宽。Swift 解析与完整 Xcode 构建通过。
- T2：App 发送带目标 Session ID 的 `closeSession`；Bridge 调用 `session.async_close()`，保留 iTerm 原生非强制确认，并沿用 `actionResult` 错误展示。Python self-test 使用 fake session 验证关闭调用、默认 `force == false` 与成功响应；为避免破坏用户工作，未实际关闭真实 Session。
- T3：协议与 Bridge 同步升级到 v5，Pi/Codex 分发资源同步更新；Bridge 仅为已安装的旧 integration 保留 v4 `setSessionStatus` 兼容。系统 Python 与 iTerm Python 3.14 self-test、`py_compile`、Swift parse、`git diff --check` 均通过；完整 Xcode 测试 29/29 通过。
- T4：根因是 `.nonactivatingPanel` 中 SwiftUI `.onHover` 不能提供可靠的后台逐行 tracking，且全局焦点状态会让其他行残留按钮。现改为每行本地 hover 状态与覆盖整行的 `.activeAlways` AppKit tracking area。实际重启构建产物后，窗口截图验证：默认无关闭按钮；悬停 `native-short-reader · close button visibility (pi)` 时仅该行显示；移至 `Recall · list github projects (pi)` 时按钮随行移动；移出面板后全部隐藏。Swift parse、`git diff --check` 与完整 Xcode 测试通过，29/29 成功。
- T5：残留根因是各行独立保存 hover 布尔值，tracking exit 一旦遗漏就无法由其他行或面板清理。现由面板保存唯一 `hoveredSessionID`，行进入时替换、匹配行离开时清空、离开整个面板时无条件清空；隐藏按钮同时禁用鼠标命中。重启新构建后截图验证：面板外无关闭按钮；悬停 `iTermComrade · hover show close button (pi)` 时仅该行出现 `xmark`；再次移出面板后全部隐藏。Swift parse、`git diff --check` 与完整 Xcode 测试通过，32/32 成功。
- T6：面板新增唯一 `hoveredCloseButtonSessionID`，关闭按钮用 `.activeAlways` tracking 更新该状态，匹配时在 `xmark` 后绘制 22pt 的圆形背景；按钮、行或面板离开时均清理。Swift parse、Debug build 与完整 Xcode 测试通过，32/32 成功；用户确认悬停效果已完成。
- Review gate: Skipped — no explicit user request.
