## Review

### Review mode
independent subagent，独立只读审查；未编辑、修改任务状态或委派。

### Scope snapshot
限定 Pi 判定、模型合并、等待保持、问号样式及相关测试，排除并发归档功能。

前后读取的 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-03.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-03.json) 清单一致。提供的快照 SHA256 为 `b5791d942b5561bc316ab32145542f93604a581510c73089ce5847e800738225`；工具无法重算，未独立验证实际文件哈希。

### Correct
- 文本肯定不会被模型否定覆盖，关闭模型后保留等待并续租。
- 聚焦处理只清除完成状态，不清除等待状态；等待样式经既有偏好校验回退为问号。
- TR-2 的原始反例已有针对性修复和文本、生命周期覆盖。

### Findings

**TR-1 — substantive progress，仍未解决**

- **Severity**：P1 / Concern。
- **Location**：["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts):90–91、99、614–617。
- **Issue**：确认门槛的动作集合与完成态排除集合不一致，仍把明确已发生的动作报告为等待回复。
- **Evidence**：`needsReply("确认后我开始了测试。")` 按源码返回 `true`。第90行允许“开始”及后续“了测试”；第91行完成态过滤不包含“开始”，句末过滤也不命中，因为“了”不在句末。此前的 `approvalGate || (request && waiting)` 对此句返回 `false`。这是静态逐分支核查，未执行该反例。
- **Impact**：非待回复叙述显示问号并持续续租；模型否定不能纠正，违反 T2。
- **Suggested next step**：使完成态排除覆盖确认门槛支持的动作，至少补充上述文本和生命周期负例，同时保留“确认后我开始测试。”正例。主会话应先运行定向反例确认。

没有新增独立问题编号。

### Previous findings
- **TR-1：substantive progress**。原“确认后我保存好了文件。”已被完成态过滤排除，并增加文本及生命周期回归；但同类完成叙述误判仍存在，不能标记 resolved，也不是 no progress。
- **TR-2：resolved**。否定过滤改用最终句；“请勿回复旧问题。按这个范围实现，可以吗？”不再提前返回，尾部确认门槛有效。文本及生命周期用例覆盖该句，单独“请勿回复。”仍有负例。

### Unverified risks
- **快照绑定**：主会话仍需按约定重算八个文件哈希；此限制不单独新增问题编号，若不一致则阻断当前快照结论。
- **真实 Laya／终端 UI**：未验收。mock 不证明真实语义准确率或端到端视觉效果；在已接受边界下，不单独阻断 Target。

### Checks performed
读取实际工作区差异、相关源码及测试，静态追踪分类、模型合并、续租、下轮清理、焦点处理和样式回退；随后查看作者证据及前轮记录。未执行命令或测试。

### Author evidence examined
- 文本日志：9/9。
- 生命周期日志：17/17。
- Xcode 日志：两项定向测试通过；两轮快照清单中的相关 Swift 哈希相同。
- Bridge 自检和 diff 检查通过仅为作者记录，未复跑。
- 现有用例没有覆盖本轮指出的“开始了测试”反例。

### Coverage limits
未审计归档功能、已提交范围、真实模型准确率或完整 UI；未安装集成或重启用户应用。

**Merge verdict**：BLOCK；TR-1 仍需修复，不构成任务完成授权。