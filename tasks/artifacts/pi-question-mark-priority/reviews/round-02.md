## Review

### Review mode
independent subagent，独立只读审查。

### Scope snapshot
审查限定为 Pi 文本判定、模型肯定合并、等待保持、问号样式及配套测试；排除并发归档任务。

已前后读取 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-02.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-02.json)，清单一致。工具不能重算 SHA256，实际文件身份仍由主会话复核。

### Correct
- 肯定文本判定不会被模型否定覆盖；关闭模型分析不会撤销已确认等待。
- 等待状态持续续租，下一轮清理；等待样式通过既有偏好校验回退为问号。
- 生命周期夹具将归档 I/O 隔离为不可用，不调用真实 socket。

### Findings

**TR-1 — substantive progress，尚未解决**
- **Severity**：P1 / Concern。
- **Location**：[ "/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts):87–88、98、613–616。
- **Issue**：新增确认分支仍把明确完成叙述判为待回复。
- **Evidence**：`needsReply("确认后我保存好了文件。")` 按源码返回 `true`：“确认后我保存”命中 `confirmationGate`，尾部允许“好了文件”，完成过滤只识别动作紧接“了／完毕／完成”，未排除“保存好了”。其他前置过滤均不命中。原 `approvalGate || (request && waiting)` 对该句返回 `false`。这是源码逐分支验证，未执行该反例。
- **Impact**：已经完成的操作仍显示问号并持续续租；模型否定也无法纠正，违反 T2。
- **Suggested next step**：补充该完成叙述的文本及生命周期负例，收紧确认门槛，同时保留“确认后我保存文件”等正向覆盖。

**TR-2 — 新增修复回归**
- **Severity**：P1 / Concern。
- **Location**：[ "/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts):71–72。
- **Issue**：新增否定过滤作用于整个尾部，错误取消另一句明确待回复请求。
- **Evidence**：`needsReply("请勿回复旧问题。按这个范围实现，可以吗？")` 在新增过滤处直接返回 `false`，后面的有效 `approvalGate` 无法执行。修复前该尾句命中既有 `approvalGate`，返回 `true`。以上为源码确定性路径核查。
- **Impact**：模型关闭或不可用时，最后明确请求确认却报告完成，违反 T1。
- **Suggested next step**：将否定限制在其所属请求或句子，补充上述混合句回归；继续保持单独“请勿回复。”为负例。

### Unverified risks
- **快照绑定**：Reviewer 无法重算哈希；主会话需完成约定复核，不另建问题编号。若实际内容漂移，则阻断当前快照结论。
- **真实 Laya 与终端 UI**：未实测，单独不构成新增 Target 阻断；不能把 mock 结果当作真实准确率或 UI 验收。

### Previous findings
TR-1 为 **substantive progress**，不是 no progress：原两条反例已有针对性修复及文本、生命周期回归；但同一完成叙述误判仍存在，不能标记 resolved。

### Checks performed
读取实际工作区 diff、相关源码和测试；静态追踪分类、模型合并、等待续租、下轮清理及样式回退。随后阅读作者证据及前轮报告。未编辑文件、执行命令或运行测试。

### Author evidence examined
已读取作者文本日志 9/9、生命周期日志 16/16，以及 Xcode 日志两项定向测试通过。Python Bridge 自检、diff check 通过仅为作者记录，未复跑。现有测试未覆盖上述两个反例。

### Coverage limits
未审计归档功能、已提交范围、真实模型准确率或完整 UI 行为。两个问题均有源码路径证据，但仍建议主会话执行定向红测确认。

**Merge verdict**：BLOCK；存在需修复的具体行为问题，不构成任务完成授权。