# 深入调研 Gemma 4 E2B 及 iTermate 适用性

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-22 18:07) |
| Kind | Plan |

## Scope

深入核查 Gemma 4 E2B 的真实规模、量化内存、思考控制、官方能力及 Apple Silicon 公开实测，围绕 iTermate 中文短标题和 question/normal 分类评估。仅阅读公开资料及现有调用点；不安装引擎、不下载权重、不运行推理、基准或测试，不修改 App、用户模型配置或安装态。

## Target

- [ ] T1: 基于官方模型卡、技术资料和可核验实测，说明 Gemma 4 E2B 的能力、实际参数与内存、非思考模式、Apple Silicon性能和部署兼容性，并对照Qwen3.5-2B评估iTermate适用性，明确证据限制；仅调研，不安装、下载模型、运行基准或修改应用。

## Decisions

- Gemma 4 E2B 值得进入下一轮对照，不能仅因总参数约 5.1B 而排除；但目前没有充分证据证明其在本项目关闭思考的中文任务上优于 Qwen3.5-2B，不作生产替换决定。
- 模型与推理引擎是两个选择。后续优先保持 Ollama 不变验证模型收益，避免将换引擎与换模型混为一谈；现有 Splash 支持族不包括 Gemma 4，不能因存在 GGUF 就认为兼容。
- 首选候选是官方指令版本及可追溯量化，而非仅按社区混合量化吞吐选择。固定 revision、量化、模板、运行时和思考模式后才有可靠对照。

### 架构、能力和许可证

- E 代表 effective：约 2.3B 有效参数、模型卡标示含 embedding 约 5.1B。它是使用 Per-Layer Embeddings（PLE）的 dense Transformer，不是 MoE。视觉与音频编码器另有约 150M 和 300M 参数；不能把所有组件或不同导出格式都视为同一个参数口径。
- 原生 128K 上下文、35 层、512-token 滑动窗口、约 262K 词表；支持 system 角色、函数调用以及文本/图像/音频输入。具体运行时支持哪些模态需单独核验；本项目只需要文本。
- 支持多语言，但 MMMLU 是聚合多语评测，不代表中文标题或本项目分类准确率。未找到同条件的本项目中文质量对照。
- 原始官方仓库声明 Apache-2.0；不要沿用旧版 Gemma 的许可证印象。量化/分发仍需保留对应许可证与来源。

### 思考开关及现有接入边界

- 官方 chat_template.jinja 的 enable_thinking 默认 false；开启时在 system 起始位置使用专用触发标记，关闭则不加入触发标记。E2B/E4B 关闭后直接输出答案；不是所有 Gemma 4 大型号都采用同样的空思考块行为。
- Gemma 使用专用 channel 标记，而非 Qwen 的思考标签。运行时应正确处理模板、答案通道和结束原因，不能仅复用字符串剥离规则。
- Ollama 已提供 gemma4:e2b，并声明内部处理模板。现有 iTermate Swift 与 Pi 都发送 think:false，但仅允许 qwen3.5:2b/4b，另有配置身份、库存 digest 和迟到结果保护；仅手改 model 字符串不能构成受支持接入。
- Ollama 历史 issue #15260 最初涉及 26B 的 think:false/format，已关闭；#18774 涉及 E4B、think:true。它们不证明当前 E2B 无思考 JSON 必然失败，只说明后续应固定版本并验证控制与输出格式。当前应用以提示词约束并解析 JSON，不等于已经使用 schema 强制解码。

### 内存：估计、文件大小和运行峰值不可混用

| 来源与口径 | E2B 报告值 | 解读 |
| --- | --- | --- |
| Google 概览的 Q4_0 静态权重加载估计 | 约 2.9 GB | 参数估算并含加载余量，不是整个进程内存，不含完整运行时与上下文开销 |
| 官方 QAT Q4_0 GGUF 主文件 | 3,349,516,256 bytes，约 3.35 GB / 3.12 GiB | 实际文件大小，不是运行峰值 |
| 同仓库多模态 projector 文件 | 986,833,664 bytes，约 0.99 GB | 与主文件分开；文本模式是否不加载/下载，取决于运行时 |
| Google Mobile text-only | 约 0.84 GB | LiteRT-LM 专用移动端量化，不是桌面 Ollama/GGUF 的保证 |
| 社区基础 M4/oMLX 运行记录 | 页面摘要约 3.0 GB；资源栏 peak footprint 3.63 GB | 资源口径不同，不把摘要数字等同进程峰值 |

官方 QAT GGUF 核查 revision 为 675cff42a74c774d6cb76f76d8eacb49b48c9b93，主文件 SHA256 为 fa401b55b07ee70a54c6dae3903c783a6e65064312529ea57175cb5f8dec6634。以上来自远端元数据，未下载文件验证。Ollama 标签页还展示含 projector/drafter 的约 4.6 GB GGUF 组件组合及另一约 7.5 GB 变体，故标签名本身不保证恰好 3.35 GB 或固定量化。执行前必须核验实际 manifest、格式和版本。

技术报告的 text-only 表另报 0.8 的移动量化口径及有效参数相关内存，不能据此宣称桌面完整权重仅需该内存。M4/32 GiB 具有评估余量，但系统其他负载、上下文与并发仍影响实际峰值。

### 官方质量成绩：思考模式必须显式区分

