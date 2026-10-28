# 排查 Pi 会话状态显示不正确

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 16:15) |
| Artifacts | [Artifacts](../artifacts/diagnose-pi-session-status-display/) |
| Kind | Task |

## Target
- [x] T1: 用当前会话的真实状态证据定位截图中 Pi 状态显示异常的原因，并明确修复或恢复条件

## Scope

仅对用户截图中 Pi 会话的状态生成、传输与展示进行只读诊断。本轮不修改产品代码、配置、安装态或原始会话文件；不调用模型推理、不运行测试、不重启 App/Bridge/Pi。不混同 Codex 进程与 thread 关联问题，保留其他会话及并行任务的未提交记录。

## Plan

1. 已核对截图的 Pi 三角身份与灰色状态不可用提示。
2. 已关联真实 Pi 私有状态端点、Bridge Session ID与原始会话时间线，静态追踪空回复到unknown的路径。
3. 交付根因与修复边界：应在Pi集成处理无可见文本的轮次，不能依赖空文本分类，也不能在UI把unknown伪装成完成。实际源码修复属于后续执行范围。

## Diagnosis

- 截图标记的是本会话的Pi三角图标；右侧灰色感叹号由 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift) 的 AgentUnknownStatusView（约1913行）显示，语义为“Agent detected; status unavailable”，不是普通Shell，也不是明确等待回复。
- 只读当前Pi发现元数据，核对PID10667与终端Session身份。直接对私有Unix socket发送现有认证status动作，返回status=running、hasRunningSubagents=false；真实Bridge快照同一Session亦为agent/pi/running。因此本轮正在处理用户消息时，Pi→Bridge传输正常。认证token、原始会话路径与完整原生会话ID未保存到记录。
- 只读原始Pi会话条目元数据：本地16:08:40.736正常助手回复stop、可见正文501字符；随后一个custom_message；16:08:47.766再次出现助手stop、正文0字符。当前对话可核对custom_message对应后台网页抓取完成通知与随后的空回复；该时序早于16:11:54截图。未复制完整会话或隐藏思考。
- ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts) 的agent_end（约1301行）取最后一条助手消息，未跳过空正文；agent_settled（约1319行）在正常结束且启用模型辅助时先将baseStatus设为null；classifyReplyWithModel（456行）对空白正文直接返回undefined；1333行将undefined映射为null并发布。因此这种正常stop但无可见正文的轮次必然落入unknown，符合截图表现。空回复本身不是模型服务故障。
- 仓库与已安装Pi集成SHA256相同：817e083f8d3ebdc43092cab63eae40fa57602b4fc6141193ddefd9b7f3f18911，排除这两份磁盘副本版本不一致。未把磁盘相同当作所有模块内存已更新的通用证明。
- GET读取Ollama库存与驻留模型，所选2B模型存在且digest匹配源码固定revision；这些只证明当前库存及驻留，不证明16:08时某个推理成功。本例空正文在发出模型请求前即返回unknown，故无需重新推理来验证该分支。Pi现有日志只有上午标题provider失败，不能用来证明本次问题分类失败。
- 修复位置应为Pi生命周期集成：显式定义后台通知/无可见回复轮次的语义，不将空正文作为新回复进行问题分类；同时保留中止、失败、真实待回复、子代理活动与完成去重边界。不应仅在界面强制把所有unknown显示为idle/finished，也不能无条件复用之前的等待状态。此次仅诊断，没有实施该修复。
- Context完整元数据索引及CTX-pi-status-recovery、CTX-pi-session-archives、CTX-local-decision-models已核对；相关知识已覆盖模型返回unknown及共用状态派生，未改变稳定架构事实，无需写入Context。既有未索引“工程与组件”警告保持不动。
- 证据限制：没有保存截图时刻的原始Bridge状态快照，无法声称直接观测过16:11的内部baseStatus。根因判断由实际会话时间线、可确定的源码分支及截图语义相互印证；当前running的现场观测不冒充历史状态采样。

## Task Summary

本轮仅完成Pi会话状态异常的只读诊断，没有修改产品源码、用户配置或安装态。

## Result

- T1: 已只读核对Pi原始会话时间线：16:08:40有501字可见回复，16:08:47后台通知后stop但正文为0；源码agent_end取空正文，classifyReplyWithModel直接返回undefined，agent_settled上报null，界面AgentUnknownStatusView显示感叹号。现场Pi认证status与同Session的Bridge均为running，集成磁盘哈希一致。修复应处理空回复轮次而非强制UI状态；此次未修复，历史快照限制见Diagnosis。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 仅交付只读根因分析，没有请求的产品交付文件变更；任务记录和源码身份清单不算产品变更。
- Snapshot: snapshot:tasks/artifacts/diagnose-pi-session-status-display/evidence/f08eb2953980bb8e93f834eb74ee0c682bd39e0e3bcc47cf3cec014d3c2c43ac.json#f08eb2953980bb8e93f834eb74ee0c682bd39e0e3bcc47cf3cec014d3c2c43ac
- Evidence: Diagnosis中的原始会话元数据、认证status/Bridge实采、源码行号及集成哈希交叉核对；未执行模型推理或测试。
- Task fingerprint: f3e260da5973dc685fc12860496af56e49f30465440f1388b4cd47a84e206a54

## Verification

- Passed: 最终复读AgentUnknownStatusView源码及空文本分支，Context validate有效（保留既有未索引警告），git diff --check通过；本轮没有产品源码差异，Pi10667与App70525仍运行且未主动重启；不把本轮running样本冒充截图历史快照。
