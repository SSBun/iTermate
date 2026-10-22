# 添加远程与本地2B会话标题生成对比测试

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-20 18:35) |
| Artifacts | [Artifacts](../artifacts/compare-session-title-model-tests/) |
| Kind | Task |

## Target
- [x] T1: 新增可重复运行的会话标题生成测试，用相同对话摘录和iTermate现有标题规则比较远程LLM与本地Qwen3.5-2B。
- [x] T2: 对比测试保留两侧生成标题与耗时，并校验现有标题约束；不以两个模型必须生成完全相同文字作为通过条件。
- [x] T3: 默认单元测试不依赖真实网络；真实模型对比须显式启用且使用合成会话，不自动上传真实会话历史，不切换iTermate生产模型。

## Scope

- 在 Pi 集成现有测试目录增加标题生成对比测试，补充本地运行说明；复用真实的摘录及标题生成函数。
- 不修改生产标题或状态分类路径，不安装依赖或重载用户集成，不启动/重启 App、Bridge、Ollama，不读取真实会话记录或远程凭据文件。

## Decisions

- 用户确认默认离线单元测试与显式启用的真实模型集成比较分开，真实比较只使用固定合成对话，不更改生产模型。
- 两种适配器都经同一个 summarizeTask 及相同 excerpt；远程采用显式配置的 HTTPS OpenAI 兼容 Chat Completions 接口，本地固定回环 Ollama qwen3.5:2b。远程地址、模型和 Bearer key 均显式提供，不猜测账号或复用用户真实历史。
- 标题的 80 字符是硬上限，尽量不超过 24 字属于偏好指标；比较保留双方标题、延迟和违规信息，不以标题完全相同为通过条件，也不将格式合格等同于语义质量合格。
- 默认测试全部模拟网络，真实比较门关闭时不检查凭据、不启动模型请求；真实门开启而配置缺失时明确失败，不能静默跳过或降级到另一模型。
- 当前请求授权编写测试，未明确要求运行测试；本轮执行语法/类型与静态检查，不运行单元测试、真实模型比较或项目套件，交付时如实说明。

## Plan

1. 用固定合成会话覆盖普通任务、目标转移和可见文本过滤，复用生产摘录与标题函数实现两个测试适配器及结果收集。
2. 增加离线断言，覆盖输入/提示词一致、不同合法标题、长度/格式、失败保留、请求取消、远程配置与无网络默认门。
3. 增加显式启用的双模型比较入口和说明，只输出合成场景的标题、延迟与检查结果；静态验证并按实际风险完成审查。

## Task Summary

**Pi 标题测试**：[Pi 集成测试目录](../../integrations/pi/) 新增一个测试文件，包含八个离线测试及一个显式开启的真实双模型比较测试；复用生产摘录和标题生成函数，增加 HTTPS 远程与固定回环 2B 测试适配、结果收集、结构检查及凭据脱敏，没有修改生产生成或状态路径。

**会话功能说明**：[会话文档](../../docs/pi-session-archives.md) 仅新增标题测试运行方式、显式远程配置、合成数据范围、费用与质量验证边界；其他已有内容保持不变。

## Result

- T1: 新增integrations/pi/session-title-model-comparison.test.ts，直接导入生产taskSummaryExcerpt/summarizeTask，三个固定合成场景经相同摘录和prompt进入显式远程HTTPS与回环qwen3.5:2b测试适配器。默认8项离线测试与1项opt-in真实比较分离。语法与严格类型检查通过；未执行测试。
- T2: 比较收集双方标题、端到端耗时、结构违规与24字偏好；80长度为硬限制，不要求逐字相同；任何一侧失败仍记录另一侧结果并使live比较最终失败。静态核查及离线断言覆盖不同合法标题、无效输出、取消和脱敏。这里只交付测试代码，未取得真实模型标题比较结果。
- T3: 真实fetch仅在显式live门内，缺少远程配置失败，只用固定合成对话且无会话/凭据文件读取，拒绝重定向并脱敏。测试/文档未变，9个直接依赖和Pi安装副本哈希稳定；Laya运行配置已在外部变化，测试不读取它，本任务未改或回退；见runtime-config-drift.json及relevant-protected-files-final.json。未运行测试或模型请求。
- Review gate: Passed — fresh独立只读Reviewer运行804cc3af-0f52-4ebd-840e-0a0eb16e7cda，reviews/round-02.md无确认问题或阻塞风险；独立核查Laya配置不属于标题测试输入链。主Agent终态重核snapshot-02 SHA256=34ceed6960ac201deb5607d889e184938de04f7a792224b32e0bfcaaf8f7c82f，23项和9个相关保护文件均未漂移；未运行测试的限制保留。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 保留远程适配与凭据边界的R2独立审查义务；终态发现不被测试读取的外部运行配置变化，刷新证据范围并复核，代码与文档无变化。
- Snapshot: evidence/snapshot-02.json sha256:34ceed6960ac201deb5607d889e184938de04f7a792224b32e0bfcaaf8f7c82f
- Evidence: evidence/self-check-final.json及runtime-config-drift.json：新增测试与文档、生产标题直接依赖身份未变，9个保护文件一致；仅排除实际未被测试读取的Laya运行配置并保留变化证据。语法/类型检查沿用同一未变内容，未执行测试或模型调用。
- Task fingerprint: a12ccd79750d384dfd9136d139552cc400a31d98b75b404a8d96f9e6d7055efe
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/compare-session-title-model-tests/reviews/round-01.md) | evidence/snapshot.json sha256:104427d11910c96bbb3f08669dba23109a27ac8b9c721a5dbf2671943611d6da | no blocking findings；终态前发现未被测试读取的外部Laya运行配置变化，更新证据范围后重新审查 |
| 02 | [第 02 轮](../artifacts/compare-session-title-model-tests/reviews/round-02.md) | evidence/snapshot-02.json sha256:34ceed6960ac201deb5607d889e184938de04f7a792224b32e0bfcaaf8f7c82f | no blocking findings；独立确认动态配置不在标题测试输入链，保留未运行测试的覆盖限制 |

## Verification

- Passed: 终态核验新测试/文档及审查scope23项内容身份一致、9个相关已有文件未变，审查报告和索引可恢复；先前语法与严格类型检查对应同一代码版本，Context validate、局部diff与新测试空白检查通过。仅完成测试编写与静态核验，未执行单测、live比较或模型调用，无实际标题质量结果。
