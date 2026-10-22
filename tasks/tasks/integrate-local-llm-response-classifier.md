# 在本地模型设置接入2B会话回复分类

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-20 20:42) |
| Artifacts | [Artifacts](../artifacts/integrate-local-llm-response-classifier/) |
| Kind | Task |

## Target
- [x] T1: 在现有本地模型设置页新增 Local LLM 区域，可部署并查看本地 Qwen3.5-2B 的可用状态，保留现有模型功能。
- [x] T2: 选用并启用本地2B后，实际使用它判断Agent完整回复是否需要用户参与或属于普通回复，并映射到现有Session状态展示。
- [x] T3: 正确处理模型未就绪、冷启动、超时或分类失败，不把失败冒充分类结果、不静默调用云端；本轮不改变会话标题的生成模型。

## Scope

- 在现有 Swift 本地模型设置和服务中增加 Local LLM/Qwen3.5-2B 选项、部署及可用性检查；复用现有 Python 鉴权 API 和 Pi 回答结束分类链。
- 通过已安装的本机 Ollama 运行 2B；只管理 App 自己的分类桥接进程，不自动安装 Homebrew、接管/停止 Ollama、重启 App/Bridge 或直接覆盖用户 Pi 安装副本。
- 不改会话标题、Shell/无 hook 会话、云端模型配置或其他并行任务。

## Decisions

- 复用现有配置 revision、analysis-enabled、provider/instance 与 generation 校验，provider 新值为 local-llm，保留 Laya/Vela 与已有持久选择，不自动替换偏好。
- 固定回环 Ollama 和 qwen3.5:2b，使用已实测的固定模型 digest；部署复用存在的权重，缺失时通过 Ollama 下载，模型文件不随 App 打包。Ollama 未运行时给出明确指引。
- 使用相同的用户参与语义和严格 JSON label 输出；生成式分类不捏造概率或 confidence，旧 Laya/Vela 概率校验保持原样。
- 分类服务启动前检查、预热模型；2B 单独使用有界较长截止处理冷启动，错误保留生命周期 fallback，不串入其他分类器或云端。
- 本轮用户未要求执行单元测试，使用 Swift/TypeScript/Python 静态检查、Debug build 和隔离本机 API 路径验证；不运行单元测试或项目套件。真实设置界面与用户当前会话验收需用户自行运行新版 App 并通过既有入口更新/reload Pi 集成。

## Plan

1. 增加本机 Ollama 2B 分类适配和部署标记，复用鉴权、连接限额、配置身份与错误边界。
2. 在 Swift 设置新增 Local LLM 部署/状态/选用入口，接通现有服务开关及分析偏好，保留原提供方功能。
3. 接通 Pi 的新 provider、无概率标签协议与独立截止，保持过期结果拒绝和标题逻辑不变；补充契约测试与说明。
4. 静态检查、构建并隔离验证真实2B分类路径，完成强制独立审查；不替换用户当前运行态。

## Task Summary

**本地模型设置与服务**：[应用组件](../../iTermate/) 在现有设置页新增 Local LLM 区域、2B 库存核验、部署与选用入口，复用安装进度/像素动画状态控件和服务生命周期；保留原有默认与持久选择，不自动安装或接管 Ollama。

**本机分类服务**：[本地模型集成](../../integrations/laya/) 新增固定本机 Ollama 2B 适配、digest 核对、已有权重复用、预热就绪与严格生成式标签协议；保留现有鉴权、连接限额和错误边界，补充契约测试及连接模板，不伪造概率或扩展通用决策能力。

**Pi 回复状态集成**：[Pi 集成](../../integrations/pi/) 新增 local-llm 提供方、无概率标签解析和独立冷启动截止，沿用原有响应身份/代际核验、生命周期映射及失败 fallback；补充解析与生命周期测试定义，没有修改标题生成链。

**本地模型说明**：[项目文档](../../docs/) 补充2B部署、启用、进程所有权、API限制、超时、共享缓存及用户安装态验收边界。

## Result

- T1: LocalModelService新增Local LLM区域、2B库存/部署/选用与独立运行时，Laya/Vela与默认Vela保留；Debug独立DerivedData构建成功，资源与源码逐字一致。隔离Python3.12实际部署复用Ollama匹配2B并预热发布Ready，未自动安装/接管Ollama。真实设置窗口未启动/观察，需用户自行运行新版App。详见evidence/build-final.log、local-llm-diagnostics-final.json、self-check.json。
- T2: 实际2B鉴权API对计算报告/选择请求/完成报告返回normal/question/normal，生产TS解析得到false/true/false，provider与instance一致；新provider进入原agent_settled/状态映射，无fake概率。标题生成函数与修改前逐字一致。原App/Bridge与用户安装Pi副本未替换，当前真实Session切换尚未验收。见evidence/actual-client-decisions.json和local-llm-diagnostics-final.json。
- T3: 2B库存核对2秒、推理6秒、Pi独立10秒截止且预热后才发布许可，保留revision/instance/generation复核与原生命周期fallback，不换模型/云端。错误revision实际启动exit1且无端点/许可；坏Token401、Origin403、通用decide400和超长输入400已观察。冷超时/取消/迟到路径静态检查并补测试定义，但未运行单元测试或人为阻塞真实服务。
- Review gate: Passed — 独立fresh只读Reviewer运行82e048ab-82d9-4d36-bd8e-c53ac39d52a1完成，reviews/round-01.md无确认问题或阻塞风险。主Agent复核snapshot SHA256=0f352f424155f1db5e9cef4797366acaf88df79d3a9a0d6e165797fe9d90a4de的35项无漂移；Context所选Pack、安装Pi副本和原App/Bridge进程一致。保留未运行单测/真实UI及当前Session验收等限制。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 新增原生设置/持久选择、Ollama部署与本机代理、跨Python/TypeScript生成式协议及生命周期截止，涉及进程所有权与信任边界，必须独立审查。
- Snapshot: evidence/snapshot.json sha256:0f352f424155f1db5e9cef4797366acaf88df79d3a9a0d6e165797fe9d90a4de
- Evidence: evidence/self-check.json、task-scoped.diff和真实隔离API诊断：Debug build、Swift/TS/Python静态检查和资源一致性通过；3条真实回复及生产解析匹配、鉴权/错误部署拒绝通过。明确未运行单测、未启动真实App/UI或替换Pi安装态。
- Task fingerprint: 4d7043f5d263c8ac27f990e6e58cfc8cbe617774682a02993b62f31c2b8ab60f

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/integrate-local-llm-response-classifier/reviews/round-01.md) | evidence/snapshot.json sha256:0f352f424155f1db5e9cef4797366acaf88df79d3a9a0d6e165797fe9d90a4de | no blocking findings；独立只读审查82e048ab-82d9-4d36-bd8e-c53ac39d52a1，保留真实UI/当前会话、完整下载和超时场景未实测的限制 |

## Verification

- Passed: 终态复核35项已审内容与独立构建资源身份一致，当前Context Pack匹配且validate通过，局部diff空白检查通过，审查报告和索引可恢复。原App/Bridge与用户Pi安装副本未替换；真实2B隔离API和生产解析证据对应当前内容，未重复执行推理。源码交付完成，真实UI、用户会话激活、完整下载/超时实测和单元测试仍未宣称通过。
