## Review
**Review mode**: independent subagent（独立、只读）。

### Scope / snapshot
审查范围为委派的 Pi 判定、模型合并、等待保持、问号样式及配套测试；排除并发归档功能。

已读取并复读 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-01.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-01.json)。清单内容一致，但工具无法重算文件 SHA256，因此不声称已验证实际文件与快照完全一致。

### Correct
- 肯定规则不再被模型否定覆盖，已识别等待不会因关闭模型分析撤销；下一轮会清理等待状态。
- 已检查共享样式消费者：不再支持的等待样式会回退到问号。
- Registry 的聚焦处理只清除 `finished`，不会将 `awaitingInput` 改为空闲。

### Findings

**TR-1**
- **Severity**: P1 / Concern，需修复。
- **Location**: ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts):74–95、610–614。
- **Issue**: 新增直接请求及隐含确认分支将明确不待回复的句子判为等待。
- **Evidence**: 按源码可确定：
  - `needsReply("请勿回复。")` 返回 `true`：否定过滤未覆盖“勿”，`请…回复` 命中 `directRequest`。
  - `needsReply("确认后我已经提交。")` 返回 `true`：`confirmationGate` 接受“已经提交”的完成叙述。
  - 两例在原逻辑中均无 `request && waiting` 成立，返回 `false`；因此是本次修改引入的误判，而非泛指模型准确率问题。以上为源码逐分支核查，未执行测试。
- **Impact**: 没有待用户回应的问题仍显示问号，并持续续租；模型即使正确返回否定也无法纠正。违反 T2 的实际待回应语义。
- **Suggested next step**: 在新增规则中排除否定请求和已完成叙述，补充上述两例的负向测试及至少一个生命周期用例，同时保留现有正向覆盖。

**Merge verdict**: BLOCK。确认问题需由主会话修复并重新审查；本报告不批准任务完成。

### Unverified risks
- **快照绑定**：缺少审查前后实际文件哈希重算。阻断当前快照验证，直到主会话提供一致性证据；若发现漂移，应刷新自检及审查。
- **真实终端 UI、真实 Laya 推理**：未验证。现有源码与确定性 mock 能支持本次有限行为结论；单独不构成新增阻断项，但不能据此声称真实 UI 或推理准确率已验收。

### Checks performed
- 先检查需求与五个指定文件的实际 diff，再阅读作者证据。
- 静态追踪分类、模型合并、心跳、下一轮清理、样式回退及 Registry/Bridge 等待状态消费。
- 核查上述两个新增误判的完整条件路径。
- 未修改文件、执行命令、运行测试或委派。

### Author evidence examined
- 已读取任务 Target、Result、Review Assessment。
- 已读取文本测试日志：8/8；生命周期日志：15/15。
- 已检查 Xcode 日志：两项定向测试通过。
- Python Bridge 自检及 diff check 通过仅为作者记录，本次未复跑。

### Coverage limits
未审查归档安全性、全部应用行为或已提交范围；测试日志属于作者证据，不是 Reviewer 独立运行结果。