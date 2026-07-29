# 观察 Session 命令状态并显示完成图标

Status (2026-07-29 14:00): Completed

## Scope

- 包含：使用 iTerm2 Shell Integration 的 PromptMonitor 观察每个 Session 的命令开始与结束，向 Session 快照传递运行/完成状态及退出码，并在列表中显示状态图标。
- 包含：完成状态持续显示，直到用户激活对应 Session 后清除。
- 不包含：未启用 Shell Integration 时对任意终端进程的猜测、系统通知或跨 Bridge 重启持久化命令历史。
- 本次跟进包含：为运行中的状态图标增加持续动画。
- 本次修正包含：Pi/Codex 长驻进程改用 agent 原生 turn 生命周期，Shell Integration 仅作为普通命令 fallback。

## Target

- [x] T1：Bridge 对动态创建和销毁的 Session 订阅命令开始/结束事件，并传递运行状态与退出码。
- [x] T2：命令完成状态不会按时间自动消失；对应 Session 被激活后才清除。
- [x] T3：运行中、成功完成和失败完成分别显示可区分的状态图标；无 Shell Integration 时不伪造状态。
- [x] T4：协议、Swift 解码、Python 自检和完整 Xcode 测试通过，既有 Session 激活行为不回归。
- [x] T5：运行中的状态图标持续动画，完成状态图标保持静态。
- [x] T6：Pi/Codex CLI 进程仍存活但 agent 已等待输入时不再显示运行状态，新 turn 与完成状态按 agent 生命周期更新。
- [x] T7：Agent 退出后状态所有权返回 Shell Integration，普通命令状态观察不回归。
- [x] T8：本机 Pi/Codex 集成安装后不覆盖现有 extension/hooks，Bridge、App 和测试验证通过。
- [x] T9：Pi lifecycle handler 在返回前确认状态已送达 Bridge，agent settled 后不再因异步发送失败而残留 running。

## Plan

1. 让 Pi lifecycle handler 等待 Bridge 确认状态，消除 fire-and-forget 发送窗口。
2. 更新 bundle 与本机 extension，并复现 running → finished。
3. 运行相关 smoke check、构建与测试。

## Result

- T1：Bridge v3 为每个动态 Session 创建 `PromptMonitor`，监听 `COMMAND_START` 与 `COMMAND_END`；命令开始传递 `running`，命令结束传递 `finished` 和退出码。未启用 Shell Integration 时监视器不可用且不伪造状态。
- T2：Bridge 不设置完成状态过期时间；显式 `activateSession` 成功或 FocusMonitor 观察到后续激活时才清除 `finished` 状态。
- T3：Session 行显示运行中的橙色沙漏、成功完成的绿色勾和失败完成的红色叉；无状态时保留原有焦点/最小化图标。
- T4：`python3 -m py_compile`、Bridge `--self-test`、`swiftc -parse` 和 `xcodebuild -project iTermate.xcodeproj -scheme iTermate build test` 均通过；完整测试 17/17 通过。重启 helper 后 Unix Socket 握手返回 `version: 3`、`bridgeVersion: 3`，快照包含 `status` 与 `exitStatus` 字段。
- T5：[`iTermateApp.swift`](../../iTermate/iTermateApp.swift) 中运行状态使用可重复的 180° 沙漏动画；成功/失败图标保持静态，并在系统启用 Reduce Motion 时禁用动画。`swiftc -parse`、`git diff --check` 和完整 Xcode 测试通过，17/17 测试通过。
- T6：Bridge v4 接受 agent lifecycle 状态并赋予其高于 PromptMonitor 的优先级；Pi mock lifecycle 与 Codex hook smoke test 均观察到 idle → running → finished，完成状态等待 2 秒仍保留，激活 Session 后清除。重启 Bridge 后现场快照中长驻但空闲的 Pi Session 不再显示 running，实际截图确认误报沙漏已消失。
- T7：Pi `session_shutdown` 与 Codex `SessionEnd` 报告 detached，Bridge self-test 验证释放 agent 管理权；PromptMonitor 仍负责非 Pi/Codex 普通命令。
- T8：Pi extension 作为新文件安装，未修改现有 Otty extension；Codex hooks 以 `_iTermate` 条目追加，原文件备份为 `~/.codex/hooks.json.itermate-backup`。Bridge 握手为 v4，Python compile/self-test、TypeScript import、Swift parse、`git diff --check` 与完整 Xcode 测试通过，17/17 测试通过。已有 Pi Session 需执行 `/reload`；Codex 需在 `/hooks` 中信任新增条目。
- T9：Pi integration 的 `report` 改为返回 Promise，连接后立即发送状态并等待匹配 request ID 的 Bridge `actionResult`，最多等待 3 秒；Pi lifecycle handler 现在由 extension runner 等待，不再 fire-and-forget。真实 Bridge smoke check 依次观察到 `agent_start → running`、`agent_settled → finished (0)`，当前 Session 快照保持 finished；源码、本机 extension 与 App bundle 内容一致，24/24 Xcode 测试、Swift parse、TypeScript import 和 `git diff --check` 通过。
- Review gate: Skipped — no explicit user request.
