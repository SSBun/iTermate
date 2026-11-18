# 远程 LLM 模型列表与思考等级设置

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-13 15:28) |
| Artifacts | [Artifacts](../artifacts/remote-model-list-and-thinking/) |
| Kind | Task |

## Plan

1. 核对提供商的模型列表、思考参数与能力说明，明确未知型号的默认行为。
2. 接入主动获取列表、保留手动输入与所选模型对应的思考设置，覆盖 Swift/Pi 请求。
3. 执行编译与静态检查，核对请求取消和旧配置兼容，完成独立审查；不执行真实生成或测试套件。

## Execution Log

### 001 — 接口事实与范围

截图涉及 OpenAI API 的 Model ID 和密钥。按远程 LLM 设置同时覆盖 OpenAI 与 DeepSeek，保留现有 Codex、本地 Ollama 和固定的 Decision 模型。已读取官方模型列表与 reasoning 文档：OpenAI GET /v1/models 主要返回基本信息，不能据此推断所有模型支持的思考等级；已逐个核对常用 GPT-6/5.6/5.5/5 型号。DeepSeek GET /models 可返回 effort.supported_levels；当前 deepseek-flash/v4-pro 支持 thinking enabled/disabled 和 low/high/max。未知模型不推断等级，保留默认。

### 002 — 实现路径

新增两类远程提供商的 Fetch Models 与 Choose Model；目录只驻留内存，保存密钥后清空旧目录。获取使用保存的 Keychain 密钥、固定官方 HTTPS GET、十五秒总截止，不发送对话；切换提供商或更新密钥取消旧请求并以请求身份拒绝迟到结果。列表过滤已知非文本模型，并提示 API 可见不等于所有端点兼容。

手动输入与菜单选择共用模型更新逻辑。能力与思考等级以提供商/模型绑定，可选配置字段保证旧配置可读；换模型恢复默认。OpenAI 使用 reasoning.effort，DeepSeek Off 使用 thinking.disabled，其余等级使用 thinking.enabled 和 reasoning_effort；Swift/Pi 标题及 LLM 判断共用对应客户端。尚未执行本阶段构建或实际模型列表请求。

### 003 — 初步验证与凭据边界

初次 Debug 构建、严格 TypeScript noEmit 和 git diff --check 通过。尝试一次只读 OpenAI 模型目录核验，但 security 工具读取已保存密钥在五秒处超时，未发出 API 请求、没有获取模型响应，也未自动重试。脱敏观察保存于 evidence/model-list-observation.json，不能当作目录连通成功。

为使 Fetch Models 不因认证弹窗等待而看似无响应，该操作的 Keychain 查询使用禁止交互模式；额外授权不足时明确提示在当前应用保存/授权后重试，不绕过权限。其他既有生成请求保留原有认证方式。请求前后增加取消检查，测试菜单在列表获取期间禁用，避免获取能力更新造成并行测试结果失效。此轮补充后需要重新编译。

### 004 — 最终自检与限制

最后一次无签名 Debug 构建、严格 TypeScript noEmit、git diff --check 均独立返回成功。静态核对列表操作无请求体、官方地址固定、共享重定向策略拒绝跳转；解析验证 data/id、去重并排序；请求身份及取消保护覆盖切换和密钥更新。Swift 与 Pi 的可选配置、model 绑定、默认省略参数、OpenAI/DeepSeek 字段一致。

没有启动 GUI 预览，避免再次抢用户焦点。没有执行测试套件或真实生成。实际模型目录查询未越过 Keychain 读取步骤，不能宣称验证了真实列表、全部账号权限或完整 UI 交互；DeepSeek 列表及动态能力依据官方文档和源码核对。构建日志与脱敏失败观察已保存。代码冻结后进入独立审查。

## Task Summary

**AI 模型服务与设置**：[应用组件](../../iTermate/)新增官方模型目录获取、内存目录缓存、手动/菜单选择与模型绑定的思考设置；获取状态和错误就近显示，取消旧请求并保护密钥访问。

