# 调研 Laya 之外的开放 System 1 分类与决策模型

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 17:17) |
| Artifacts | [Artifacts](../artifacts/explore-open-system-one-models/) |
| Kind | Plan |

## Target
- [x] T1: 基于项目文档、论文和模型卡，确认Laya之外可用的开放System 1或相近低延迟分类/决策模型，区分同类模型与仅相近的技术路线。
- [x] T2: 对候选的开放代码/权重及许可证、输入输出范式、中英文支持和本地部署条件给出可追溯资料，并说明对普通回答与待回复问题识别的适用性和未实测限制。
- [x] T3: 在统一中英文待回复判定样本上实际评估前述六种方案并与Laya基线比较，提供逐例输出、漏报误报及本机延迟；不能运行的候选明确记录原因，不以资料或mock充当实测。

## Scope

用户新增要求实际测试前述方案，并已确认完整评估目标。允许为评估准备隔离依赖及下载公开模型，范围为六种候选的小规模版本与Laya基线；不替换产品集成、不重启用户App/Pi或现有Laya服务、不上传真实会话。不使用收费API。开放权重不等于宽松开源许可，运行框架也不等于新模型。

## Decisions

1. 确认存在直接同类：Vela 2.0、GLiNER2.5-Decide、Kev、mpuig/system-one、Liquid d1；GLiClass 是相邻的零样本分类路线，同样能实现此二分类，不必要求 System 1 品牌。
2. 当前固定配置实测中，system-one与Vela值得继续验证，但仅凭48条合成样本不替换产品模型；具体漏报/误报、语言分组和局限见实测报告，不能将一条样本差距当作稳定排名。
3. 应分类“是否需要用户下一步回应”，而不是是否有问号或终端是否正在运行。普通结果、隐含确认、修辞疑问、引用问题、否定回复、历史完成叙述必须区分。未知/低置信度是产品策略，不宜与二分类训练目标混为一谈。
4. 不采用厂商跨数据集榜单推断本项目表现；真实模型分类测试属于集成/评估测试，纯 mock 单元测试只能验证解析和状态流转。

## Sources

| 候选 | 已核查事实与限制 | 原始资料 |
| --- | --- | --- |
| Vela-2.0-0.3B | 约0.3B ModernBERT；choice/noul/score/span/set；8192总输入token；语言包含中英；Torch/ONNX本地推理。权重代码Apache-2.0，但tokenizer另受Gemma条款约束；未核查Core ML移植。 | https://huggingface.co/vllm-sr/Vela-2.0-0.3B |
| GLiNER2.5-multi-Decide | 287M；动态标签、单次前向，不生成token；权重Apache-2.0，开源gliner2运行库。模型卡声明多语言，未提供中文专项结果；底座卡支持CPU/CUDA/MPS。英文340M版本不能与多语言版混用。 | https://huggingface.co/fastino/GLiNER2.5-multi-Decide ，https://github.com/fastino-ai/GLiNER2 ，https://huggingface.co/fastino/gliner2.5-multi-v1 |
| Kev-0.8B | Qwen3.5底座+公开LoRA/决策头，Apache-2.0；choice/noul/score；仓库明确支持Apple Silicon MLX。模型卡language=en，不能由Qwen底座推断中文准确率。另有4B/9B/27B档位。 | https://github.com/jaredpalmer/kev ，https://huggingface.co/jaredpalmer/kev-0.8b |
| mpuig/system-one | 原生MLX研究原型，公开Qwen3-0.6B适配器及MiniCPM5-2B质量档；choice/noul/score；代码MIT，底座许可另计。作者明确不宣称生产就绪；官方中文专项评测未核实，本轮中文样本表现另见实测报告。 | https://github.com/mpuig/system-one |
| GLiClass multilingual mini | 相邻零样本/少样本分类路线；动态标签、描述与示例；权重Apache-2.0，代码公开；模型卡明确列中英，示例使用Transformers/PyTorch。未验证本机加速后端及性能。 | https://huggingface.co/knowledgator/gliclass-multilang-mini ，https://github.com/Knowledgator/GLiClass |
| Liquid d1-3B | 约3.1B，文本/图像单次前向的类型化决策；卡列中英；公开权重、llama.cpp支持，厂商报告Apple M5 Pro运行数据。LFM Open License v1.0含商业营收门槛，不应称为Apache/MIT式无条件开源。 | https://huggingface.co/LiquidAI/d1-3b ，https://huggingface.co/LiquidAI/d1-3b/blob/main/LICENSE ，https://www.liquid.ai/blog/d1-open |
| kaivoss/system-one-270m | 270M单次前向选择候选字母；公开权重，Gemma许可；作者明确主要英语，不优先用于中文。 | https://huggingface.co/kaivoss/system-one-270m |

