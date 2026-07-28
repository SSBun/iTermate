# 建立 iTerm Python Bridge 并显示全部 Tab

Status (2026-07-28 14:32): Completed

## Scope

- 包含：安装和启动 iTerm2 AutoLaunch Python Bridge，通过本地 Unix Socket 同步 Window、Tab、Session 层级与焦点变化，在原生面板中按窗口展示并激活 Tab。
- 不包含：Prompt/命令状态、Screen Streaming、发送文本、创建/关闭/拆分会话及 Session 状态展示。

## Target

- [x] T1：App 能从 bundle 安装版本化 Bridge，并在 iTerm 已运行时启动它且不会产生重复 daemon。
- [x] T2：Bridge 通过受当前用户保护的版本化 Unix Socket 提供全量 Window/Tab/Session 快照，并在布局或焦点变化后推送更新。
- [x] T3：面板按窗口显示全部 Tab、选中状态和 Session 数量，并随 Bridge 更新。
- [x] T4：点击 Tab 能激活对应 iTerm Tab，点击不会穿透面板。
- [x] T5：Bridge 不可用、权限失败或断开时，面板显示连接状态并自动重连。
- [x] T6：Swift、Python 和真实 iTerm 集成检查通过，原有窗口跟随行为保持有效。

## Plan

1. 明确 Bridge 生命周期、协议和本地 iTerm Python API 的实际能力。
2. 实现并验证 Python daemon 的快照、事件和激活动作。
3. 实现 Swift 安装、启动、Socket 客户端和状态模型。
4. 将面板接入 Tab 列表与激活操作。
5. 添加协议、布局和端到端验证，处理发现的问题。

## Result

- T1：Bridge 已作为 App resource 打包；运行 App 后安装内容与 resource 一致、脚本权限为 `0700`；重复通过 `it2run` 启动时文件锁保持单实例。
- T2：真实 iTerm Python API 连接返回完整 Window/Tab/Session 快照；临时创建 Tab 后收到 Layout 更新，切换 Tab 后收到 Focus 更新；支持目录为 `0700`、运行中 socket 为 `0600`。
- T3：运行时面板截图确认按窗口显示 Tab 标题、选中状态和 Session 数量；协议解码与乱序快照测试通过。
- T4：真实 `activateTab` 请求成功切换并恢复原 Tab；SwiftUI Button 绑定同一动作，面板测试确认接收鼠标且可成为 key window。
- T5：Bridge 不可用时显示授权或重启提示；mock Unix Socket 关闭并重建后，Swift 客户端完成两次连接；发送失败进入共享重连路径。残余风险：该网络层重连验证尚未沉淀为自动化测试。
- T6：系统 Python 与 iTerm Python 的 Bridge self-test、Python 编译、Swift parse、`git diff --check` 均通过；默认 `xcodebuild test` 运行 9 个测试全部通过；真实窗口跟随与失焦隐藏检查通过。
- Review gate: Required — 安装可执行 AutoLaunch Bridge 并使用 Automation/本地 IPC，涉及权限与安全边界。
- Review decision: `APPROVED` — 3 次 Reviewer pass 后无未解决 finding；[审查报告](../../reports/adversarial-review/iterm-bridge-tab-list.md)。
