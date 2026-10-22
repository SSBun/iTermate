# Task Review — Round 04

- Task: `replace-codexm-with-native-monitoring`
- Round: 04
- Review mode: independent subagent
- Run identity: `/root/native_passive_monitor_review`
- Reviewed snapshot: `sha256:f31c0a663c4c02ac68ea656fef944dc97895108192a207ce674079e317b450c3`

## Reviewer feedback

Review mode: independent subagent

Reviewed scope / snapshot: 已检查指定源码、测试、配置、文档、删除项及相关调用方；检查前后快照均为 `sha256:f31c0a663c4c02ac68ea656fef944dc97895108192a207ce674079e317b450c3`，无漂移。

Findings:

- TR-4
  - Severity: Critical
  - Location: `iTermate/CodexSessionMonitor.swift:125-165`，T2
  - Issue: 监控器只读取 rollout 最后 1 MiB；若 `task_started` 已滑出该窗口且尚无终态事件，会把仍在运行的任务判为 `idle`。
  - Evidence: `observation(at:)` 截断到最后 1,048,576 字节，`parseObservation` 在窗口内找不到支持事件时无条件返回 `.idle`。只读检查中，当前最新 rollout 已有 952,126 字节，最后一个 `task_started` 位于偏移 19,266，且尚无 `task_complete`/`turn_aborted`；再增长约 115 KiB 即会触发该错误。
  - Impact: 长任务会在执行中从 Running 错误变成 Idle，违反可靠状态和“不确定时保守而非猜测”的要求。
  - Suggested next step: 截断窗口中没有生命周期事件时不得推断 idle；保留该进程已确认的上一状态，首次附着且无法回溯时返回未知，并增加覆盖超过 1 MiB 活跃 rollout 的小型测试。

- TR-5
  - Severity: Critical
  - Location: `iTermate/CodexSessionMonitor.swift:153-165`、`iTermate/ItermBridge.swift:46-52,1192-1213`，T2
  - Issue: 交付没有可区分的 interrupted 状态：`turn_aborted` 被直接映射为普通 `.idle`，进程意外退出则直接移除 Codex overlay。
  - Evidence: `TerminalSessionStatus` 不含 interrupted；解析器在 `turn_aborted` 时返回 `.idle`；进程消失后 observation 字典中不再有对应 TTY，未形成中断状态。
  - Impact: 用户无法区分正常空闲与被中断的回合，未满足 done condition 中对 interrupted 状态的识别。
  - Suggested next step: 明确定义并实现中断的独立状态及 UI/统计语义，至少保留 `turn_aborted` 的独立含义，并明确处理活动回合中进程消失的情况。

- TR-6
  - Severity: Concern
  - Location: `iTermate/CodexSessionMonitor.swift:160-163,226-229`；`iTermateTests/CodexSessionMonitorTests.swift:5-17`
  - Issue: 实际 Codex 时间戳含小数秒，但当前解析器不能解析，测试样例恰好省略了小数秒。
  - Evidence: 只读检查到真实事件时间戳形如 `2026-10-21T03:14:24.243Z`；执行 Foundation 解析检查时，`ISO8601DateFormatter().date(from:)` 对该值返回 `nil`。因此已识别事件的 `changedAt` 为 nil。
  - Impact: Codex 的 Running/Finished 耗时标签退化为无时间文本，状态转换时间也无法使用。
  - Suggested next step: 支持带小数秒和不带小数秒两种 ISO-8601 格式，并用真实格式补一条解析测试。

- TR-7
  - Severity: Concern
  - Location: `docs/product-introduction.zh-CN.md:164-168`
  - Issue: 能力清单仍宣称 Codex “通过 Codex 原生 hooks 接入，审核后直接运行”。
  - Evidence: 同一文档第 214 行及新的监控文档均说明不安装 hooks；该旧条目与 T1/T4 及当前实现直接矛盾。
  - Impact: 用户仍会被引导去理解或审核已删除的 hook 方案，文档未完整完成迁移。
  - Suggested next step: 将该条改为被动 TTY/rollout 监控，并明确无需 hooks 或包装器。

Unverified risks: 聚焦测试仅编译、未执行，GUI 状态未因工具超时进行视觉验证；分别影响 T2/T3，但在当前“不得运行测试”的授权约束下不单独列为阻塞项。交互式无显式 ID 的 resume 映射歧义及 Codex 内部 rollout 格式演进属于已披露、保守降级的非阻塞限制。

Checks performed: 对照任务 Target、修订要求和约束检查了指定 diff、未跟踪文件、删除项及相关调用方；核对两次完整逐文件 manifest；静态追踪进程识别、rollout 解析、overlay、迁移清理和 Pi/Shell 路径；检查真实 rollout 的事件时间戳与文件偏移；用 Foundation 单表达式验证小数秒解析结果。未编辑文件、未运行测试、未调用嵌套 host CLI。

Author evidence examined: 任务 Result/Review Assessment；XcodeGen、Python `py_compile`、`git diff --check`、`xcodebuild build-for-testing`、venom-cli 构建启动、实时 hooks 保留/清理、旧文件缺失及六个直接 Codex TTY/rollout 匹配的作者记录。上述均仅作为继承证据，未声称复跑。

Coverage limits: 未执行单元/项目测试，未进行 GUI 视觉检查，未复跑构建或启动流程，也未对 Codex 上游内部格式做跨版本兼容性审计。
