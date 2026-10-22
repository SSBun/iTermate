# 本地模型统一用于问题判断与标题生成

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 12:06) |
| Artifacts | [Artifacts](../artifacts/local-llm-only-question-and-title/) |
| Kind | Task |

## Scope

- 旧Decision实现、模型缓存与历史偏好保留以便未来恢复；当前构建停用其API服务器、本地推理入口、设置界面及连接凭据展示，不只是隐藏地址。
- 新流程直接访问固定回环Ollama中的既有Qwen3.5-2B，不新增公开服务，不自动下载或卸载模型，不替换用户安装态或重启App/Bridge。
- Pi问题判断与实时任务标题使用新本地流程；会话归档的多句摘要不是任务标题，保持原有行为。
- 标题原始输出超过十六元素或带标点、空白、数字时拒绝并保留旧标题，不通过清洗伪装合规；模型不可用时不回退旧Decision或云端。
- 当前请求未授权运行单元测试或全套测试；使用构建、语法/类型检查及本地合成输入的手工调用观察，不声称已进行真实UI验收。

## Plan

1. 为旧体系的Swift入口、Python入口与Pi调用链增加关闭门，保留实现；设置替换为Local LLM专用状态页面。
2. Pi新增固定回环Ollama请求路径，统一问题分类与短标题生成的模型身份、超时、取消和十分钟keep_alive；保留生命周期和标题失效保护。
3. 更新受影响的测试源码与说明，构建并检查调用路径、原始标题格式与失败处理，记录限制。
4. 主Agent自查后按R2提交独立只读task-review，处理确认的问题后最终验证。

## Task Summary

**应用本地模型与设置**：在 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/) 保留旧Decision实现并关闭其启动、下载、调用、设置和凭据入口；App改用独立LocalLLMService及专用设置页检查并预热Ollama，实时标题显示和手动刷新响应按原始十六元素规则校验。

**Pi集成**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 将问题分类和任务标题默认路径统一为固定回环Ollama，增加库存身份、超时、取消、响应边界与原始输出校验；每次推理请求十分钟空闲驻留。标题不再要求当前Pi模型；旧Decision本地链保留但关闭。更新对应测试源码和隔离适配器，未执行测试套件。

**旧Decision后端**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/laya/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/laya/) 为旧API服务器、模型推理与下载入口添加关闭门，保留实现与隔离回归源码以便恢复。

**模型与归档说明**：在 ["/Users/caishilin/Desktop/personal/iTermate/docs/"](file:///Users/caishilin/Desktop/personal/iTermate/docs/) 说明旧体系暂停、新本地模型流程、十分钟驻留、标题格式与归档多句摘要的边界。

## Decisions

- 用户已确认完整Target；随后明确旧体系源码保留以便日后恢复，当前只屏蔽所有入口与使用，不删除模型缓存或历史偏好。
- 本轮不会启动、重启、安装或替换运行中的App、Bridge、Pi集成；运行态旧进程仍需用户自行运行新版App并reload集成后切换，构建不代表切换完成。
- Swift Debug构建成功，TypeScript严格类型检查及修改的JavaScript/Python语法检查通过；未运行单元测试、全套测试或UI自动验收。
- 手工本地调用使用合成文本，不读取真实会话；问题请求确认与完成报告分别返回true/false，标题在没有当前Pi模型的上下文中成功生成并通过元素校验。观测见evidence/manual-local-call.json。
- 手工预热同一固定模型后，Ollama报告过期时间距观测约600秒，见evidence/manual-warmup.json。只验证协议与实际驻留期限，不保证共享Ollama在内存压力下永不提前卸载。
- 旧CLI实际调用返回关闭错误、退出码1，且未创建指定目录，见evidence/legacy-cli-blocked.log。构建后的旧服务入口未启动。

## Target
- [x] T1: 完整停用旧Decision体系，包括其API服务、本地调用逻辑、应用入口及设置页面，不只是隐藏服务地址；本地模型能力仅保留新的Local LLM流程。
- [x] T2: 问题类型判断和会话标题生成均使用本地小模型，不调用云端模型或其他decision模型。
- [x] T3: 本地模型每次推理后保持十分钟热驻留，并保留问题判断与标题生成的失败处理。
- [x] T4: 标题沿用已确认的最多十六元素规则，汉字逐字计数、英文技术词或缩写整体计一元素，不含标点、空白或数字。

## Result

- T1: 源码关闭门阻断Swift启动/下载/设置/凭据、Pi旧Decision调用及Python服务和推理入口，App仅接入新LocalLLM设置；手工旧CLI返回disabled、退出码1、未建目录。代码与缓存保留；旧运行实例未主动终止，需用户自行运行新版后生效。
- T2: 手工调用当前源码的合成问题分类返回true/false；无ctx.model的上下文成功生成十五元素中文标题。默认请求仅固定回环Ollama并校验模型digest，无旧API/token或云端后备；归档多句摘要保持原有独立路径。见manual-local-call.json。
- T3: Swift预热及Pi问题/标题生成均传keep_alive=10m。manual-warmup.json观测03:56:01Z预热完成后Ollama expires_at为04:06:01Z，约600秒；超时/取消/非法响应保持旧生命周期或标题。不声称内存压力下必定常驻。
- T4: Pi与Swift消费者均直接校验汉字/英文词、十六元素和禁用字符，不进行trim或替换；当前本地手工标题十五元素通过。相关边界/取消/分类测试源码已更新并通过严格类型检查，未运行单元测试或全套测试；模型原始结果仍可能被拒绝。
- Review gate: Passed — Fresh只读reviewer运行fce6f5c6-2456-42a8-9443-359bab476197检查当前round-01快照，无确认发现或阻塞风险；反馈已保存reviews/round-01.md并索引。主Agent重算所有源码和证据SHA256，无漂移。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨Swift设置与启动、Pi异步推理和标题生命周期、Python旧API关闭，涉及本地通信及失败/取消边界，需独立检查遗漏。
- Snapshot: sha256:3b5d8a950cb4ce1028a7dc76df3ad181cdda06390f4a750afd0723a4c605f8d1; tasks/artifacts/local-llm-only-question-and-title/evidence/round-01-snapshot.json
- Evidence: 按T1至T4对照源码、Debug构建成功、TS严格类型检查及JS/Python语法通过；真实合成输入观察两类问题和十五元素标题，旧CLI关闭、预热实际600秒；未运行测试套件或真实UI验收。
- Task fingerprint: c269d7b0db63f5376e326e07593390279ab2ca26a731fe47f90e76709d95800e

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第一轮](../artifacts/local-llm-only-question-and-title/reviews/round-01.md) | sha256:3b5d8a950cb4ce1028a7dc76df3ad181cdda06390f4a750afd0723a4c605f8d1 | no blocking findings |

## Verification

- Passed: 终验重算round-01快照、全部源码/证据及baseline索引哈希，与独立评审范围一致；报告存在且run/snapshot对应。当前Debug构建和TS严格检查成功，合成调用分类true/false及十五元素标题、旧CLI拒绝、600秒预热证据齐全。未运行测试套件或真实UI验收，未替换用户运行态。