**Pi 集成**：[集成组件](../../integrations/pi/)读取并校验可选思考配置，按所选模型给 OpenAI 或 DeepSeek 请求添加对应字段，覆盖标题与普通 LLM 判断。

**使用文档**：[文档](../../docs/)说明模型目录、能力来源、未知模型默认、凭据权限和思考参数，补充官方参考及验证边界。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | A | 复用既有 Keychain、HTTP 客户端与配置存储，只增加目录状态和模型绑定能力记录；无新依赖。 | Swift 与 TypeScript 保留各自请求实现，能力表需随官方说明维护。 |
| 稳定性 | A | Debug 编译、严格 TypeScript 检查与 diff 检查通过；静态核对旧可选配置、取消、身份及参数分流；固定地址与无交互 Keychain 失败路径明确。 | 只读目录实测因凭据工具超时未发请求；无真实服务、GUI 或测试套件覆盖，独立代码审查另行执行。 |
| 完整性 | A | T1-T3 均有对应入口、模型目录、手动覆盖、能力约束和两端调用，操作附近显示状态。 | 未替换安装态，完整 UI 和真实账号模型组合需用户运行新版验证。 |

## Target
- [x] T1: OpenAI API 和 DeepSeek API 保存密钥后提供获取模型列表入口，模型可手动输入或从列表选择。
- [x] T2: 根据所选模型提供适用的思考选项，并将配置用于 Swift/Pi 的标题和普通 LLM 问题判断调用。
- [x] T3: 获取列表的进度、结果和失败原因可见，不泄露密钥，不发送真实会话内容，保留现有配置。

## Result

- T1: AISettingsView提供Fetch Models/Choose Model并保留手动输入；服务读取保存密钥对OpenAI /v1/models或DeepSeek /models发GET，解析去重文本候选。源码和编译核验；实际目录查询因Keychain工具超时未发出。
- T2: 根据DeepSeek元数据或已核对官方型号说明提供选项，未知保留默认；换模型重置，配置绑定provider/model。Swift/Pi分别使用OpenAI reasoning.effort或DeepSeek thinking/reasoning_effort，覆盖标题和LLM判断。Debug与tsc通过，未实际生成。
- T3: 状态和错误置于按钮附近；GET不发送会话，固定HTTPS且拒绝重定向，Keychain非交互失败明确提示；切换/存新密钥取消旧请求，requestID拒绝迟到结果。无密钥写入配置/日志。静态核验；未GUI实操。
- Review gate: Passed — 独立只读复查round-01无确认发现；owner check-evidence验证六文件冻结快照一致。真实目录查询及GUI/生成限制保留。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 新增认证GET目录请求、取消与能力状态、配置和双运行时思考参数，需独立审查。
- Snapshot: snapshot:tasks/artifacts/remote-model-list-and-thinking/evidence/f6ea524a3e28504f3ffdb50c61ba0dadb5d97da50d48268196d26943aedf5ff3.json#f6ea524a3e28504f3ffdb50c61ba0dadb5d97da50d48268196d26943aedf5ff3
- Evidence: Result T1-T3；最终Debug/tsc/diffcheck成功；实际目录查询受Keychain限制，观察JSON明确未发请求。
- Task fingerprint: 6d8362540f44689564113d4c2c34ecf2972685d46e2d83d1b44338a79bfdcccc

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/remote-model-list-and-thinking/reviews/round-01.md) | snapshot:tasks/artifacts/remote-model-list-and-thinking/evidence/f6ea524a3e28504f3ffdb50c61ba0dadb5d97da50d48268196d26943aedf5ff3.json#f6ea524a3e28504f3ffdb50c61ba0dadb5d97da50d48268196d26943aedf5ff3 | no blocking findings | a0adc6c0abd3f6229d623bb4a11f51758e0793c5f450383cac2bb63ac8434397 |

## Verification

- Passed: 最终严格tsc及git diff --check分别exit0；check-evidence核验六文件快照和审查报告。源文件自成功Debug构建后未变，独立审查无发现。未取得真实列表响应（凭据读取超时），未GUI、生成、测试套件或安装态验证。
