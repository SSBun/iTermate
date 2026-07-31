# Session 完成通知

Status (2026-07-30 23:06): Completed

## Scope

- 包含：普通 shell 命令与 Pi/Codex agent turn 的完成通知，覆盖所有 Session。
- 包含：默认关闭的全局通知开关与 macOS 通知权限请求。
- 包含：点击完成通知后激活对应的 iTerm Session。
- 不包含：自定义声音或按 Session 单独配置。

## Target

- [x] T1：Basic Settings 提供默认关闭的完成通知开关，并通过 `~/.iTermate/config.toml` 持久化。
- [x] T2：开关打开时，每个 Session 的 `running → finished` 转换仅发送一次包含 Session 名称与结果的 macOS 通知。
- [x] T3：App 启动时已有的 finished 状态不触发历史通知，关闭开关后仍跟踪状态但不发送通知。
- [x] T4：打开开关时请求 macOS 通知权限；拒绝授权只阻止通知投递，不覆盖用户保存的开关。
- [x] T5：配置、状态转换、Swift 解析、构建、测试与运行时设置界面验证通过。
- [x] T6：用户点击完成通知后，iTerm 激活通知对应的 Session；关闭通知或忽略通知不改变 Session。
- [x] T7：通知开关已开启且系统已授权时，真实 `running → finished` 转换会被 macOS 接受并显示通知；发送失败必须留下可诊断错误。
- [x] T8：`completion_notifications_enabled = true` 在 App 重启后保持为 true；系统通知授权状态不得覆盖用户持久化偏好。
- [x] T9：用户打开通知开关但系统未授权时，使用标准 SwiftUI 提示引导其前往 macOS 通知设置，且不关闭已保存的开关。
- [x] T10：系统已授权时，打开通知开关不会错误显示“Notifications Are Disabled”。
- [x] T11：只有系统状态明确为 denied 时才引导打开通知设置；授权请求的技术错误只记录诊断，不伪装成用户拒绝。
- [x] T12：通知授权分支回归测试、完整测试与单一规范 Debug App 运行验证通过。

## Plan

1. 对照运行 App 身份、系统授权与授权 API 结果复现错误引导。
2. 以当前通知设置为授权事实来源，只在明确拒绝时显示系统设置引导。
3. 覆盖授权、拒绝、未决定与技术错误分支，并使用单一规范 Debug App 验证。

## Result

- T1：[`SettingsViews.swift`](../../iTermate/SettingsViews.swift) 在 Basic Settings 增加默认关闭的 `Notify when sessions finish`，并通过 `completion_notifications_enabled` 写入 `~/.iTermate/config.toml`；默认值、持久化及手工配置读取测试通过，实际配置确认值为 `false`。
- T2：[`SessionNotifications.swift`](../../iTermate/SessionNotifications.swift) 订阅 Store 的全部 Window/Tab/Session 快照，只对上一次为 running、当前为 finished 的 Session 发送原生通知；通知包含 Session 名称，成功显示完成信息，非零退出码显示失败状态。两 Session 同时完成测试均只报告一次。
- T3：`SessionCompletionTracker` 初始快照仅建立 running 基线，已有 finished 不报告；重复 finished 也不报告。Controller 无论开关状态都推进 tracker，关闭时仅跳过发送。
- T4：通知开关开启时调用 `UNUserNotificationCenter.requestAuthorization`；授权失败仅记录诊断日志，不再改写用户保存的开关。
- T5：运行 Debug App 并以窗口级截图确认 Basic Settings 中通知开关默认关闭；`swiftc -parse`、`git diff --check` 与完整 Xcode 构建测试通过，29/29 测试成功。
- T6：完成通知通过 `userInfo` 携带 Session ID；通知中心 delegate 只接受默认点击操作并调用 Store 的既有 Session 激活请求，dismiss 不路由。Bridge 在选择 Session/Tab/Window 后激活 iTerm App；路由测试、Bridge self-test、运行时 Bridge v4 握手及 Debug App 启动均通过。
- T7：用户配置确认 `completion_notifications_enabled = true`，但重新签名后的 Debug App 未重新校验系统授权，真实完成请求返回 `UNErrorDomain Code=1` / `hasError: 1`，且未进入 `usernoted` 投递管线。现在持久化开关开启时，App 每次启动都会重新请求/确认当前 bundle 的通知授权；`add` completion handler 会记录未来发送错误。最终 Debug App 的真实 `running → finished` 出现 `hasError: 0`、`Delivering` 与 `Presenting ... as banner`，完整 Xcode 构建测试 29/29 通过。
- T8：根因是 App 启动时重新请求通知授权，并在系统返回未授权时调用 `setCompletionNotificationsEnabled(false)`，把用户配置写回 `false`。授权回调现在只记录失败或拒绝，不再修改持久化偏好；聚焦持久化测试通过，最新 Debug App 连续重启两次后配置均保持 `true`，完整 Xcode 测试 32/32 通过。
- T9：`requestCompletionNotificationAuthorization` 将授权结果回传给调用方；仅当用户在 General Settings 打开开关且系统返回未授权时，页面显示标准 SwiftUI Alert，说明 `System Settings > Notifications` 路径，并提供 `Open Notification Settings` 按钮。通知设置 URL 已确认由 macOS 解析到 System Settings.app；完整 Xcode 测试 32/32 通过，最新 Debug App 启动后配置仍为 `true`。
- Review gate: Skipped — no explicit user request.
- T10：截图中的提示来自 `/private/tmp/iTermate-session-cell-fix-tests` 下以 `CODE_SIGNING_ALLOWED=NO` 构建的副本；其代码签名 identifier 为 `iTermate`，与 `CFBundleIdentifier=com.caishilin.iTermate` 不一致。系统日志明确记录该进程授权请求 `didGrant: 0, hasError: 1`，而系统设置授权和成功通知属于规范签名的 `com.caishilin.iTermate` App。
- T11：授权请求出现技术错误时现在记录错误并直接返回，不再把 `granted = false` 回传给设置页，因此不会错误显示“Notifications Are Disabled”；真正无错误且未授权时仍保留原有系统设置引导。
- T12：已终止三个并存的 Debug App，只启动 DerivedData 中代码签名 identifier 与 bundle ID 一致的规范构建；当前仅一个 iTermate 进程，启动授权日志为 `didGrant: 1, hasError: 0`，配置仍为 `completion_notifications_enabled = true`。`swiftc -parse`、`git diff --check` 与完整 Xcode 测试通过，共 33 个测试、0 失败。
- Notification authorization follow-up review gate: Skipped — no explicit user request.
