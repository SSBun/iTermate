# 拆分 AI 设置中的 LLM 与决策模型提供商

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-13 11:08) |
| Artifacts | [Artifacts](../artifacts/split-ai-model-providers/) |
| Kind | Task |

## Target
- [x] T1: AI 设置分为 LLM models 与 Decision models 两个区域。
- [x] T2: LLM models 提供 Codex integration、OpenAI API、DeepSeek API 与本地 Ollama 部署配置。
- [x] T3: Decision models 仅提供 OpenAI Decision API，配置与 LLM 模型独立。
- [x] T4: 标题生成与问题判断各有独立设置区；标题生成自动使用当前选中的 LLM provider，不单独选择标题模型；问题判断可选择 LLM models 或 Decision models，并执行对应推理和结果解析。
- [x] T5: LLM providers 与 Decision models 各有测试入口，可查看测试结果和失败原因。

## Plan

1. 核对提供商的认证方式、现有标题及问题判断调用路径，确定独立配置与旧配置兼容方式。
2. 实现提供商配置、独立功能设置与测试入口，并接入对应调用路径。
3. 执行获准的编译和静态检查，核验配置与错误处理，并完成独立审查；不运行单元测试或项目测试套件。

## Execution Log

### 001 — 设置结构与调用边界

当前 AI 页只有标题自动补全与 Local LLM 两区，标题生成和问题判断共用本地模型。用户要求改为 LLM models 与 Decision models 提供商配置，并进一步要求标题生成、问题判断各有独立设置区，标题自动使用所选 LLM provider，两类提供商均有测试入口。尚未修改产品源码。Codex integration 的认证语义仍待确认；此前已询问是否复用本机 Codex CLI 的 ChatGPT 登录，用户本轮补充未明确回答。

### 002 — 问题判断双路由

用户明确修订：问题判断必须允许选择普通 LLM 或 Decision models，且实现对应调用与解析。默认保留普通 LLM，本地 Ollama 配置继续有效。标题始终使用所选 LLM。Codex integration 暂按复用本机 Codex CLI 登录实现，界面明确该语义；不运行嵌套 Codex 做开发或验证。OpenAI Decisions 接口按本机 SOP 的 predicate 请求结构实现并严格验证概率；未获授权发送真实会话验证。现有源码尚无远程提供商配置，需同时覆盖 Swift 的 Codex 会话标题路径与 Pi 的标题/判断路径。

### 003 — 实现与静态核验

新增独立 AI 配置与 Keychain 凭据访问、四区设置页、两类测试菜单及显式 Ollama 模型下载入口。Pi 标题/判断与 Swift 的 Codex 标题均接入所选提供商；问题判断按普通 LLM 标签或 Decision predicate 概率解析，保留十秒总预算与 normal 默认值。配置读取失败不覆盖，写入加锁后重读合并，结果发布前检查配置身份。应用启动仅在选中 Ollama 时预热本地模型。

已执行无签名 Debug 构建、TypeScript 严格类型检查和 git diff --check；未运行单元测试或项目套件，未调用真实远程模型、Codex 登录或 Ollama 下载，也未启动或替换已安装应用。Codex CLI 的参数与特性开关通过只读 help/features 查询核对。远程账号权限、模型可用性、Keychain 跨进程首次授权和实际 GUI 交互仍需用户运行新版后通过设置验证。

### 004 — 首轮审查修正

已保存首轮独立报告并通过 check-evidence 核对审查快照一致。确认 TR-1：URLRequest.timeoutInterval 只约束请求等待，不能保证 Swift 标题操作总截止；新增覆盖本地/远程与两轮生成的结构化任务组，六十秒计时器到期抛错并取消生成子任务，URLSession.data(for:) 随任务取消实际网络请求，Codex 子进程沿既有取消路径停止。确认 TR-2：统一自动标题、手动刷新和诊断适配器说明，明确使用选中 LLM provider、远程提供商接收摘录及 Ollama 条件。修正后需刷新编译与审查证据；本次仍不运行测试套件或真实模型。

## Task Summary

**AI 设置与模型服务**：[应用组件](../../iTermate/)新增独立提供商配置、Keychain 凭据管理、远程标题生成、功能分区及测试菜单；本地服务增加主动部署与固定示例判断能力，保留原有模型配置。

**Pi 集成**：[集成组件](../../integrations/pi/)增加 OpenAI、DeepSeek、Codex 标题与 LLM 判断调用，以及 OpenAI Decision predicate 判断路径，保留取消、超时和配置身份检查。

