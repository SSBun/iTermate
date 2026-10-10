# 第 01 轮独立审查

- 任务：distinguish-venom-debug-monitor
- 模式：independent subagent
- Run：21c5c3a2-886f-4cce-a8d9-b2c94a57d5bd
- 快照：sha256:516bcec728d6f92cd00e517c8cf7aa8569416e34601314aa98accc474124235e

以下为 Reviewer 原始反馈。

## Review

**Review mode**: independent subagent

**Reviewed scope / snapshot**：检查本任务增量、实际源码、相关调用方和失败路径；未将既有脏工作区改动归入本任务。依据 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/distinguish-venom-debug-monitor/evidence/task.patch"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/distinguish-venom-debug-monitor/evidence/task.patch) 和 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/distinguish-venom-debug-monitor/evidence/snapshot-01.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/distinguish-venom-debug-monitor/evidence/snapshot-01.json)。快照声明 SHA256 为 `516bcec728d6f92cd00e517c8cf7aa8569416e34601314aa98accc474124235e`；本轮未独立重算哈希。

### Findings

**TR-1 — Critical Finding / P1：iTerm2 会话缺少 TTY，雷达入口始终不可达。**

- **Location**：[ "/Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift) 第 971–974 行；相关上游 ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py) 第 953–978 行。
- **Issue**：新候选筛选要求 `session.tty` 非空，但 iTerm2 Bridge 的会话快照没有输出 `tty`。
- **Evidence**：Python 快照字典只有路径、ID、状态等字段，全文件搜索也没有 `tty`。Swift 的 `TerminalSessionSnapshot.tty` 是可选字段（第 125 行），缺失时解码为 `nil`；因此 `$0.tty.map { ttyCounts[$0] == 1 } == true` 永远不成立。iTerm2 快照直接用于当前窗口，没有补齐 TTY 的步骤。
- **Impact**：即使 venom-cli 已构建成功并进入监控，iTerm2 面板仍一直显示普通图标，违反 T1。手工向 detector 传入 TTY 的只读观测绕过了这个缺口。
- **Suggested next step**：从 iTerm2 权威会话变量读取并输出真实 TTY，保持读取失败时不猜测；补充 Bridge 快照→Swift 候选→识别结果的链路证据。需要修复后重新审查。

### Unverified risks

- **真实 UI 与转换**：未运行新 App、未操作监控停止或重新构建，也未现场观察模拟器分支。静态源码与图像预览不能证明真实面板交互。本轮不将这些限制单独判为阻断项；TR-1 已明确阻断 T1。
- **快照身份**：前后读取的快照清单一致，但工具无法独立计算实际文件哈希。当前内容与声明快照的逐文件一致性仍须主 Agent 按约重算；完成该检查前，不能声称已验证当前快照身份。

### Checks performed

- 核对有效 T1/T2、精确增量、生产 detector、Store 发布与清理、SwiftUI 消费入口、工程源码注册。
- 对照 venom-cli 的成功构建、启动、日志子进程创建及清理路径。
- 检查 Canvas 扫描算法、减少动态效果分支，并查看浅色、深色、静态预览。
- 确认识别仅细化普通命令显示，没有改写 Agent 生命周期或完成统计。

### Author evidence examined

读取构建摘要、完整构建日志相关内容、只读观测及预览源码。构建日志显示 `BUILD SUCCEEDED`，但不是本 Reviewer 重跑的结果。

观测文件实际记录 **3 个 monitoring、4 个 not monitoring**，与 Result 所写的 4 个正例、3 个反例不一致；本轮仅采信文件中的数量，且不据此推断每个正例的平台。

### Coverage limits

未执行任何命令、测试或构建；未启动、停止或重启 App、Bridge、用户监控；未编辑文件。审查反馈不授权任务完成。