| 模型及模式 | MMLU-Pro | IFEval | 说明 |
| --- | ---: | ---: | --- |
| Gemma 4 E2B，thinking | 60.0 | 94.6 | Google 技术报告 Table 5 明确默认开启思考 |
| Qwen3.5-2B，thinking | 66.5 | 78.6 | Qwen 官方卡 |
| Qwen3.5-2B，non-thinking | 55.3 | 61.2 | 当前应用所用模式的参考基线 |
| Gemma 4 E2B，non-thinking | 未取得可比官方值 | 未取得可比官方值 | 不把 thinking 成绩填入 |

这是不同发布方的报告值，不是统一 harness 的直接排名。Gemma 的 IFEval 显示指令服从潜力，不能据 94.6/61.2 推断实际提升比例。Gemma 同表 IFBench 38.0、MMMLU 67.4 也属于 thinking。IFEval 不是本项目二分类或标题质量，MMMLU 也不是中文专项证据。

### Apple Silicon 公开实测及限制

1. 基础 M4、10 核 GPU、16 GB，oMLX 0.5.7、macOS 26.3、gemma-4-e2b-it-4bit：1K 输入 prefill 2331 token/s、decode 49.3 token/s、TTFT 439 ms；4K 输入 decode 58.7 token/s。资源栏 peak footprint 3.63 GB、MLX active peak 2.82 GB。这是 Python 代码提示的社区单次上传，不是本机 32 GiB 实测；thinking_budget_enabled:false 仅说明预算限制未开启，不能据此确定思考模式关闭。
2. M4 Pro/64 GB 的实验性 text-only MLX mixed-3.62bpw：MLX 0.32.0、mlx-lm 0.31.3、thinking 开启、greedy、batch 1，2K 输入实出 182 tokens，decode 109.99 token/s、端到端 2.278 秒；MLX peak 2.779 GiB、RSS 3.069 GiB。不同芯片/格式/运行时不能与上项或此前 Qwen 数字直接算速度比。
3. 该混合量化相对同 harness BF16 的 MMLU-Pro 400 题从 59 降至 54；IFEval strict prompt 从 84.10 降至 83.36。说明体积/吞吐优化仍可能损失质量；其测试为 thinking，原始逐题记录未全部公开，不当作中文生产质量保证。
4. 另有 M5 Max/128 GB 的社区同机无思考 MLX 合成吞吐：原始结果表 4K 下 Gemma E2B 为 204.9 token/s、Qwen3.5-2B 为 310.5。仅重复文本输入、最多 32 输出 token，采样设置不同、缺少稳定重复测量与严格缓存隔离；README 还误称 E2B 为 MoE，故只作低置信线索，不外推本机速度或业务质量。
5. 结论是已有可运行、可接受资源级别的证据，而非已证明更快。标题/分类更应看有效结果完成延迟、中文语义与格式成功率，而不是单独看 decode token/s。

## Plan

1. 保留当前 Qwen3.5-2B，不改 App 或模型配置。将 Gemma 4 E2B 作为值得实测的候选；已有公开证据不足以作替换决定，也不需要用户先选未证实的优劣。
2. 如后续明确授权接入/评估，先固定 Ollama 版本、模型实际 digest/量化及模板，核对 think:false 与最终答案通道；不同时迁移推理引擎。官方 QAT GGUF 可作为独立可追溯候选，但不能假定等同 Ollama 默认 Q4_K_M 包。
3. 用固定、合成的中英文输入对照：中文短标题、目标切换、简短确认沿用、真正等待用户回应与单纯交付说明、严格二分类 JSON。记录标题质量、分类 macro-F1、误报/漏报、JSON 成功率、最终有效答案 P50/P95、冷/热启动、并发与进程峰值内存；两者均关闭思考，固定输入与上下文。
4. 只有质量不回退且有效结果延迟/资源获益后，才另行实施模型枚举、库存身份、Swift/Pi 双端配置与解析的最小接入。研究接受不构成下载、基准、安装或实施授权。

## Sources

- [Google Gemma 核心概览与静态/移动内存口径](https://ai.google.dev/gemma/docs/core)
- [Google 官方 E2B 模型卡](https://huggingface.co/google/gemma-4-E2B-it)
- [官方思考开关说明](https://ai.google.dev/gemma/docs/capabilities/thinking)
- [原始 chat template](https://huggingface.co/google/gemma-4-E2B-it/blob/main/chat_template.jinja)
- [Gemma 4 技术报告，架构及 Table 5 思考模式评测](https://arxiv.org/html/2607.02770)
- [官方 QAT Q4_0 GGUF 文件与许可证](https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/tree/675cff42a74c774d6cb76f76d8eacb49b48c9b93)
- [官方仓库文件元数据](https://huggingface.co/api/models/google/gemma-4-E2B-it-qat-q4_0-gguf?blobs=true)
- [Ollama E2B 标签与组件](https://ollama.com/library/gemma4:e2b)
- [Qwen3.5-2B 官方模式区分评测](https://huggingface.co/Qwen/Qwen3.5-2B)
- [基础 M4 oMLX 社区测量](https://omlx.ai/benchmarks/performance/ocagralm)
- [M4 Pro 实验性 MLX 混合量化，条件及质量回退](https://huggingface.co/maglun/Gemma-4-E2B-it-Text-MLX-Mixed-3.62bpw)
- [M5 Max 社区合成吞吐报告及脚本](https://github.com/Incept5/gemma4-benchmark)
- [Ollama 历史格式问题，已关闭](https://github.com/ollama/ollama/issues/15260)
- [Ollama E4B/think:true 格式问题，不是 E2B 复现](https://github.com/ollama/ollama/issues/18774)

资料核查日期：2026-10-22。未下载权重、未运行推理/基准或测试，未修改应用或用户配置。公开 main/tag 可漂移，执行前须重新固定身份；本记录为研究交接，不表示已有本机行为验证。
