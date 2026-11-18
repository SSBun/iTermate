# 评估 OpenAI Decision 回复分类准确性

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-13 16:10) |
| Artifacts | [Artifacts](../artifacts/evaluate-openai-decision-reply-precision/) |
| Kind | Task |

## Plan

1. 从生产代码提取 Decision 模型、predicate 和阈值，确认样例及已保存 Decision 凭据。
2. 顺序执行 38 个固定样例，每个请求十秒截止、不自动重试，保存每条有效响应或失败。
3. 独立重算混淆矩阵、精确率、召回率和准确率，核对误判与覆盖限制。

## Execution Log

### 001 — 评估口径与能力预检

固定模型为生产常量 gpt-6-luna，predicate 从当前 classifyWithOpenAIDecision 提取，阈值0.5，样例38条（question20、normal18），合同记录语料及生产 Decision 分支哈希。当前日常配置仍为 questionEngine=llm，本次直接评估 Decision 路径，不修改设置。

当前 App 的请求 socket 不存在，因此不通过生产 IPC 传输。非交互 Keychain 查询已确认 decision 账户可读，未输出密钥。评估工具直接请求官方 Decisions HTTPS，使用同一个已保存凭据和逐字段一致的生产请求/概率规则；这是模型精度评估，不冒称完整 App/Pi 集成验收。有效判断与服务失败分开，避免生产 normal 默认值掩盖调用失败。

### 002 — 工具准备

现有 reply-classification.test.ts 的离线检查已通过，真实 live 分支明确关闭，避免误测当前普通 LLM。已编译独立评估工具；凭据仅在进程内读取，请求顺序执行、十秒资源截止、禁止重定向、不重试，每条结束后原子保存检查点。遇到400/401/403/404/429或连续三次服务失败即停止后续请求，避免无效消耗。尚未发送模型样例。

### 003 — 38条真实请求完成

已顺序执行38次官方 POST /v1/decisions，全部HTTP200，返回模型均为gpt-6-luna，均通过单个predicate及有限[0,1]概率验证。没有重试或服务失败。保持生产predicate与0.5阈值不变，没有改用普通LLM，也没有修改配置。结果逐条保存在evidence/results.json。

重新从原始probability计算分类并核对expected标签与语料哈希，生产Decision分支哈希保持一致。混淆矩阵TP18、FN2、FP0、TN18；36/38正确，准确率94.7368%，question精确率100%、召回率90%、F1为94.7368%。两条漏判分别是english-status-continue-gate（0.49）与reload-with-explicit-response-request（0.46），均要求操作后回复。没有把普通回复误判为提问。

平均请求耗时1168.03ms，中位754ms，P95为2317ms，最大2366ms；包含客户端网络与模型响应，不是纯推理时间。累计返回用量input_tokens9186、output_tokens0、total_tokens9186；未查询价格，不推算费用。概率不是正确率或校准结论。测试为固定38条单次回归，不能推导未见样本泛化率；未验证App/Pi IPC集成。

## Task Summary

未修改生产源码或配置。仅保存评估合同、独立执行工具、38条脱敏结果与重算指标，作为本任务证据。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | S | 复用现有38条语料及生产predicate/模型/阈值，以独立工具避免normal失败默认值污染统计；不改产品。 | 独立HTTP传输不覆盖生产IPC。 |
| 稳定性 | A | 38条均HTTP200且模型/概率有效；逐条重算并校验语料及合同哈希，失败单列且不重试；凭据不落盘或输出。 | 单次固定语料不能证明概率校准或泛化表现，延迟含网络。 |
| 完整性 | S | 38/38有效结果，准确率、精确率、召回率、混淆矩阵、误判、耗时和实际返回用量均已记录，设置未改。 | 明确不包含后续提示词调优、阈值调整或App端到端测试。 |

## Target
- [x] T1: 使用现有38条回复分类样例和已配置OpenAI Decision模型完成真实评估，区分有效判断与调用失败。
- [x] T2: 报告准确率、question精确率/召回率、混淆矩阵及误判样例，并披露模型、阈值、调用与覆盖限制。
- [x] T3: 仅发送固定样例，不读取真实会话、不泄露凭据，不改模型或生产判断设置。

## Result

- T1: 38条固定样例均真实返回HTTP200、gpt-6-luna和有效predicate概率；0调用失败、0重试，未将normal兜底当作模型结果。
- T2: 独立重算TP18/FN2/FP0/TN18，准确率36/38=94.7368%，question精确率100%、召回率90%；metrics.json记录误判原文、耗时和返回用量。Node另行核验算术成功。
- T3: 只发送固定语料；使用已保存decision Keychain凭据但不落盘或输出；未改生产源码/模型/阈值或questionEngine设置。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 交付为实际评估结论，无请求的生产交付文件改动；仅新增任务拥有的执行证据。
- Snapshot: snapshot:tasks/artifacts/evaluate-openai-decision-reply-precision/evidence/3d5e3718c2246c69f87f1b3ab7d7334b70d6cd7190c213a5d03e564c4069e68e.json#3d5e3718c2246c69f87f1b3ab7d7334b70d6cd7190c213a5d03e564c4069e68e
- Evidence: Task执行日志003、results.json、metrics.json、offline-tests.log与arithmetic-check.log；实际38次返回与生产合同一致。
- Task fingerprint: 354c480932e57fa4391c265832374004e2ea7959d6965b30e11122b089fdd688

## Verification

- Passed: 语料与生产Decision分支哈希一致；逐条概率/标签/HTTP/模型校验通过；Node重算矩阵和指标与Python一致；git diff --check及当前7文件check-evidence通过，临时二进制已删除。
