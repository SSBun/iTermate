# 调研 Splash 与 Ollama 的差异及 iTermate 适用性

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-22 17:07) |
| Kind | Plan |

## Scope

只读调研 Splash 与 Ollama 的定位、实际模型支持、性能证据、资源与平台约束、维护状态及 iTermate 适配影响。不安装服务、不下载模型、不执行基准或测试、不修改应用/集成代码、不迁移用户配置。抓取公开 GitHub 仓库仅用于临时源码阅读。

## Target

- [ ] T1: 基于可追溯来源说明 Splash 与 Ollama 的核心差异，区分性能宣传、可核验数据与推断，并评估是否更适合 iTermate 的本地 LLM 需求；仅调研，不实施替换。

## Decisions

- 当前不建议把 iTermate 默认后端从 Ollama 替换为 Splash；Splash 在其支持的大模型、长上下文、共享前缀和并发 Agent 场景具有真实的性能潜力，但没有现有 Qwen3.5 2B/4B、短中文标题与二分类工作负载上的直接证据。
- 调研基准日期为2026-10-22。临时读取的 Splash main 为 `1482f6bbc2abf12375332725302019594150b6cb`；GitHub API列出的最新稳定发布是1.4.0（2026-10-20）。这些是本轮核查值，不作为永久平台配置事实。
- Splash 以 DFlash2 draft、按模型形状定制 Metal 内核、共享前缀/分页KV、连续批处理和自动内存计划优化少量模型；1.3起支持部分dense模型的GPU/ANE prefill拆分，ANE使用私有接口且可禁用回到GPU。不能将其描述成仅包装Ollama/MLX的通用服务。
- README和 `install/families.py` 只列 Qwen3.8-27B、Qwen3.6-35B-A3B、Qwen3.8-Flash-Next 三个family及其draft；同family兼容微调/多种GGUF或MLX量化可加载，Ternary Bonsai等兼容变体不是任意模型支持。ModelDescriptor按hidden size、层数、词表、注意力维度等精确核验，当前iTermate的Qwen3.5 2B/4B不属于现有family，不能原样换引擎。
- 官方发布基准：M5 Pro 48GB、选定SPEED-Bench编码提示、最长32K、最多1024输出tokens、开启推理；27B短提示74 tok/s、35B-A3B 210 tok/s。README中的2倍/接近4倍主要指所测下一快引擎，不专指Ollama。同GGUF对比另测llama.cpp，不能直接当作所有Ollama版本的结果。
- 社区issue37提供部分交叉证据，需读后续而非只引用初帖：M3 Max128GB的1.0.1曾在dense27B落后Ollama MLX；1.0.2/1.3.0后已明显改善，1.3.0的27B约58.2 tok/s、35B约134.3 tok/s，初帖Ollama MLX基线分别42.5/84.7。不同量化、未固定Ollama准确版本、非最新1.4.0严格A/B，没有中文标题质量对照，不据此声称本机或现有小模型更快。
- 本机只读硬件核查为Apple M4、32GiB、macOS26.5.1；满足Splash M3+/macOS26.4+，但低于官方常见4bit示例的36GB最低说明（48GB推荐）。24GB已有低比特大模型案例，因此不是完全不能跑；在本机运行需另选低比特/语言模式/资源上限，并接受模型和量化改变及其他App内存竞争。未实测本机速度。
- iTermate主要是后台短标题与问题/正常二分类；更应比较热/冷端到端P50/P95、有效JSON/标题率、中文语义准确度、取消/并发失败率、常驻RAM与系统压力，而非仅持续输出tok/s。推测解码的长输出收益不能直接推广到此负载。Splash的JSON Schema有grammar约束并验证最终结果，适合后续分类评估，但Ollama也有结构化输出支持，并非独有优势。
- Splash提供OpenAI Chat/Responses/Completions和Anthropic Messages；默认127.0.0.1:8000。现有Swift与TS均直连Ollama原生11434的/api/tags、/api/chat，并有/api/generate预热及digest身份校验。接入需改两端协议、模型发现/身份校验、输出解析、参数和预热，不能只换base URL；think:false需对齐reasoning_effort:none，输出上限用对应OpenAI字段，上下文/空闲驻留多属server设置。模型改变也必须重新评价分类/标题质量。
- Splash项目代码Apache-2.0，部分llama.cpp材料MIT、模型权重独立授权。项目公开约一个月、更新活跃且已到1.4.0；既有问题不能一律当现版本缺陷。例如M3 Ultra旧1.0.2故障issue96已关闭，不作为当前不可用结论。ANE私有接口、升级/休眠恢复、内存/SSD缓存和请求等待仍是接入前的运行风险验证项。
- 当前没有需要用户决定才可给出的结论。未来是否投入大模型实验属于独立授权，不自动下载、安装、改变Pi/Codex模型或启用Splash。

## Plan

1. 当前决策交付：保留Ollama作为轻量后台模型后端，将Splash列为特定大模型/本地Agent工作负载的备选，而非立即迁移。
2. 若未来明确授权评估：先确认可接受模型与量化变化、M4/32GiB可用内存及磁盘预算，再选择Splash支持的模型；没有2B/4B支持时不把性能差异归因成纯引擎差异。
3. 另行授权后才执行同机、固定版本/权重/量化/模板/推理开关的对照；若无法同模型，分开报告引擎效应与模型质量变化。覆盖中文标题/分类质量、冷/热P50/P95、两至四并发、取消、恢复和常驻资源，不只测长输出吞吐。
4. 只有性能、质量及资源收益均得到证据支持，才另行规划Swift与TS的后端接入；保留固定本机地址、模型身份和在途取消，不自动改Pi/Codex主模型。

## Sources

- [Splash README及平台/模型要求](https://github.com/incoai/splash/blob/1482f6bbc2abf12375332725302019594150b6cb/README.md)
- [官方发布文章及完整基准条件](https://inco.ai/blog/splash/)
- [性能方法与同GGUF对比](https://github.com/incoai/splash/blob/1482f6bbc2abf12375332725302019594150b6cb/docs/performance.md)
- [实际支持family与draft](https://github.com/incoai/splash/blob/1482f6bbc2abf12375332725302019594150b6cb/install/families.py)
- [精确模型形状校验](https://github.com/incoai/splash/blob/1482f6bbc2abf12375332725302019594150b6cb/runtime/model/ModelDescriptor.mm#L240-L285)
- [API、结构化输出、模型存储和私有ANE细节](https://github.com/incoai/splash/blob/1482f6bbc2abf12375332725302019594150b6cb/DEVELOPMENT.md)
- [社区M3基准及后续1.0.2/1.3.0复测](https://github.com/incoai/splash/issues/37)
- [1.3.0社区具体复测](https://github.com/incoai/splash/issues/37#issuecomment-6058664720)
- [1.4.0发布](https://github.com/incoai/splash/releases/tag/1.4.0)
- [旧M3 Ultra故障issue96已关闭](https://github.com/incoai/splash/issues/96)
- [Ollama macOS要求](https://docs.ollama.com/macos)
- [Ollama并发与驻留](https://docs.ollama.com/faq)
- [Ollama OpenAI兼容API](https://docs.ollama.com/api/openai-compatibility)
- [Ollama结构化输出](https://docs.ollama.com/capabilities/structured-outputs)
- iTermate当前接入权威：`iTermate/LocalModelService.swift` 的LocalLLMModel、generateSessionTitle/request，以及 `integrations/pi/iTermate-integration.ts` 的completeLocalLLM/localLLMRequest；本轮仅阅读，未改动。
