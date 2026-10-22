# Task Review — Round 07

- Task: `replace-codexm-with-native-monitoring`
- Round: 07
- Review mode: independent subagent
- Run identity: `/root/native_passive_monitor_utf8_review`
- Reviewed snapshot: `sha256:1267998ed685507cb352e575cd1cfd5039bf4356ad922707fd3a60f5934673c1`

## Reviewer feedback

Review mode: independent subagent

Reviewed scope / snapshot: 已审阅 T1–T5、实现及调用方、迁移失败路径、测试源码、项目配置、文档、任务账本和 Round 04–06。入口与出口逐文件 SHA-256 均匹配冻结清单，删除/缺失项保持不变；聚合快照均为 `sha256:1267998ed685507cb352e575cd1cfd5039bf4356ad922707fd3a60f5934673c1`，无漂移。

Findings:

- TR-8 — substantive progress
  - Severity: Concern
  - Location: `tasks/context.md:72,122`，T4
  - Issue: 面向用户的监控指南和任务摘要已准确披露首行 `cwd/source` 元数据与有界尾部读取，但权威 workspace context 仍声称“也不读取 prompt/回复内容”及“仅解析”三类生命周期事件。
  - Evidence: `CodexSessionMonitor.observation(at:)` 读取 rollout 尾部并转为字符串；`parseObservation` 在筛选 `event_msg` 前对每个完整 JSONL 行执行完整 JSON 反序列化。`sessionMetadata(at:)` 另读取首行元数据。该行为与 `tasks/context.md` 的旧表述不一致。
  - Impact: 后续任务和审查可能依据错误的本地数据访问边界继续传播隐私声明；当前用户文档虽已修复，任务的权威上下文仍不一致。
  - Suggested next step: 将两处 context 表述同步为：读取首行 `cwd/source` 用于映射、读取有界本地尾部并仅使用生命周期类型/时间戳判断状态、不展示或上传对话内容。
  - 本轮未分配 TR-10；该问题与既有 TR-8 根因及所需结果相同。

Unverified risks: 聚焦测试仍未执行，GUI 的 Interrupted 展示无法视觉验证；交互式无显式 ID 的 resume 映射及上游 rollout 格式演进仍仅有保守降级说明；`awaitingInput` 无可靠原生信号且实现未猜测。分别涉及 T2/T3，但在明确禁止测试、已有当前构建证据及已披露限制下均不阻塞 Target 验证。

Previous findings:

- TR-4 — resolved：尾部无生命周期事件时返回未知；同一进程仅保留上一已确认状态，首次附着不猜测。
- TR-5 — resolved：`turn_aborted` 和 running 进程消失映射独立 `.interrupted`，标签及 UI 失败语义仍存在。
- TR-6 — resolved：时间戳同时支持带与不带小数秒的 ISO-8601。
- TR-7 — resolved：旧 hooks 能力声明未重新出现。
- TR-8 — substantive progress：监控指南与任务摘要已修复；上述 `tasks/context.md` 旧隐私表述仍需同步。
- TR-9 — resolved：`decodableTail` 在严格 UTF-8 解码前从原始 `Data` 删除首个残缺 JSONL 行；fixture 以 continuation bytes 开头、换行后接完整 `task_started`，并调用生产 helper。

Checks performed: 两次核对全部指定哈希、缺失项及聚合快照；静态追踪进程/TTY 识别、rollout 映射与读取、状态保留、中断、overlay/UI、启动迁移、第三方 hooks 保留、Pi/Shell 路径和项目引用；审阅测试源码及文档声明；执行范围搜索和 scoped `git diff --check`。未修改文件、未运行测试或构建、未调用嵌套 host CLI。

Author evidence examined: 当前 Target/Result/Assessment/Review ledger、Round 04–06；作者记录的当前 `git diff --check`、Python `py_compile`、Debug `xcodebuild build-for-testing`，以及既有 xcodegen、venom 启动、0 个受管 hooks/20 个第三方 hooks、旧文件缺失和六个直接 TTY/root 匹配。均作为继承证据读取，未声称复跑。

Coverage limits: 未执行单元/项目测试、构建、App 启动、实时迁移或 GUI 视觉检查；未做 Codex 上游 rollout 格式的跨版本审计；无关脏工作树变更不在本次范围内。
