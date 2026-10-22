# Task Review — Round 06

- Task: `replace-codexm-with-native-monitoring`
- Round: 06
- Review mode: independent subagent
- Run identity: `/root/native_passive_monitor_final_review`
- Reviewed snapshot: `sha256:e364c91f0cd727a983ae842018d5247f5e689d31ad494c27e4e83ba66fe020a8`

## Reviewer feedback

Review mode: independent subagent

Reviewed scope / snapshot: 已审阅 T1–T5、指定源码与调用方、迁移失败路径、测试源码、配置、删除项、文档、任务账本及 Round 04/05。入口与出口逐文件 SHA-256 均匹配冻结清单，删除项保持缺失，对应 `sha256:e364c91f0cd727a983ae842018d5247f5e689d31ad494c27e4e83ba66fe020a8`，未发现漂移。

Findings:

- TR-8
  - Severity: Concern
  - Location: `docs/codex-monitoring.md:18-19`、`iTermate/CodexSessionMonitor.swift:134-152,235-240`，T4
  - Issue: 隐私说明仍声称“只读取” rollout 尾部，但非显式 resume 的映射还会读取文件开头最多 65,536 字节，并解码首行 Session 元数据中的 `cwd` 和 `source`。
  - Evidence: `sessionMetadata(at:)` 执行 `read(upToCount: 65_536)` 并解码首个换行前的数据；`resolveRollout` 使用其中的根/子代理来源与工作目录。当前“仅使用生命周期事件类型和时间戳”也未区分状态判断与 Session 映射。
  - Impact: 不展示、不上传对话内容的核心声明已准确，但本地文件读取及所用字段的边界仍未完整披露。
  - Suggested next step: 明确说明会读取首行 Session 元数据用于根 Session 映射，并读取有界尾部用于生命周期状态；分别列出 `cwd/source` 与事件类型/时间戳。

- TR-9
  - Severity: Concern
  - Location: `iTermate/CodexSessionMonitor.swift:155-169`、`iTermateTests/CodexSessionMonitorTests.swift:39-49`，T2
  - Issue: 大文件尾部可能从多字节 UTF-8 字符中间开始；实现先严格解码整个字节块，之后才丢弃首个残缺 JSONL 行。
  - Evidence: `String(data:encoding:.utf8)` 位于首个换行裁剪之前；若起始字节是 UTF-8 continuation byte，解码直接返回 nil，后面的完整生命周期行不会进入解析。现有大尾部 fixture 只对 ASCII `String.suffix` 调用解析器，未覆盖生产文件的任意字节偏移。
  - Impact: 包含非 ASCII prompt、回复或工具内容的较大 rollout 在该边界条件下会暂时保持旧状态或首次附着为未知，即使尾部已有完整的新生命周期事件。
  - Suggested next step: 对截断后的原始 `Data` 先移除首个换行及其之前的字节，再做 UTF-8 解码，并增加从多字节字符中间截断、后接完整生命周期行的聚焦 fixture。

Unverified risks: 聚焦测试未执行，GUI 的 Interrupted 展示未做视觉验证；交互式 resume 映射歧义及上游 rollout 内部格式演进仍未做运行时扩展验证。分别影响 T2/T3，但在禁止运行测试、已有 build-for-testing 与既有现场证据的约束下，不阻塞其余 Target 验证；TR-8/TR-9 是已确认问题而非未验证风险。

Previous findings:

- TR-4 — resolved：无生命周期事件时返回未知；仅同一进程身份保留既有确认状态，首次附着不猜测。
- TR-5 — resolved：`turn_aborted` 与 running 进程消失产生独立 `.interrupted`，标签和 UI 状态映射存在。
- TR-6 — resolved：时间戳依次支持带小数秒和不带小数秒的 ISO-8601。
- TR-7 — resolved：旧 hooks 能力声明已从产品文档移除。
- TR-8 — substantive progress：已删除“不读取对话内容”的错误承诺，并准确说明不展示或上传 prompt、回复、思考及工具内容；但上述首行元数据读取边界仍未披露完整。

Checks performed: 静态追踪进程/TTY 识别、rollout 匹配与解析、状态保留及进程消失、overlay/UI、启动迁移、第三方 hooks 保留、Pi/Shell 路径和项目源引用；审阅测试与文档；运行范围搜索、`git diff --check`；在入口和出口核对全部指定哈希及缺失项。未编辑文件、未运行测试或构建、未调用嵌套 host CLI。

Author evidence examined: 当前 Target/Result/Assessment/Review ledger、Round 04/05，以及作者记录的 Python `py_compile`、Debug `xcodebuild build-for-testing`、xcodegen、venom 构建/启动、0 个受管 hooks 与 20 个第三方 hooks 保留、旧文件缺失、六个直接 Codex TTY/root-session 匹配和措辞搜索。均作为继承证据读取，未声称复跑。

Coverage limits: 未执行单元/项目测试、构建、App 启动、实时迁移或 GUI 视觉检查，也未审计 Codex 上游格式的跨版本兼容性；无关脏工作树变更不在本次范围内。
