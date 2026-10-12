# 调查问号图标过多及反复显隐

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-12 16:10) |
| Artifacts | [Artifacts](../artifacts/investigate-question-icon-flicker/) |
| Kind | Plan |

## Target
- [x] T1: 只在 Agent 回答结束的生命周期 hook 对最新完整回复进行模型分类，停用屏幕抓取、轮询分类与8秒辅助状态过期。
- [x] T2: awaitingInput 保持问号；idle 先高亮点击灰显；下一轮显示真实运行状态，旧推理不能覆盖新一轮。
- [x] T3: 没有接入回答结束 hook 的会话不做模型猜测；保留 Laya 切换能力，不重启应用或服务。

## Scope

用户已确认实施 hooks-only 修复。允许修改产品与回归源码；不重启应用或服务、不调用真实模型、不运行测试。截图不能单独证明每个会话的状态来源或误判。

## Decisions

- 已安装 AutoLaunch Bridge 与当前源码逐字节相同；本机配置 provider=vela、analysisEnabled=true、serviceEnabled=true，观察到 Vela worker 进程。这不是完整运行时行为验收。
- Bridge 每2秒最多选择一个缺乏原生状态的会话分析，辅助状态8秒过期；当候选多于4个时，即使推理无耗时也无法在过期前轮询所有会话。来源：iTermateBridge/iTermateBridge.py 的 publish_periodically、update_model_observation、model_state。
- 辅助模型输入为整个可见屏幕末尾1500字符，不是从Pi消息结构提取最后Agent回复；候选包含全部没有原生status的终端，不限定已完成Agent回复。历史请求、用户输入、启动提示可能进入分类，具体误判仍需逐会话输入/输出证据。
- 本次此前修改将辅助估计与原生等待使用相同问号，取消原双门槛；二分类不再有unknown。因此非回复内容也可能被显示为等待，但不能据此断言截图所有问号均误判。
- 文本变化、推理异常及过期会移除估计，下一轮再次分类成功才恢复。当前问号动画仅每4秒短暂水平移动1像素，无透明度隐藏逻辑；它不能解释整枚图标消失。
- 截图可见很多会话，但缺少候选数量与状态时间序列，不能把轮询过期路径声称为已逐帧复现。未连接Bridge socket，因为其新连接会触发refresh_after_wake，不是纯被动观察。

## Plan

1. 删除 Bridge 屏幕分类、缓存过期及 UI 辅助估计入口，保留真实事件与快照刷新。
2. 核查 Pi 回答完成 hook 是唯一产品模型分类触发点，心跳不重新推理，保留代际检查及用户参与状态。
3. 更新说明及回归源码，进行语法、类型、构建检查和独立审查；不运行测试或用户应用。

## Block

- Reason: 当前会话可用工具未提供 subagent 启动入口，无法派发本次 R2 必需的新鲜独立只读审查；尚未启动 Reviewer，不将自检替代审查。
- Unblock when: 恢复可用的独立 subagent 启动工具；重核当前快照后派发 task-review，并完成发现处置及最终验证。

## Task Summary

**终端 Bridge**（[iTermateBridge](../../iTermateBridge/)）：删除屏幕分类、轮询、模型缓存与8秒过期，以及相应快照字段；将回归源码收敛为禁止屏幕分析及原生已读行为。

**原生面板**（[iTermate](../../iTermate/)）：删除辅助估计解码与问号入口，保留hook上报的问号和空闲高亮/灰显；设置说明改为hooks-only。

**Pi集成回归**（[integrations/pi](../../integrations/pi/)）：补充结束hook前不推理、等待续租不重新推理及下一轮running断言。

**API说明**（[docs](../../docs/)）：说明仅完成hook触发推理、兼容API不用于轮询、无hook不猜测。

## Result

- T1: Bridge无屏幕读取、模型轮询或8秒缓存；UI不再消费模型估计字段。Pi唯一模型调用位于agent_settled并使用本轮最后完整回复；已有长度上限不变。Debug构建、AST、Node语法、tsc通过，未执行测试。
- T3: 移除无hook屏幕猜测路径，保留模型偏好与显式provider；未安装或重启用户应用服务。构建产物Bridge与当前源码字节一致，文档与设置说明同步。
- T2: 保留原生问号、idle未读高亮及点击灰显，Pi心跳不重新分类且新轮次generation拒绝旧结果。用户最新反馈：已亲自测试，表现正常，要求结束任务；未提供逐项测试记录，不据此宣称自动化测试或独立审查通过。
- Review gate: Required — 独立核对hooks-only接线及高亮/等待保持
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 跨Bridge模型轮询删除及UI状态来源收敛，需独立核对生命周期边界
- Snapshot: tasks/artifacts/investigate-question-icon-flicker/evidence/snapshot-01.json
- Evidence: evidence/checks.md、scoped.diff、构建与类型检查日志；无测试/模型/UI执行
- Task fingerprint: b29b36a8e255c33d753b666190095f4ac8bcde907b576d0c0198a7674d43f9b8
