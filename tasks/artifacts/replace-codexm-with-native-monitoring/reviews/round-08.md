# Task Review — Round 08

- Task: `replace-codexm-with-native-monitoring`
- Round: 08
- Review mode: independent subagent
- Run identity: `/root/native_passive_monitor_context_review`
- Reviewed snapshot: `sha256:4ee52ebacd2992e65c254f56b555e44afcb6710a9c77b8967bce761fc572aa2d`

## Reviewer feedback

Review mode: independent subagent

Reviewed scope / snapshot: 已审阅 T1–T5、实现与调用方、失败路径、测试源码、文档、任务账本及 Round 04–07。入口与出口逐文件 SHA-256 均与冻结清单一致，三个删除项保持缺失，对应 `sha256:4ee52ebacd2992e65c254f56b555e44afcb6710a9c77b8967bce761fc572aa2d`，未发现漂移。

Findings:

- TR-10
  - Severity: Concern
  - Location: `iTermate/ItermBridge.swift:825-829,848-854,1250-1259`；`iTermateBridge/iTermateBridge.py:696-704,947-954`；`tasks/context.md:75`，T2/T3
  - Issue: iTerm2 的菜单栏 Running Agent 总数使用未合并 Codex 被动观察结果的原始 `iTermWindows`，因此直接运行的 Codex 即使在面板中显示 Running，也不会计入菜单栏总数。
  - Evidence: Bridge 识别到 `codex` 前台命令后不会生成普通 running 状态，并会删除既有普通命令状态；Swift 的 `publishItermWindows()` 虽生成 `visibleWindows = mergingCodexObservations(into: iTermWindows)`，但随后调用的 `updateStatusMenuSummary()` 固定执行 `runningAgentCount(in: iTermWindows)`。相对地，Ghostty 计数使用已完成 overlay 的 `ghosttyWindows`。权威 context 明确要求菜单栏相加“两端可确认的 Agent Running”。
  - Impact: iTerm2 中正在工作的原生 Codex 会话被菜单栏摘要漏计，跨终端运行总数与主面板状态不一致。
  - Suggested next step: 让 iTerm2 Running 计数使用同一份 Codex-overlay 后的窗口快照，并补充一个覆盖原始快照无状态、Codex observation 为 running 的聚焦检查。
  - 该确认问题需要 remediation。

Unverified risks: 单元测试未执行、GUI 不可用，故 T2/T3 的运行时及视觉行为没有本轮执行证据；交互式无显式 ID 的 resume 映射和上游 rollout 格式演进仍只有已披露的保守降级保证。以上均不阻塞其余 Target 验证；TR-10 是已确认问题而非未验证风险。

Previous findings:

- TR-4 — resolved：尾部无生命周期事件时保持上一已确认状态；首次附着保持未知。
- TR-5 — resolved：`turn_aborted` 及 running 进程消失均产生独立 `.interrupted`，UI 映射仍存在。
- TR-6 — resolved：时间戳支持带及不带小数秒的 ISO-8601。
- TR-7 — resolved：产品文档中的旧 hooks 接入声明未重新出现。
- TR-8 — resolved：`tasks/context.md:72,122` 均已区分首行 `cwd/source` 映射读取与有界本地尾部生命周期读取，并保留不展示、不上传对话内容及不读取终端屏幕的准确边界。
- TR-9 — resolved：生产 helper 在 UTF-8 解码前按原始字节丢弃截断首行，continuation-byte fixture 仍调用该 helper。

Checks performed: 两次核对全部指定文件哈希和删除项；静态追踪 Codex 进程/TTY 发现、rollout 映射与解析、状态保留、中断、iTerm2/Ghostty overlay、菜单统计、迁移清理、Pi/Shell 路径；审阅测试源码及文档；执行 scoped `git diff --check`，无报错。未编辑文件、未运行测试或构建、未调用嵌套 host CLI。

Author evidence examined: 当前 Result、Review Assessment、Review ledger、Round 04–07；作者记录的 Python `py_compile`、Debug `xcodebuild build-for-testing`、xcodegen、venom 启动、0 个受管 hooks/20 个第三方 hooks、旧文件缺失及六个 TTY/root-rollout 匹配。均仅作为继承证据读取，未声称复跑。

Coverage limits: 未执行测试、构建、App 启动、实时迁移或 GUI 视觉检查；未做 Codex 上游 rollout 格式跨版本审计；无关脏工作树变更不在本次范围内。
