# 使用 Vela 复测截图场景的终端状态分类

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-12 11:49) |
| Kind | Task |

## Target
- [x] T1: 确认实际请求使用 Vela，并对上图场景的终端文本执行状态分类，报告输出、概率和按现有阈值应显示的标签。

## Result

- T1: 本次对已运行本机服务健康检查及 /v1/session 单次实测：provider=vela，model=vllm-sr/Vela-2.0-0.3B；配置分析开关/revision 与端点 provider 一致，响应 instance 与请求前后端点一致，未输出凭据。截图右侧文字人工转录368字符/322 tokens，包含确认问题、yes、任务列表和Working，非原始完整屏幕采样。state=running，概率0.914133364；awaitingInput=0.001633858，idle=0.077767286，unknown=0.006465492；confidence=0.836366078，needs_reply=0.606874873，模型117.915ms，HTTP约121.4ms。按Bridge所用choice概率≥0.85通过；无明确生命周期状态时应展示Running?，不使用confidence作阈值。未重启App/服务、未修改产品文件；只验证此输入，不能证明截图黄色框对应行的原始输入或现场状态。
- Review gate: Skipped — R0 无产品文件改动，无独立评审请求；已核对实际API响应与显示规则。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 仅运行用户要求的本机Vela API复测，无产品文件变更。
- Snapshot: 本会话实测：Vela-2.0-0.3B，截图转录368字符，响应running=0.9141333639930104，elapsed_ms=117.915；证据完整记录于T1 Result。
- Evidence: T1 Result与本会话实际HTTP输出，身份核验前后通过；当前Bridge阈值源码为0.85，Reply附加0.6。
- Task fingerprint: a3c743a510bc330c4b8c1a4b75f1a14693ffebd677db3596ff8188fae6445bfd

## Verification

- Passed: 实测返回确认为Vela，running概率0.914133364高于0.85；confidence不是Bridge采用的概率字段。已说明截图转录及非现场复现边界，无需推断模型准确率。