## Plan

1. 已获评估授权，冻结48条合成样本（16条历史回归、32条新样本）、统一任务定义及固定判定方式，不根据评估结果调提示词或阈值。新样本不是独立人工盲标集。
2. 使用临时隔离环境，固定候选模型版本，顺序进行真实本地推理；Laya现有服务采用通用二分类接口，并另外记录原四状态接口基线。
3. 六种候选分别记录逐例输出、重复轮次稳定性、问句召回、普通回复误报、混淆矩阵、推理时间和加载时间；环境失败与模型误判分开。
4. 汇总适用性与未验证限制；不将同机不同运行框架的延迟称为纯模型速度，不将下载时长混入推理耗时，不据小样本宣称生产准确率。

## 实测交付

- [对照报告](../artifacts/explore-open-system-one-models/reports/comparison.md)
- [冻结样本](../artifacts/explore-open-system-one-models/evidence/suite.json)、[逐次汇总](../artifacts/explore-open-system-one-models/evidence/summary.json)、[自检](../artifacts/explore-open-system-one-models/evidence/self-check.json)
- 六种候选及Laya三种配置均完成每配置48条、两轮真实推理；Kev/GLiNER初始基础设施失败及恢复证据保留，未用失败尝试冒充模型错误。
- 仅新增评估脚本、样本、报告及任务记录；未修改产品源码、用户安装集成或现有服务。

## Result

- T1: Sources核查公开模型卡与仓库，确认六种同类/相邻路线及额外研究候选；comparison.md列出本轮实际选定版本与结果。
- T3: evidence/self-check.json核对9个最终配置各96行真实输出、零请求错误及冻结样本一致性；六候选正确数29/24/39/38/40/34（各48），Laya直接choice28/48，noul23/48；summary.json列逐例、漏报误报、语言分组、P50/P95，两轮无预测变化。指标自检、py_compile与git diff --check通过；报告明确合成小样本和非独占延迟局限。
- T2: Sources记录权重/代码许可、中英声明与部署方式；models.json固定Hub revision，environment.json固定机器与源码。来源许可说明与comparison.md实测结果分开，不由底座多语言推断任务准确率。
- Review gate: Passed — 独立fresh Reviewer run 1b84ba61-1e56-4379-9ab3-506e0c0cbb66，reviews/round-01.md无阻断问题；独立核算指标、原始输出到预测及59文件前后SHA256，主会话再次匹配snapshot-01。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 多种真实模型API适配、标签语义和指标聚合构成非机械评估结果，需要独立检查是否有输入泄漏、计数错误或超出证据的结论。
- Snapshot: tasks/artifacts/explore-open-system-one-models/evidence/snapshot-01.json sha256:a5f97939227e8fdfc15dc67a074acd94513a8cafbd9ddfabec9a3e8f66a71aec
- Evidence: evidence/self-check.json、summary-check.log、reports/comparison.md；9个最终配置各96行输出及两轮稳定性核验完成，所有候选均实际推理，基础设施失败另留记录。
- Task fingerprint: 8ea311d96202321980ece7f2a1d5f74c4b1b3c09cd73e0523cabf9bdf6370e26

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [独立审查](../artifacts/explore-open-system-one-models/reviews/round-01.md) | snapshot-01.json sha256:a5f97939227e8fdfc15dc67a074acd94513a8cafbd9ddfabec9a3e8f66a71aec | no blocking findings；fresh oracle载体Reviewer，run 1b84ba61-1e56-4379-9ab3-506e0c0cbb66；审查及主会话均复核59文件哈希。 |

## Verification

- Passed: 最终复核snapshot-01的59文件长度与SHA256全部一致；审查报告已持久化并链接。六候选与Laya三配置各96条真实输出、逐例预测及指标已由独立Reviewer重算一致；合成样本、后端时延和无UI验收限制保留，未改产品集成。
