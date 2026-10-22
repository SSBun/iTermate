# Task Review — Round 09

- Task: `replace-codexm-with-native-monitoring`
- Round: 09
- Review mode: independent subagent
- Run identity: `/root/native_passive_monitor_menu_review`
- Reviewed snapshot: `sha256:0b2f9cf484a674552d9b54584c128c798a576ed43dada10fb248afc133bec3e6`

## Reviewer feedback

Review mode: independent subagent

Reviewed scope / snapshot: 已审阅 T1–T5、当前实现及调用方、失败路径、测试源码、迁移清理、文档、任务记录和 Round 04–08。入口与出口的 16 个逐文件 SHA-256 均匹配提供清单，对应冻结快照 `sha256:0b2f9cf484a674552d9b54584c128c798a576ed43dada10fb248afc133bec3e6`，未发现漂移。

Findings: none。未分配 TR-11。

Unverified risks: 单元测试未执行、GUI 不可用，因此菜单栏实际渲染、运行时状态转换及 interrupted 展示没有本轮执行证据；影响 T2/T3，但在明确限制下不阻塞 Target 验证。无显式 ID 的交互式 resume 和 Codex 上游 rollout 格式变化仍依赖已披露的保守降级。

Previous findings:

- TR-4 — resolved：无生命周期事件时仅保留同一进程的上一确认状态，首次附着保持未知；长尾 fixture 仍覆盖该规则。
- TR-5 — resolved：`turn_aborted` 及 running 进程消失产生独立 `.interrupted`，UI 失败语义仍完整。
- TR-6 — resolved：时间戳兼容带与不带小数秒的 ISO-8601。
- TR-7 — resolved：产品文档未重新出现 Codex hooks 接入声明。
- TR-8 — resolved：指南、任务摘要及 `tasks/context.md` 均准确区分首行 `cwd/source` 与有界尾部读取，并声明不展示或上传对话内容。
- TR-9 — resolved：截断尾部先按原始字节丢弃残缺首行，再进行 UTF-8 解码；对应 fixture 仍调用生产 helper。
- TR-10 — resolved：`updateStatusMenuSummary()` 的 iTerm2 计数现使用 `mergingCodexObservations(into: iTermWindows)`，与面板快照一致；Ghostty 继续使用已 overlay 的快照。聚焦 fixture 从无状态原始 Session 应用 running Codex observation 后断言计数为 1。

Checks performed: 两次核对全部指定文件哈希；静态追踪 TTY/进程识别、根 rollout 映射、生命周期解析、长尾状态保留、中断、iTerm2/Ghostty overlay、菜单统计、选择性 hooks 清理及 Pi/Shell 路径；检查相关 diff、引用搜索、测试源码与文档一致性。未修改文件或任务状态。

Author evidence examined: 当前 Result、Review Assessment、ledger、Round 04–08；作者记录的最新 `git diff --check`、Python `py_compile`、Debug build-for-testing，以及既有 xcodegen、venom 启动、0 个受管 hooks/20 个第三方 hooks、旧文件缺失和六个 TTY/root-rollout 匹配。均仅作为继承证据，未声称复跑。

Coverage limits: 未运行测试、构建、App、实时迁移或 GUI 检查；未审计 Codex 上游格式的跨版本兼容性；无关脏工作树变更不在本轮范围内。

跳过项：按授权未复跑测试或 GUI。剩余风险主要是上游 rollout 格式演进与未执行的真实菜单交互。
