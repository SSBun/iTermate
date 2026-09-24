## Review

### 审查模式与范围
单轮、独立、只读审查。仅审查任务专属补丁中的五个实现文件及必要调用链，未将其他任务的工作区变更归入本任务。

快照依据：["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/show-running-subagent-status/evidence/snapshot.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/show-running-subagent-status/evidence/snapshot.json)，声明摘要为 `9e6ef22b2bd03dfd7f817106b6447c372ccf0e0e7afbcd25a591bd4933862953`。本审查未独立计算哈希。

### 正确项
- Fleet 查询使用公开 RPC，权威实现限定当前 Pi Session，避免从历史文本推断子代理状态。
- 两种传输路径均覆盖独立字段；图标与原有矩阵、问号并列，明确等待输入的状态优先级得到保留。
- 接收端校验非法状态组合，完成和退出路径会清除子代理字段。

### Findings

**TR-1 · P1 · Concern：RPC 恢复时可能永久停止心跳，导致仍运行的子代理图标消失。**

- **位置**：["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，第 285–296、330–333 行。
- **证据**：`pollFleet()` 在等待 RPC **之前**计算 `wasStale`；与此同时，`sendHeartbeat()` 遇到过期确认会直接返回，不再安排下一次心跳。
- **可达时序**：
  1. 主代理已结束，缓存仍为 `hasRunningSubagents = true`。
  2. 轮询在旧确认年龄 5.8 秒时开始，因此 `wasStale = false`。
  3. 心跳在年龄超过 6 秒后执行并停止。
  4. RPC 在其一秒超时内成功返回，仍确认有子代理；布尔值未变，且保存的 `wasStale` 为假，轮询不调用 `publish()`。
  5. 后续正常轮询持续刷新确认时间，但均不重启心跳。两端八秒租约最终清除运行状态。
- **影响**：违反 T1；即使 RPC 已恢复且子代理持续运行，图标也可能一直缺失，直到另一个生命周期事件触发发布。
- **最小建议**：明确记录因过期而暂停的心跳状态，成功确认后恢复全量发布；不要仅依据请求开始时的 `wasStale` 判断恢复。修复后补充跨六秒边界的确定性时序验证，执行需遵守现有授权。

### 未验证风险
- **T1/T2，阻断修复验收**：没有生命周期或故障时序运行证据；现有构建、类型检查无法排除 TR-1。修复后需提供针对性恢复证据。
- **T1，非阻断剩余风险**：未观察真实 UI、macOS 13 上的图标呈现及问号并列布局；源码与构建不等于视觉验证。
- **快照绑定，待主会话核验**：未独立计算审查前后哈希；没有发现内容漂移的直接证据，但主会话必须完成清单一致性核对。

### 检查与作者证据
- 独立追踪了 Fleet RPC、Pi 生命周期、轮询/心跳、接收端租约、Ghostty 合并及 Session 行显示。
- 查阅了任务 Result/Assessment。
- 作者的 ["/tmp/itermate-subagent-build.log"](file:///tmp/itermate-subagent-build.log) 第 75 行记录 `BUILD SUCCEEDED`。
- 查阅了 ["/tmp/itermate-subagents-tsconfig.json"](file:///tmp/itermate-subagents-tsconfig.json)：配置确为严格、无输出检查，并引用已安装 Pi 类型。
- tsc、Swift/Python 语法及 diff 检查通过属于作者记录，本审查未重新执行。
- 未执行测试、命令、应用启动或文件修改。

**Merge verdict：BLOCK**，依据 TR-1；不授予任务完成授权。