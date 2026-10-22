# 排查并修复本地模型短标题生成失败

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 15:20) |
| Artifacts | [Artifacts](../artifacts/fix-local-model-session-title-failure/) |
| Kind | Task |

## Scope

按用户纠正，将标题长度、字符、空白、标点等要求仅保留为提示词指导，不对模型返回的标题做格式强过滤、删空格或截断修复；生成、发布、显示和手动刷新路径须一致。保留通信响应有效性、空结果保护及身份/取消等安全边界。不改问题分类、归档摘要或模型设置，不运行测试套件、不重启 App/Bridge、不覆盖用户安装目录。

## Plan

1. 检查实时标题生成、发布、显示与手动刷新中的格式强过滤，明确与协议安全校验的区别。
2. 移除返回标题的格式强过滤，保留提示词要求和基本有效性保护，更新受影响的回归源码与说明。
3. 执行非测试类型/语法及构建检查，按实际风险审查并说明安装态和真实会话验证限制。

## Decisions

- 用户明确纠正并确认新版 Target：标题约束只是提示词约束，不对返回结果做强过滤。此前保留严格格式校验的方案已作废；无需删空格、修改模型服务或要求结构化输出。
- 修复后实际调用当前源码的 summarizeTask，使用相同合成输入在 533ms 返回“控制 Tab 切换会话跳过 Codex 故障”，空格原样保留，不再触发格式失败。见 evidence/manual-title-after.json。
- TypeScript 严格 noEmit、修改的 JavaScript 语法、Swift 源码/回归源码 parse、Debug 构建和 diff 检查通过；没有运行测试或 UI。排查期间外部多次更新运行实例，本会话没有安装或启停操作，不声明运行中的 Pi 已 reload。
- 初次检查的已安装集成是旧版，没有新增诊断日志；结束诊断时外部已更新为仓库副本。本会话未执行安装/重启，不能追溯用户历史两次失败的原始输出。
- 本机 qwen3.5:2b 库存 digest 符合要求，合成 Control-Tab/Codex 故障输入在 0.486 秒返回 stop，无 thinking；原始标题为“控制 Tab 切换会话跳过 Codex 故障”，空格导致当前严格校验拒绝。该观察复现同类故障，不声称还原用户历史请求。

## Task Summary

**Pi 实时标题集成**：[integrations/pi](../../integrations/pi/) 移除标题字符、元素数和状态词强过滤，只拒绝非字符串或空白结果，保留原始返回内容及提示词要求；更新生成、自动发布、手动刷新和模型对比回归源码。

**App 标题展示与刷新**：[iTermate](../../iTermate/) 不再按标题格式过滤实时显示和手动刷新结果，只保留非空及发现协议大小边界，沿用身份匹配和响应一致性保护。

**标题展示回归源码**：[iTermateTests](../../iTermateTests/) 补充空格、标点、数字、英文及超出建议长度标题的原样展示用例，保留空结果和无效身份回退覆盖；未运行测试。

**本地模型与归档说明**：[docs](../../docs/) 明确十六元素和字符格式仅为提示词指导，非空标题原样使用，通信与取消保护保持不变。

## Target
- [x] T1: 实时标题的长度和字符格式要求仅用于提示词，模型返回的非空有效标题不因空格、标点、数字或超出建议长度而被拒绝或改写。
- [x] T2: 标题生成、发布、显示与手动刷新遵循一致的非强过滤行为，同时保留协议有效性、空结果、身份和取消保护。

## Result

- T1: ../artifacts/fix-local-model-session-title-failure/evidence/checks.md：同一合成场景直接调用当前summarizeTask，533ms返回带空格原始标题；Pi仅拒绝空或非字符串，不做格式校验/清洗/截断，提示词保持原样。
- T2: ../artifacts/fix-local-model-session-title-failure/evidence/checks.md：追踪生成→自动发布/refreshTitle→Swift显示/刷新确认，仅保留非空与现有通信大小/模型/会话身份/取消保护；TS严格检查、Swift/JS语法、Debug构建通过。回归源码已更新但未执行，UI未验证。
- Review gate: Passed — 独立fresh/read-only Reviewer 2aa72a5c-8183-479b-af4c-844eb6c3a529 无 Findings；报告已保存至reviews/round-01.md。主会话核对8处产品/文档及证据哈希、产品Git diff一致；Context仅外部改动无关快捷键段落，内存还原该段后完整哈希等于快照，证明标题相关内容未漂移。
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/fix-local-model-session-title-failure/reviews/round-01.md) | sha256:6f7ec862253e79d79857b792641b356d0e68ec94bdd1ebbc0a842e18dc99c4d0 | no blocking findings；产品与标题相关内容及证据哈希一致，Context仅无关快捷键段落发生外部改动 |

## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨Pi生成/发布和Swift显示/手动刷新边界调整，保留安全校验但改变标题接纳条件；需独立检查遗漏。
- Snapshot: sha256:6f7ec862253e79d79857b792641b356d0e68ec94bdd1ebbc0a842e18dc99c4d0; ../artifacts/fix-local-model-session-title-failure/evidence/snapshot.json
- Evidence: ../artifacts/fix-local-model-session-title-failure/evidence/checks.md；非测试真实合成调用、TS/Swift/JS检查及Debug构建成功，未运行测试或UI。
- Task fingerprint: b4d822260994e2a4a1dbc41e6b1f3067aee22e02bee3c1a67c27bfdd2e8409a4

## Verification

- Passed: 终验确认审查报告与快照、作用域内容身份及证据对应；产品源码与已成功Debug构建和严格TS/Swift/JS检查一致。人工合成调用实际返回原样带空格标题，生成/发布/显示/刷新均仅有非空保护，保留通信/身份/取消。最终diff和Context检查通过；未执行测试或真实UI，未安装或主动重启运行实例。
