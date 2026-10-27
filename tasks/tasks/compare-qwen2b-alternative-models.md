# 调研 Qwen3.5 2B 同级小模型及性能对比

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-22 17:37) |
| Kind | Plan |

## Scope

只读调研1–3B左右的本地指令模型，保留Qwen3.5-2B基线；对effective/非embedding参数名与实际权重规模不同的模型单独说明。核心场景为中文短标题及问题/正常二分类，优先non-thinking的有效完成延迟、指令/格式服从与资源占用。不下载模型、不执行基准或单元测试、不变更App、推理服务、模型配置或用户安装态。读取公开模型卡、模板、许可证与现有源码不等于已实测。

## Target

- [ ] T1: 基于 Hugging Face 模型卡及可核验公开评测，比较 Qwen3.5 2B 与同级本地小模型的能力、速度与资源证据，评估中文短标题和问题分类适用性，明确不可直接横比或缺少实测的部分；仅调研，不安装、下载模型、运行基准或改动应用。

## Decisions

- 本轮优先验证候选是 LFM2.5-1.2B-Instruct（轻量指令/结构化输出）、MiniCPM5-2B（中文/英文与较强能力候选，须关闭思考并核验模板），其次是Granite-4.0-1B（Apache许可的轻量分类候选）。这是评估顺序，不是已经证明优于现有模型的生产替换决定。
- Qwen3.5-2B仍作为中文基线。当前源码Swift和TS均发送think:false；Pi分类最多32输出tokens，Pi标题每轮64，Swift标题每轮1024。因此不能用thinking榜单代替现行工作模式，尤其不能把LFM2.5-2.6B的始终思考结果当作无思考直换。
- 公开数据缺少全部候选在本机M4/32GiB、相同运行时/量化/提示/上下文的严格对照。不输出虚构的M4统一tokens/s或峰值RAM排行榜。模型卡列出支持中文不等于中文短标题或二分类胜出；IFEval也不是本项目分类准确率。

### 同来源的Qwen非思考能力对照

来自Qwen3.5-2B模型卡同一张Non-Thinking表，均为百分制报告值，不是本机测试：

| 模型 | MMLU-Pro | C-Eval | IFEval |
| --- | ---: | ---: | ---: |
| Qwen3.5-2B | 55.3 | 65.2 | 61.2 |
| Qwen3-1.7B | 40.2 | 61.0 | 68.2 |
| Qwen3.5-0.8B | 29.7 | 46.4 | 52.1 |

Qwen3.5-2B思考模式另报66.5 MMLU-Pro、78.6 IFEval，不能混入上述表。1.7B在该报告的IFEval略高，不代表中文能力整体更强；0.8B是低资源对照，不据其较少参数假定语义质量足够。

### 同来源的Liquid非思考/指令对照

LFM2.5-1.2B-Instruct模型卡的统一对照，IFEval是strict/loose、prompt/instruction四种准确率平均：

| 模型 | MMLU-Pro | IFEval | IFBench |
| --- | ---: | ---: | ---: |
| LFM2.5-1.2B-Instruct | 44.35 | 86.23 | 47.33 |
| Qwen3-1.7B instruct | 42.91 | 73.68 | 21.33 |
| Granite 4.0-1B | 33.53 | 79.61 | 21.00 |
| Gemma 3 1B IT | 14.04 | 63.25 | 20.47 |

这些是Liquid发布方评测，不是独立报告；其Qwen3-1.7B为42.91/73.68，与上一Qwen表的40.2/68.2不同，不能把两表拼成统一榜单。Granite自身模型卡另报strict instruction80.82、strict prompt73.94、两者平均77.38，也不能与Liquid的四项均值直接排序。

### 其他候选的能力与规模边界

