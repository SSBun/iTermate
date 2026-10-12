# 第01轮独立审查

- 任务：recover-pi-status-proactively
- Run：322e32aa-98cc-42e2-98a0-9683a77cf38b
- 模式：independent subagent
- 快照：sha256:b68b23d0b00db5baaef8384205de6bbf70d36526b7171a64ccf844f36dc59178

以下为原始反馈。

## Review

**Review mode**: independent subagent

**Reviewed scope / snapshot**：按已接受的 T1/T2，检查了[本任务精确增量 "/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/recover-pi-status-proactively/evidence/task-01.patch"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/recover-pi-status-proactively/evidence/task-01.patch)、对应生产源码、测试及相关调用路径；未把工作区其他任务改动归入本次。

快照清单声明 SHA256 为 `b68b23d0b00db5baaef8384205de6bbf70d36526b7171a64ccf844f36dc59178`。审查前后读取的清单一致，但未独立重算文件哈希。

### Correct

- 查询路径验证 token、会话及实例身份；旧端点无 `supportsStatus` 时不查询。
- 两类接收端均保护已知 Agent 状态，包括聚焦后的 idle；查询失败不生成完成状态。
- 查询与推送共享来源序列，恢复的运行状态有租约；Shell→Agent 的恢复不会直接制造完成通知。

### Findings

**TR-1 — P1 / Critical Finding：并发额度耗尽时仍推进游标，可能让健康会话持续得不到恢复查询。**

- **Location**：[ "/Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift):986–989；两秒调度位于第391行。
- **Issue**：代码先将游标推进四位，再检查四个在途额度是否已满。没有实际发起查询的轮次也消耗轮转位置。
- **Evidence**：固定八个候选、初始游标为0，前四个端点每次三秒超时且发现描述保持有效：
  1. 第0秒查询0–3，游标变4；
  2. 第2秒额度仍满，没有查询，却将游标改回0；
  3. 第3秒请求超时释放额度；
  4. 第4秒再次查询0–3，后续重复。
  
  因而4–7即使能够立即返回，也始终未被查询。这是根据当前控制流得到的确定性时序反例，非已执行运行测试。
- **Impact**：部分慢端点会阻碍其他健康会话恢复，违反 T2 的主动重新同步目标。当前六项 Swift 测试不包含 Store 调度器，无法覆盖此情况。
- **Suggested next step**：仅在实际选择并启动请求后推进游标，额度已满时保留位置；增加固定八候选、前四个持续超时的隔离调度测试，验证其余候选最终获得查询且并发不超过四个。

**Merge verdict: BLOCK**。TR-1 需要修复及定向验证；此结论仅为审查反馈，不变更任务状态。

### Unverified risks

- **快照绑定待核实**：工具不支持独立重算 SHA256。主 Agent 必须完成约定的逐文件重算，才能把本报告绑定到当前工件；核验前阻断当前快照验收，若发现漂移需重新审查。
- **真实 UI 路径未验证，非独立阻断项**：未操作实际启动、唤醒、重连或通知投递。这符合本轮禁止影响现有会话的边界，但不能将源码与隔离测试结果表述为已安装版本的现场恢复验收。

### Checks performed

- 读取需求、精确补丁和实际源码，检查认证、只读状态获取、终端映射、序列、接收端保护、租约、连接代际和完成追踪路径。
- 检查工作区差异统计，区分既有改动；审查末再次读取快照清单及调度器差异统计。
- 静态推演上述饥饿反例。未运行命令、测试或应用，未修改文件。

### Author evidence examined

读取了[证据目录 "/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/recover-pi-status-proactively/evidence/"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/recover-pi-status-proactively/evidence/)中的 Node、Python、Swift 日志、构建摘要及独立 Swift runner：分别记录32、7、6项通过。另检查[构建日志 "/tmp/itermate-recovery-final-build.log"](file:///tmp/itermate-recovery-final-build.log)，含 `BUILD SUCCEEDED`。

以上为继承作者证据，不是本 Reviewer 重跑结果。

### Coverage limits

未执行完整测试、真实 GUI 或安装态验证；未审查无关任务。只读工具不能重算内容哈希或确认暂存区是否为空。没有修改、委派或授予完成授权。