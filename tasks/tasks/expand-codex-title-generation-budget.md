# 扩大 Codex 标题输出预算并支持再次摘要

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 18:10) |
| Artifacts | [Artifacts](../artifacts/expand-codex-title-generation-budget/) |
| Kind | Task |

## Scope

仅修改原生 Codex 的本地标题输出预算与有界二次提炼，自动及手动共用。不改变 Pi、问题分类、归档、会话状态及标题所有权路径。不运行单元/项目测试，不安装、覆盖或启动/重启用户运行的 App、Bridge、Pi、Codex、Ollama。

## Decisions

- 用户已确认扩大输出预算，首轮过长可再概括一次，最终标题不要求固定字数；保留非空、响应及身份有效性保护。
- 单次生成上限由64提高到1024 tokens，上下文请求仍为16384；这不是标题字数限制。完整草稿超过80字符或含多行时最多提炼一次；首轮length响应只作草稿，最终响应必须正常stop。二次结果非空且有效即原样返回，不裁剪、不再按字数检查或继续循环。
- 首轮去除数字式字数/元素要求，保留最新的核心目标概括规则和示例。再次提炼同时参考原对话和草稿，不把草稿当指令。
- 两轮绑定初始模型选择/库存digest，每轮校验取消和前后身份；二次失败保留原标题并沿用现有错误日志。每次HTTP保留既有超时，单个外层尝试最多两次chat，外层尝试预算不变。

## Plan

1. 扩大Codex预算并移除字数要求，实现首轮正常或截断草稿的有界二次提炼，最终只返回完整有效标题。
2. 更新直接相关说明与Context，核对Pi及Store身份/状态路径未受影响。
3. 进行Swift语法、非启动Debug构建与许可范围内的合成调用检查，记录限制并执行风险相称的独立审查；不运行测试套件。

## Task Summary

**原生 App**：[iTermate](../../iTermate/) 将 Codex 标题单次输出预算扩大为1024 tokens，移除固定字数提示，首轮冗长/多行或截断草稿最多再提炼一次；最终完整有效标题原样返回，并保留模型配置、库存与取消保护。

**使用说明**：[docs](../../docs/) 说明输出预算与字数限制的区别、有界二次提炼、截断草稿不可展示及仅Codex生效的边界。

## Target
- [x] T1: Codex 标题生成使用更充足的输出预算；首轮结果过长时可再调用模型摘要，避免当前64-token上限导致的失败。
- [x] T2: 最终标题不要求固定字数，不因字数超限被拒绝或截断；保留非空、响应有效性及会话身份安全保护。

## Result

- T1: evidence/checks.md逐条件核对1024预算、首轮long/multiline/length仅触发唯一二次调用，草稿不发布且最终必须stop；Debug构建11.890秒通过。实际生产服务合成调用0.699秒返回调整终端会话标题生成策略；第二轮只做源码/类型验证，未运行测试。
- T2: 首/二轮提示词均无固定字数，最终直接return result.text无长度过滤或裁剪；保留每轮模型/响应/空结果/库存配置和取消校验，Store及Pi源码哈希不变。diff/Context检查通过，未安装或重启用户App；具体检查及限制见evidence/checks.md。
- Review gate: Passed — fresh只读Reviewer c28d823e-7bd0-42e8-bdb3-7a6c0cb8b59b无Findings；报告已保存reviews/round-01.md并索引。主会话实际重算快照全部文件SHA-256，drift=[]，已补齐Reviewer工具限制；二次路径未动态验证继续披露。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 从单轮严格结束改为允许截断中间草稿并有界二次提炼，涉及模型响应有效性、取消及跨轮配置/库存一致性；二次路径未运行测试，需独立检查遗漏。
- Snapshot: sha256:c25da4729e4966a2c59eacb0666e1661ad6a430474bc2b751a241995ac2342dc; tasks/artifacts/expand-codex-title-generation-budget/evidence/snapshot.json
- Evidence: checks.md逐Target源码核对及已披露覆盖限制；Swift parse/Debug build通过，直接实际生产服务本机合成调用成功；Pi/Store/logger/工程哈希不变。
- Task fingerprint: b0ea05d097aa6e1075e6b6b338f93d50ec93eb25b7eb9b1c1d3ca7ab4c06ca15

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/expand-codex-title-generation-budget/reviews/round-01.md) | sha256:c25da4729e4966a2c59eacb0666e1661ad6a430474bc2b751a241995ac2342dc | no blocking findings；主会话逐文件重算SHA-256确认drift=[]；动态覆盖限制已披露 |

## Verification

- Passed: 终验快照全部SHA-256无漂移，独立报告已保存且无Findings；Swift parse/diff/Context和Pi/Store/logger/工程未变检查通过。内容对应成功Debug构建及生产服务0.699秒合成调用；未跑测试，二次分支仅静态/编译检查，未重启安装App。
