## 模式与继承约束

独立只读 task-review 初轮；未修改文件或任务状态，未运行测试、模型、下载、服务或 App，未读取凭据。无执行委派，也不授予完成批准。

基线为 T1–T3：持久化 Laya/Vela 选择、本地准备与失败反馈、保持问句定义、拒绝旧模型迟到结果、不自动回退；真实安装、GUI 与运行验收不在本轮授权范围。

## Scope / Snapshot

检查了本任务增量、相关调用路径、文档和新增回归源码；不归属并发归档、Venom 或状态恢复改动。

快照：["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/add-vela-decision-provider/evidence/snapshot-01.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/add-vela-decision-provider/evidence/snapshot-01.json)

- SHA256：`fcf4677873684f2d6d85cc89c9e9f8a89f15849d41752f58a36cca832773a3fe`
- 审查前后均重算全部 34 个文件的长度与哈希，均匹配。

## Findings

### TR-1 — 停止后立即切换可绕过旧 worker 退出等待

- **Severity**：Medium，阻断 T3。
- **Location**：["/Users/caishilin/Desktop/personal/iTermate/iTermate/LocalModelService.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/LocalModelService.swift)，148–169、204–208、300–312 行。
- **Issue**：新增切换等待仅捕获当前 `process`，但 `stop()` 在子进程真正退出前就清空该引用并解除忙状态。经过停止或取消入口后，切换无法再等待仍在退出的自有 worker。
- **Evidence**：源码允许以下序列：旧 worker 正在运行 → 关闭服务，`process = nil`，仅发送 SIGTERM → 切换 provider → 重新开启服务。此时新启动没有旧进程退出屏障；旧进程最迟可能等三秒后的 SIGKILL 才退出。Python helper 采用非阻塞独占锁，因此新 worker 可以因旧锁尚未释放而直接失败。
- **Impact**：正常设置操作可能使已安装的新模型进入不可用状态，需要再次手动重启服务；不符合“等待旧 worker 退出再启动所选 worker”的生命周期承诺。这不是自动回退或已证实的旧结果覆盖。
- **Suggested next step**：保留正在终止的自有进程身份，让所有启动路径共享退出屏障，而不只在直接 `setProvider` 路径等待。补充停止→切换→启动及取消→切换场景的回归源码；本轮仍不要执行测试。

## Drift / Contradiction

provider、资产隔离、问句接口和禁止自动回退与既定决策一致。TR-1 是退出等待承诺在停止/取消组合路径上的遗漏；无需产品或架构转向。

## Unverified risks / Target 状态

| Target | 状态 |
|---|---|
| T1 | 未发现其他确定阻断；持久化与调用接线仅静态核查，未点击设置。 |
| T2 | 未发现确定阻断；固定 revision/hash、离线加载和反馈路径已检查，但依赖安装、实际模型加载及推理时延未验证。属于已接受边界。 |
| T3 | TR-1 阻断。请求身份和 Bridge 缓存失效防护已静态检查，但未进行真实跨进程切换验收。 |

问句准确率 77.5% 为既有证据引用，本轮未复测；不能外推为 Laya 表现或可靠性保证。

## 实际 Checks

- 前后核对快照及 34 个文件的长度、SHA256。
- Python helper、协议测试文件和 Bridge 的 AST 解析通过；未导入或执行它们。
- `node --check` 对生命周期回归文件的语法检查通过。
- 构建产物中的 Python helper、Pi 集成和连接模板与源码逐字节一致。
- 暂存区文件列表为空。

## 作者证据与 Coverage limits

检查了任务 Result/Assessment，以及：

["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/add-vela-decision-provider/evidence/self-check.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/add-vela-decision-provider/evidence/self-check.json)

同时阅读最终构建、类型检查和 helper 帮助日志。构建日志明确显示 `BUILD SUCCEEDED`；类型检查日志为空，其成功状态来自作者记录，而非本轮重新执行。

编译、语法和资源一致性不等于安装、模型运行、GUI 或竞态验收。新增回归用例均未执行。

## Recommendation / Need from main agent

主 Agent 核实并修复 TR-1 后，刷新受影响自检和快照，再交新一轮只读审查。无需新增产品决策；本报告不委派 executor，也不提供完成批准。