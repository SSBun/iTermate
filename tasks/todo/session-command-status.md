# 观察 Session 命令状态并显示完成图标

Status (2026-07-30 22:55): In Progress

## Scope

- 包含：使用 iTerm2 Shell Integration 的 PromptMonitor 观察每个 Session 的命令开始与结束，向 Session 快照传递运行/完成状态及退出码，并在列表中显示状态图标。
- 包含：完成状态持续显示，直到用户激活对应 Session 后清除。
- 不包含：未启用 Shell Integration 时对任意终端进程的猜测、系统通知或跨 Bridge 重启持久化命令历史。
- 本次跟进包含：为运行中的状态图标增加持续动画。
- 本次修正包含：Pi/Codex 长驻进程改用 agent 原生 turn 生命周期，Shell Integration 仅作为普通命令 fallback。
- 本次跟进包含：Pi 自动重试最终仍失败时显示失败图标，而不是成功完成图标。
- 本次修正包含：系统唤醒或 Bridge 恢复时，只从 Prompt 恢复命令身份明确的普通 Shell 命令；命令缺失时保持未知，不把长驻 Pi/Codex 外层进程标记为 running。

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
- [x] T10：Bridge 启动或重连时，已在运行的普通 Shell 命令也能显示 running 状态。
- [x] T11：电脑从睡眠唤醒后，过期的 running 状态不会继续显示，仍在运行的普通命令可被重新识别。
- [x] T12：仅重启 App 重新连接 Bridge 后，不会继续显示无法确认的旧 running 状态。
- [x] T13：Pi 自动重试最终失败并 settled 后显示红色失败图标；重试后成功仍显示绿色完成图标。
- [x] T14：Pi 的最终失败结果以非零退出状态跨 integration、Bridge 和 Swift 快照传递，旧版 Pi/Codex integration 仍可上报状态。
- [x] T15：Pi agent 工作期间持续补报 running；首次发送失败或 Bridge 重启后，状态可在后续心跳自动恢复，settled 后不再发送 running。
- [x] T16：仅 heartbeat-capable agent 的过期 running 会在心跳中断后自动清理，finished、普通命令和旧 integration 状态不受影响。
- [x] T17：睡眠唤醒或 Bridge 重连后，空闲的 Pi/Codex Session 不会被 Prompt fallback 标记为 running，仍在执行的普通 Shell 命令继续恢复。
- [ ] T18：Bridge 重启后，正在工作的 Pi Session 不得静默丢失 running 状态；集成版本或加载态不满足恢复条件时必须有明确修复路径。
- [x] T19：唤醒或重连时，命令身份缺失的 RUNNING Prompt 保持未知，不得被恢复为 running。
- [x] T20：明确的普通 Shell 命令仍可从 Prompt 恢复 running，Pi lifecycle heartbeat 仍可独立上报 running。

## Plan

