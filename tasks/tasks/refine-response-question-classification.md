# 优化回复类型判断避免操作说明被误判为提问

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-28 16:06) |
| Artifacts | [Artifacts](../artifacts/refine-response-question-classification/) |
| Kind | Task |

## Plan

1. 核查 Pi settled → 本地模型 → 二分类状态路径，用截图全文复现误判。
2. 收紧模型判断顺序，区别用户操作与用户回复，添加未完成诊断及明确回复/授权的对照样例。
3. 按用户后续明确授权，运行本机 Ollama 全部分类回归和相关单元测试；不安装或重启。

## Task Summary

**Pi 集成**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 调整回复分类提示词，先查找用户回复请求，再排除仅要求执行操作的说明；加入未完成诊断和明确回报/授权的对照示例及十一个回归数据项；分类数据共38项，测试增加选择、状态确认与继续关口断言，并更新旧提示词的语义匹配断言。模型调用次数、JSON 协议、十秒预算和默认 normal 均未改变。

## Verification Notes

本轮用户明确要求更新用例并重新测试：新增8项，覆盖选项选择、检查状态后回复继续、无问号状态确认、英文继续、纯状态操作、自主推进、引用示例和报告混合继续关口。ITERMATE_REPLY_CLASSIFICATION_LIVE=1 tsx --test integrations/pi/reply-classification.test.ts 通过40项（38个分类场景、数据检查及父测试），0失败、0跳过；当前所选本地qwen3.5:2b，生产分类入口返回值全部符合预期。测试观察的是最终分类值，normal含生产错误兜底语义，不能据此宣称所有场景的原始模型输出均被单独审计。

相关单元测试首次缺少--experimental-vm-modules启动参数，随后正确运行发现两处旧提示词字面断言失败；已按当前等价分类边界替换，并保留和增加具体反例断言。node --experimental-vm-modules --test integrations/pi/local-llm-selection.test.mjs 最终20/20通过。git diff --check通过。生产提示词未在本轮修改，未部署或重启。以下为前一轮的历史验证，未运行测试的限制已被本轮用户授权和实际执行取代。

- 当前本地 qwen3.5:2b，temperature=0、seed=42、num_ctx=16384、num_predict=32、think=false；通过回环 Ollama API 直接推理，不执行项目测试套件。
- 修改前截图全文返回 question（0.41 秒）；修改后同一全文返回 normal（1.89 秒），明确回报请求返回 question（1.77 秒），明确重启授权请求返回 question（0.26 秒）；均 done_reason=stop。
- 三次请求的系统提示词+正文+1024 字节预算为 8401、8017、8048，均低于 16384。
- Node TypeScript stripTypeScriptTypes 转换并由 node --check 检查语法成功；回归 JSON 可解析，30 个 ID 全部唯一；git diff --check 通过。未运行单元测试或项目测试套件。
- 检查 classifyReplyWithModel 的调用方：仍只在 settled 后调用，明确 UI 等待与取消/过期保护不变；不改实际 Agent 生命周期、导航或统计。实际安装态和常驻 Pi 进程未修改，需用户更新集成并 reload 后生效；未声称当前面板已经采用修改。
- Context 仅更新 CTX-local-decision-models 的分类边界，保留其他任务已有改动。Lessons 的不覆盖安装态、不重启进程约束已遵守；本次纠正通过产品提示词及回归数据承载，不新增 Lesson。

## Target
- [x] T3: 选择选项、检查状态后回复继续及无问号确认关口识别为question；纯操作说明与自主推进保持normal，相关分类测试通过。
- [x] T1: 截图中的诊断说明与reload操作建议判定为normal而非question
- [x] T2: 明确要求用户回答、选择或确认的回复仍识别为question

## Result

- T1: 全量live分类回归中截图全文场景通过，返回normal；先前前后推理记录保留。
- T2: 全量live回归中选择、必要信息、回报与授权场景均返回question；相关单元测试20/20通过。
- T3: 新增8项选择/状态/继续关口及反例，全部通过；live回归38个场景全部匹配，TAP共40项通过0失败0跳过。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 局部提示词和分类用例维护，当前真实生产入口回归及相关单元测试通过，影响可恢复的显示分类。
- Snapshot: snapshot:tasks/artifacts/refine-response-question-classification/evidence/9c87da417be354116e5b2a0cb343f811ed7db836a3feee9eb214d50e85665c11.json#9c87da417be354116e5b2a0cb343f811ed7db836a3feee9eb214d50e85665c11
- Evidence: Verification Notes记录live分类38个场景与20项单元测试、失败修复及验证边界。
- Result clarity: 用户定义等待回复才能继续，选项与状态检查后回复继续为question，操作说明为normal。
- Bounded impact: 本轮仅扩充分类数据和测试断言，未再修改生产提示词或生命周期。
- Low risk: 仅可恢复的分类显示与测试覆盖，不涉及权限、删除、外部发布。
- Sufficient verification: 真实所选模型生产入口38/38场景通过，相关单元测试20/20通过，diff检查通过；不承诺所有自然语言或原始模型输出逐项审计。
- Task fingerprint: 3d18ece682b6f05733928572d09d4f25d53ce22ee444e0d1e8bcf9aea57d08a9

## Verification

- Passed: 测试后代码未修改，已核对最终diff与快照；Context验证通过仅保留既有警告；安装态和进程未更改。