**工程与文档**：[Xcode 工程](../../iTermate.xcodeproj/)登记新增源码；[使用文档](../../docs/)说明配置、内容发送、双判断路径、测试与运行态更新要求。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | A | 沿用既有 LocalLLMService 与 Pi 生命周期，只新增共享配置和各运行时所需的提供商客户端。 | Swift 与 TypeScript 各自处理协议，后续接口变化需同步维护。 |
| 稳定性 | A | Debug 编译、TypeScript 类型检查及静态路径核对覆盖配置、解析、取消与默认值；独立审查另行执行。 | 未运行测试套件、真实 API、Codex 认证、Keychain 跨进程授权或 GUI 验证，不承诺运行态已切换。 |
| 完整性 | A | 五项目标均已有对应设置、调用和解析实现，见 Result 与源码。 | 远程账号和模型可用性需要用户在设置测试菜单验证；本次不安装或发布。 |

## Result

- T1: AISettingsView 的 LLM models 与 Decision models 为独立 Section；Debug 构建通过，尚未进行实际 GUI 验收。
- T2: AIProvider 列出 Ollama/Codex/OpenAI/DeepSeek；Swift 与 Pi 按 provider 分流，LocalLLMService.installModel 显式下载所选模型。编译与类型检查通过；未调用真实服务或下载。
- T3: Decision models 固定 OpenAI Decision API，独立 decisionModel 与 Keychain decision 账户；predicate 数量、类型及有限概率值检查已核对。未作账号连通验证。
- T5: AISettingsView 两类 Menu 均接入固定示例请求并展示文本/标签/概率、耗时和脱敏错误。Debug 构建见 ../artifacts/split-ai-model-providers/evidence/debug-build.log；测试菜单未在真实服务上执行。
- T4: 两种问题判断路由与独立功能设置实现；首轮审查后为 Swift 标题增加六十秒结构化任务组总截止，取消传播至 URLSession 与 Codex 子进程。修正后 Debug 构建与 tsc 严格检查通过；未作真实 API/GUI 验证。
- Review gate: Passed — 第二轮独立审查报告 round-02 无新发现，TR-1/TR-2 均 resolved；owner check-evidence 验证当前快照及首轮报告一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 提供商认证、隐私与双运行时路由仍需独立审查；TR-1/TR-2 已修改，待新 pass 核验。
- Snapshot: snapshot:tasks/artifacts/split-ai-model-providers/evidence/856fcca8da05f4fe97df6c9fa0356aa0ba88e9e690b200c63ce089f12abb0077.json#856fcca8da05f4fe97df6c9fa0356aa0ba88e9e690b200c63ce089f12abb0077
- Evidence: Result T1-T5；修正后 Debug 构建、tsc、git diff --check 通过；限制见 Execution Log 003/004。
- Task fingerprint: 50ff9f7a2d6d6ba3d86779899f38c6c653c7af069b1b74daabbc3306539b890c
## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/split-ai-model-providers/reviews/round-01.md) | snapshot:tasks/artifacts/split-ai-model-providers/evidence/d4601c4c50ad9773fd7b88a8b8bf313d6f5a361f8dd777db54400f17c2fb7a55.json#d4601c4c50ad9773fd7b88a8b8bf313d6f5a361f8dd777db54400f17c2fb7a55 | findings | 506739b4c7a2d3568a580f4a12c0283d7807af92a76716ed0dd7e5907b9cd771 |
| 02 | [Round 02](../artifacts/split-ai-model-providers/reviews/round-02.md) | snapshot:tasks/artifacts/split-ai-model-providers/evidence/856fcca8da05f4fe97df6c9fa0356aa0ba88e9e690b200c63ce089f12abb0077.json#856fcca8da05f4fe97df6c9fa0356aa0ba88e9e690b200c63ce089f12abb0077 | no blocking findings | 481af3592f695996caa688871728f0936ed507a9d7ffcde22f990f643a072d72 |

## Verification

- Passed: 最终 tsc noEmit strict 单独执行 exit 0；git diff --check 单独执行 exit 0；check-evidence 验证当前13文件快照及两份审查报告。修正后 Debug 构建已通过，源码之后未变化。第二轮独立审查无新发现且 TR-1/TR-2 resolved；未运行测试套件、真实API、认证、GUI或下载，也未替换安装态。
