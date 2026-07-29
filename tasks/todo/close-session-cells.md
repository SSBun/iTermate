# 为 Session 单元格添加关闭按钮

Status (2026-07-29 23:49): Completed

## Scope

- 包含：在每个 Session 单元格中提供独立关闭操作，并通过现有 Bridge 关闭目标 iTerm Session。
- 不包含：强制关闭、批量关闭或自定义确认弹窗。

## Target

- [x] T1：每个 Session 单元格显示可访问的关闭按钮，关闭操作不触发行激活，原有点击激活行为保持不变。
- [x] T2：关闭操作携带正确 Session ID，Bridge 使用 iTerm 原生非强制关闭并回传结果；失败信息仍显示在面板中。
- [x] T3：Swift/Python 协议版本保持同步，相关自动化检查与构建通过。

## Plan

1. 扩展现有 Session 动作协议与 Bridge 处理路径。
2. 将关闭操作作为 Session 行中的独立控件接入。
3. 运行协议自检、Swift 测试与构建验证。

## Result

- T1：Session 行拆为独立的激活按钮与尾部 `xmark` 关闭按钮；两者具有各自的 accessibility label，激活按钮继续占满关闭按钮之外的行宽。Swift 解析与完整 Xcode 构建通过。
- T2：App 发送带目标 Session ID 的 `closeSession`；Bridge 调用 `session.async_close()`，保留 iTerm 原生非强制确认，并沿用 `actionResult` 错误展示。Python self-test 使用 fake session 验证关闭调用、默认 `force == false` 与成功响应；为避免破坏用户工作，未实际关闭真实 Session。
- T3：协议与 Bridge 同步升级到 v5，Pi/Codex 分发资源同步更新；Bridge 仅为已安装的旧 integration 保留 v4 `setSessionStatus` 兼容。系统 Python 与 iTerm Python 3.14 self-test、`py_compile`、Swift parse、`git diff --check` 均通过；完整 Xcode 测试 29/29 通过。
- Review gate: Skipped — no explicit user request.