1. 等待旧 Pi Session 的当前 turn 结束后加载已更新的 integration。
2. 通过 Bridge 重启与 lifecycle heartbeat 验证正在工作的旧 Session 可恢复 running，空闲 Session 不误报。

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
- T10：每个 Session 的 `PromptMonitor` 建立前先读取 `async_get_last_prompt`；若状态为 `PromptState.RUNNING`，立即恢复 running 快照，再继续监听增量事件。Python self-test 覆盖“已有命令 + 监控启动”场景；`py_compile`、`git diff --check` 和 Xcode 测试 29/29 通过。重建并重启 Bridge/App 后 Socket 握手为 v5，已安装 Bridge 与源码一致；无 Shell Integration 时仍保持未知状态，不猜测进程运行状态。
- T11：周期发布使用 `time.time()` 检测事件循环跨越睡眠的长时间间隔；唤醒后清除 Agent 管理且无法确认的 running 状态，保留 finished 状态，并用 iTerm 当前 Prompt 状态恢复普通 Shell 命令。Bridge self-test 覆盖 Agent running 清理、已结束 Prompt 清理与 RUNNING Prompt 恢复；`py_compile`、`git diff --check` 和 Xcode 测试 32/32 通过。重建并重启 App/Bridge 后 Socket 握手为 v6，已安装 Bridge 与源码一致，现场快照正常返回。
- T12：App 连接 Bridge 后先按当前 Prompt 重新验证 running 状态；已结束的 Agent 状态会被清除并释放状态所有权，仍运行的 Prompt 保留 running，普通 Shell 状态继续恢复。Bridge self-test 覆盖重连路径；`py_compile`、`git diff --check` 和 Xcode 测试 32/32 通过。重建并重启 App/Bridge 后握手为 v6，已安装 Bridge 与源码一致，现场快照为 0 个 running 状态。
- Wake refresh review gate: Skipped — no explicit user request.
- Reconnect refresh review gate: Skipped — no explicit user request.
- Initial running-state review gate: Skipped — no explicit user request.
- T13：Pi integration 在每次 `agent_end` 保存最后一个 assistant 的 `stopReason`，只在最终 `agent_settled` 上报结果；smoke check 验证最终 `error` 上报 `exitStatus: 1`，失败后自动重试成功上报 `exitStatus: 0`。App 已有的非零退出状态分支显示红色 `xmark.circle.fill`。
- T14：`setSessionStatus` 接受可选的 0–255 `exitStatus`，缺省为成功；Bridge 按字段校验请求而不按 integration 携带的版本元数据拒绝旧请求。Bridge self-test、Socket 失败/清理请求和 Pi mock lifecycle 均通过。
- T13、T14：`python3 -m py_compile`、`swiftc -parse`、`git diff --check` 和当时的 Xcode 测试通过。其后按用户纠正恢复原有已安装 Pi extension，并移除 App↔Bridge 运行时版本校验；后续实现仅修改源码与构建产物。
- Review gate: Skipped — no explicit user request (Pi failure status follow-up).
- T15：Pi integration 将所有状态请求串行发送；受控 Unix Socket 竞态检查验证在途 running 完成后才发送 finished，settled 2.2 秒后没有新 running。首次连接失败后启动 Bridge，下一次心跳可恢复 running，再正确发送 finished。
- T16：Bridge 仅为显式 `heartbeat: true` 的 running 记录活跃时间，8 秒无心跳后清除 running 但保留 agent 状态所有权直至外层命令结束；普通 Shell 状态、旧 integration 的非心跳 running 与 finished 均不参与该过期逻辑。Bridge self-test 覆盖心跳刷新、过期、兼容和终态保留。
- T15、T16：TypeScript 类型检查、Node 受控竞态/恢复检查、Python compile/self-test、Swift parse、`git diff --check` 与 Xcode 测试 32/32 通过。未部署用户目录；`~/.pi/agent/extensions/iTermate-integration.ts` 在实现前后哈希均为 `329b409cb1be34bcf231bc4d2bbf93138e3bf3364850dde633e45f19eb643f23`。
- Review gate: Skipped — no explicit user request (heartbeat fix).
- T17：截图与受控 self-test 复现了唤醒刷新会把 `PromptState.RUNNING` 的长驻 `pi` 外层命令当成普通 Shell 命令；Bridge 现在读取 `Prompt.command`，恢复路径跳过 Pi/Codex，仅保留普通命令。回归检查同时断言普通 `python3 build.py` 可恢复、`pi` 不会恢复为 running。
- T17：Python compile/self-test、TypeScript 类型检查、Swift parse、`git diff --check` 与 Xcode 测试 32/32 通过。未部署源码：已安装 Bridge 与 Pi extension 的哈希在本次实现前后保持不变。
- Review gate: Skipped — no explicit user request (wake fallback fix).
- T18 investigation：现场 Bridge 快照确认两个工作中的 Pi Session 状态均为 `null`；对应 Pi 进程分别启动于 integration 更新之前的 7 月 28 日与 11:49。21:59 重启 Bridge 后，旧进程没有加载可恢复 running 的当前心跳实现；直接以外层 `pi` Prompt fallback 会重新引入空闲误报，因此不能使用该猜测。
- T18 implementation：经用户明确许可，App 启动现在仅在 Pi integration 已安装且内容落后时原子更新为 bundle 版本，保持 `0600` 权限，未安装时不写用户目录。聚焦测试覆盖“未安装不创建、已安装旧版本自动更新”，完整 Xcode 测试 33/33 通过；真实重启把安装文件哈希从 `329b409c…` 更新为与 bundle 一致的 `f233b222…`。
- T18 pending：两个已运行的旧 Pi 进程仍需在当前 turn 结束后执行一次 `/reload`，再通过 Bridge 重启验证 running 心跳恢复后才能关闭目标。
- Review gate: Skipped — no explicit user request (Pi integration auto-update follow-up).
- T19：`current_prompt_is_running` 现在要求 RUNNING Prompt 同时具有非空命令；新增回归断言先在旧逻辑下稳定触发 `AssertionError`，修复后命令为空的唤醒恢复不再产生 running 状态。
- T20：Bridge self-test 保留了 `python3 build.py` Prompt 恢复 running、`pi` Prompt 不走普通命令 fallback，以及 heartbeat 请求独立建立 running 状态的断言。
- T19、T20：`python3 iTermateBridge/iTermateBridge.py --self-test`、`python3 -m py_compile iTermateBridge/iTermateBridge.py`、聚焦 `git diff --check` 与完整 Xcode 测试均通过，34/34 测试成功；未修改用户安装态。
- Review gate: Skipped — no explicit user request (Prompt observation optimization).