- LFM2.5-1.2B-Instruct实际1.17B、32K上下文，明确支持中文，conv+GQA混合架构；官方提供GGUF、MLX等格式。推荐数据提取/RAG/指令任务，不推荐知识密集或编程任务。它是non-thinking候选，而非同名Thinking版本。
- MiniCPM5-2B实际2,516,756,480总参数、约1.982B非embedding参数、128K上下文，Apache-2.0，支持中文/英文；原始chat_template.jinja实现enable_thinking:false分支。发布方报告IFEval86.7、MMLU-Pro70.8，但未在该表单列可核验的non-thinking口径，不据此宣称关闭思考后同样分数。其精选综合平均53.9也不当作跨项目通用质量指数。已有GGUF/MLX/LiteRT路径，仍需核验所选量化模板和输出解析。
- Granite-4.0-1B实际约1.6B、128K上下文，是dense Transformer；不要混淆Granite-4.0-H-1B的Mamba/attention版本。支持中文，但模型卡明确其指令训练以英文为主；Apache-2.0，适合作为轻量指令候选，不承诺中文比Qwen强。
- SmolLM3-3B为3B、128K、Apache-2.0，non-thinking模型卡IFEval76.7。中文是训练量较少的附加语言，而非其六种主要语言；体积更大，暂无证据表明在本项目比2B更划算。
- Gemma-4-E2B-it是2.3B effective、含embedding约5.1B，不是2B总权重；128K、Apache-2.0。支持多语与系统提示，思考可关。官方表MMLU-Pro60.0未给出这里所需的独立non-thinking IFEval，不能以60.0大于55.3就声称优于Qwen的现行模式。需更高资源预算，列为能力取向备选而非最轻量替换。
- LFM2.5-2.6B实际2.69B、128K，模型卡明确always thinks；发布方IFBench59.17、Multi-IF80.07、M5 Max220 tok/s等不能绕开最终答案思考延迟。更接近参数规模，但不优先用于当前32/64输出token预算。
- Ministral-3-3B-Instruct-2512另有3.4B语言模型加0.4B视觉编码器，Apache-2.0并支持中文/JSON/system角色；属于更大备选，未将其Reasoning版本成绩当Instruct版本成绩，当前不优先。
- 未把名称带Qwen3.8的社区蒸馏仓库自动视为Qwen官方2B升级，也不靠下载量推断能力。

### 可核验的速度与资源数据

1. Liquid同机手机对照：Galaxy S25 Ultra、CPU、llama.cpp Q4_0，1K输入/100输出：LFM2.5-1.2B为335 prefill tok/s、70 decode tok/s、719MB报告内存；Qwen3-1.7B为181/40、1306MB。该组支持其端侧效率潜力，不是Qwen3.5-2B或M4对照。
2. 社区同机MLX Qwen对照：M4 Pro 20GPU/64GB、MLX0.31.0+mlx-lm0.30.7、20次测量、int4、256输入/100输出：0.8B为284.1 tok/s、2B为144.3、4B为68.0；4096输入的TTFT分别1.09/2.54/6.14秒，报告峰值内存3.3/4.2/6.4GiB。不是本机基础M4，也不是Ollama；仅引用原始测量，不采纳该报告无严格依据的通用质量/选型断言。
3. Hugging Face社区LiteRT转换卡：LFM2.5-1.2B在M4 Max、LiteRT-LM0.16.0、int4 GPU、256输入/256输出测得318.3 tok/s、TTFT0.07秒；这是特定转换/运行时配置，不是Ollama或基础M4。其另一CPU设置int4虽然decode更快，prefill/TTFT反而比int8差，说明不能只看量化位数。
4. 社区MiniCPM5 LiteRT卡：M4 Max、LiteRT-LM0.17.0、256/256、GPU，int4为93.0 tok/s、TTFT0.15秒，int8为124.2、0.13秒；int4/int8转换方案不同，不能得出所有8bit普遍快于4bit。其thinking-off小样本GSM8K中bf16为92/100、GPU int4为87/100，不能将该5题差异推广为所有任务损失率。
5. 各转换包、GGUF文件、总参数或effective参数均不是运行时总RAM；还需计KV/state、tokenizer、workspace、模型/视觉组件及进程开销。没有测量就不填统一RAM估计。

### 接入与许可证结论

