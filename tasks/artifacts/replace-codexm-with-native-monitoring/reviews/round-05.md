# Task Review — Round 05

- Task: `replace-codexm-with-native-monitoring`
- Round: 05
- Review mode: independent subagent
- Run identity: `/root/native_passive_monitor_rereview`
- Reviewed snapshot: `sha256:b7262d0d6b082aab65da56165fa004e8d9f6764126104b5d52cddc0d59e42203`

## Reviewer feedback

Review mode: independent subagent

Reviewed scope / snapshot: 已审阅 T1–T5、指定源码与调用方、迁移失败路径、测试源码、配置、删除项、文档、当前任务记录及 Round 04。检查前后所有逐文件 SHA-256 与冻结清单一致，删除项保持缺失，对应整体快照 `sha256:b7262d0d6b082aab65da56165fa004e8d9f6764126104b5d52cddc0d59e42203`，未发现漂移。

Findings:

- TR-8
  - Severity: Concern
  - Location: `docs/codex-monitoring.md:19`、`tasks/tasks/replace-codexm-with-native-monitoring.md:28`、`iTermate/CodexSessionMonitor.swift:155-189`
  - Issue: 文档和任务摘要声称监控“不读取”对话内容，但实现会读取 rollout 最后 1 MiB，并对其中每一行执行完整 JSON 反序列化，包括非生命周期的 `response_item` 行；实现只是最终不使用或展示其对话字段。
  - Evidence: `observation(at:)` 将整段尾部读入 `String`；`parseObservation` 在检查 `type == "event_msg"` 之前，已通过 `JSONSerialization.jsonObject` 解析整行对象。该行为与“只读取事件类型和时间戳”“without reading conversation content”的字面承诺不一致。
  - Impact: 用户会得到不准确的本地数据访问/隐私边界说明；功能状态映射本身不受影响。
  - Suggested next step: 将声明准确收窄为“仅读取本地 rollout 尾部，仅使用生命周期事件类型和时间戳，不展示或上传对话内容”；若“不读取内容”是硬性要求，则需相应改变解析策略并提供验证。此 Concern 需要 remediation。

Unverified risks: 聚焦测试仍仅完成编译、未执行，GUI 的 Interrupted 展示未做视觉验证；影响 T2/T3，但在明确禁止运行测试且已有 build-for-testing 成功证据的约束下，不阻塞当前 Target 验证。交互式无显式 ID 的 resume 映射、Codex 内部 rollout 格式演进仍为已披露的非阻塞限制。

Previous findings:

- TR-4 — resolved：`parseObservation` 无生命周期事件时返回未知；`resolvedObservation` 仅对同一进程身份保留上一已确认状态，首次附着保持未知；测试源码构造超过 1 MiB 的尾部并覆盖该生产 helper。
- TR-5 — resolved：新增独立 `.interrupted`；`turn_aborted` 映射为 interrupted；先前 running 的进程消失时按原 TTY 发出 interrupted；标签为 “Interrupted”，动画映射为失败语义。
- TR-6 — resolved：时间戳先按带小数秒 ISO-8601 解析，再回退到无小数秒格式；测试 fixture 使用原生小数秒形式。
- TR-7 — resolved：产品介绍中的旧 hooks 声明已替换为 TTY/rollout 被动监控；监控指南状态表及 hooks/包装器边界一致。

Checks performed: 核对入口与出口逐文件哈希、删除项及工作树范围；静态追踪 Codex 进程识别、rollout 解析与状态保留、进程消失、overlay/UI 映射、启动迁移、第三方 hooks 保留、Pi/Shell 路径及项目源文件引用；比较旧安装逻辑确认 `_iTermate` 所有权标记；审阅测试源码和全部相关文档声明。未修改文件、未运行测试、未运行构建、未调用嵌套 host CLI。

Author evidence examined: 当前 Result、Review Assessment、Review ledger、Round 04；作者记录的 `git diff --check`、Python `py_compile`、Debug `xcodebuild build-for-testing`、xcodegen、venom 构建/启动、0 个受管 hooks 与 20 个第三方 hooks 保留、旧文件缺失及六个直接 Codex TTY/root-session 匹配。均作为继承证据读取，未声称复跑。

Coverage limits: 未执行单元或项目测试，未复跑构建/启动和实时迁移，未进行 GUI 视觉检查，也未对 Codex 上游内部 rollout 格式做跨版本兼容审计。
