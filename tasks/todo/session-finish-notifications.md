# Session 完成通知

Status (2026-07-29 18:59): Completed

## Scope

- 包含：普通 shell 命令与 Pi/Codex agent turn 的完成通知，覆盖所有 Session。
- 包含：默认关闭的全局通知开关与 macOS 通知权限请求。
- 包含：点击完成通知后激活对应的 iTerm Session。
- 不包含：自定义声音或按 Session 单独配置。

## Target

- [x] T1：Basic Settings 提供默认关闭的完成通知开关，并通过 `~/.iTermate/config.toml` 持久化。
- [x] T2：开关打开时，每个 Session 的 `running → finished` 转换仅发送一次包含 Session 名称与结果的 macOS 通知。
- [x] T3：App 启动时已有的 finished 状态不触发历史通知，关闭开关后仍跟踪状态但不发送通知。
- [x] T4：首次打开开关时才请求 macOS 通知权限；拒绝授权时开关恢复关闭。
- [x] T5：配置、状态转换、Swift 解析、构建、测试与运行时设置界面验证通过。
- [x] T6：用户点击完成通知后，iTerm 激活通知对应的 Session；关闭通知或忽略通知不改变 Session。
- [x] T7：通知开关已开启且系统已授权时，真实 `running → finished` 转换会被 macOS 接受并显示通知；发送失败必须留下可诊断错误。

## Plan

1. 用当前运行中的 App 和 Bridge 重现通知发送失败并捕获系统返回的具体错误。
2. 修复最小根因，并让未来发送失败可从日志诊断。
3. 重跑真实状态转换、Swift 解析、构建和测试验证。

## Result

- T1：[`SettingsViews.swift`](../../iTermate/SettingsViews.swift) 在 Basic Settings 增加默认关闭的 `Notify when sessions finish`，并通过 `completion_notifications_enabled` 写入 `~/.iTermate/config.toml`；默认值、持久化及手工配置读取测试通过，实际配置确认值为 `false`。
- T2：[`SessionNotifications.swift`](../../iTermate/SessionNotifications.swift) 订阅 Store 的全部 Window/Tab/Session 快照，只对上一次为 running、当前为 finished 的 Session 发送原生通知；通知包含 Session 名称，成功显示完成信息，非零退出码显示失败状态。两 Session 同时完成测试均只报告一次。
- T3：`SessionCompletionTracker` 初始快照仅建立 running 基线，已有 finished 不报告；重复 finished 也不报告。Controller 无论开关状态都推进 tracker，关闭时仅跳过发送。
- T4：通知开关只有从关闭切到开启时调用 `UNUserNotificationCenter.requestAuthorization`；授权回调非 granted 时在主队列恢复关闭，启动时不会请求权限。
- T5：运行 Debug App 并以窗口级截图确认 Basic Settings 中通知开关默认关闭；`swiftc -parse`、`git diff --check` 与完整 Xcode 构建测试通过，29/29 测试成功。
- T6：完成通知通过 `userInfo` 携带 Session ID；通知中心 delegate 只接受默认点击操作并调用 Store 的既有 Session 激活请求，dismiss 不路由。Bridge 在选择 Session/Tab/Window 后激活 iTerm App；路由测试、Bridge self-test、运行时 Bridge v4 握手及 Debug App 启动均通过。
- T7：用户配置确认 `completion_notifications_enabled = true`，但重新签名后的 Debug App 未重新校验系统授权，真实完成请求返回 `UNErrorDomain Code=1` / `hasError: 1`，且未进入 `usernoted` 投递管线。现在持久化开关开启时，App 每次启动都会重新请求/确认当前 bundle 的通知授权，拒绝时关闭开关；`add` completion handler 会记录未来发送错误。最终 Debug App 的真实 `running → finished` 出现 `hasError: 0`、`Delivering` 与 `Presenting ... as banner`，完整 Xcode 构建测试 29/29 通过。
- Review gate: Skipped — no explicit user request.