- 选择模型与选择推理引擎是两件事；这些小模型不因有GGUF就自动得到Splash支持，其现有family限制仍然存在。
- 现有iTermate仅允许Qwen3.5 2B/4B标签及已定义身份核验。即便Ollama/MLX底层能加载候选，也需要显式后续任务接入模型身份、模板/思考开关、完成原因和输出解析，不能只把共享配置JSON的model字符串换掉。
- Liquid模型采用LFM Open License v1.0，含年营收1000万美元门槛的商用限制，不能等同Apache-2.0；面向企业使用/分发前要核验完整条款。Qwen、MiniCPM5、Granite、SmolLM3与Gemma4所选原始仓库声明Apache-2.0；量化分发也需保留原许可证。
- LFM官方GGUF同时有普通PTQ Q4_0和QAD Q4_0；两者不可当同权重版本。QAD宣传的约97%为其自定义跨基准BF16相对表现保留，不是本项目分类准确率97%。

## Plan

1. 保留Qwen3.5-2B为现行基线。若后续授权对照，优先LFM2.5-1.2B-Instruct与MiniCPM5-2B（明确关闭思考），再按许可证/资源要求考虑Granite-4.0-1B；暂不做生产替换决定。
2. 对照前固定原始模型revision、量化版本（尤其PTQ/QAD）、推理引擎/版本、chat template、思考开关和上下文。不能把换模型与换引擎的收益混成一个数字。
3. 另行授权才下载/运行，用合成且固定的中英文标题与问题分类集合，同时统计分类macro-F1、question误报/漏报、JSON有效率、标题目标准确率/单行长度、P50/P95最终有效结果延迟、冷/热、并发、峰值内存和异常比例。思考token耗时必须算入结果延迟。
4. 只在实际业务质量不回退、延迟/资源确有收益后才规划接入；不因单项IFEval或MMLU高分直接替换，不新增无需求的双模型运行架构。

## Sources

- [Qwen3.5-2B官方模型卡：non-thinking与thinking表](https://huggingface.co/Qwen/Qwen3.5-2B)
- [Qwen3-1.7B官方卡与思考硬开关](https://huggingface.co/Qwen/Qwen3-1.7B)
- [LFM2.5-1.2B-Instruct官方卡：统一评测和手机速度表](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct)
- [LFM2.5-2.6B官方卡：实际参数和始终思考限制](https://huggingface.co/LiquidAI/LFM2.5-2.6B)
- [LFM许可证](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct/blob/main/LICENSE)
- [LFM官方GGUF：普通PTQ与QAD不同](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF)
- [Liquid QAD解释](https://huggingface.co/blog/LiquidAI/qad)
- [MiniCPM5-2B官方卡](https://huggingface.co/openbmb/MiniCPM5-2B)
- [MiniCPM5原始思考模板](https://huggingface.co/openbmb/MiniCPM5-2B/blob/main/chat_template.jinja)
- [Granite-4.0-1B官方卡：实际1.6B、IFEval子口径](https://huggingface.co/ibm-granite/granite-4.0-1b)
- [SmolLM3-3B官方卡](https://huggingface.co/HuggingFaceTB/SmolLM3-3B)
- [Gemma4 E2B官方卡](https://huggingface.co/google/gemma-4-E2B-it)
- [Ministral3 3B Instruct官方卡](https://huggingface.co/mistralai/Ministral-3-3B-Instruct-2512)
- [社区M4 Pro原始MLX报告](https://github.com/weklund/mlx-coding-bench/blob/main/measurements/llm_benchmarks/Apple_M4_Pro_10P%2B4E%2B20GPU_64GB/2026-03-06__19%3A47%3A24/REPORT.md)
- [社区LFM LiteRT卡与详细测量条件](https://huggingface.co/litert-community/LFM2.5-1.2B-Instruct)
- [社区MiniCPM5 LiteRT卡与详细测量条件](https://huggingface.co/litert-community/MiniCPM5-2B)

本轮仅阅读公开卡片、模板、许可证和本地现有调用点；未下载权重、未运行推理/基准/测试，未修改应用或用户模型配置。数据核查日期：2026-10-22。外部卡片随main变更，后续执行前重新固定revision与文件身份。
