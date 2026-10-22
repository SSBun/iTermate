# 测试 Qwen3.5-2B 回复状态分类

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-20 18:18) |
| Artifacts | [Artifacts](../artifacts/compare-qwen35-2b-reply-classification/) |
| Kind | Task |

## Target
- [x] T1: 使用本机运行环境安装并验证 Qwen3.5-2B 可用于回复状态分类。
- [x] T2: 沿用此前固定样本、标签定义与提示词测试2B，报告正确率、误报、漏报、截图原文结果及冷/热态延迟，并与已有Vela和0.8B结果比较。
- [x] T3: 本轮仅新增2B模型，不安装4B，不修改或替换iTermate现有分类器。

## Scope

- 复用已安装的 Ollama，仅下载 Qwen3.5-2B，执行独立的本地助手回复分类评估并保存证据。
- 不升级运行环境、不修改产品源码、Pi 安装副本或当前模型配置，不启动或重启 iTermate/Bridge；不运行项目单元测试或套件。

## Decisions

- 用户确认本轮仅新增 2B，不安装 4B，不切换生产分类器。
- 原样沿用上一轮 40 条样本、期望标签、最终分类提示词、生成设置、三轮次数与洗牌种子；正式评估期间不调提示词。
- 仅实测 2B，Vela 与 0.8B 引用上一任务的正式结果，不重跑已完成比较。报告明确不同时间测量的延迟不是同场配对实验。
- 关闭思考输出，不启用强制 JSON 解码，严格校验标签；格式错误、HTTP 失败或超时保留并计错，不删样本或静默重试。
- 分开记录热态分类与卸载后的首次加载耗时；800 毫秒按完整请求实测耗时模拟，不接入生产 UI。

## Plan

1. 检查前轮不可变语料、提示词和结果身份，记录当前产品与环境保护范围，下载单个 2B 模型。
2. 冻结本轮脚本并执行 120 次分类，单独测量加载延迟，保留所有原始输出与失败。
3. 重算统计、核查产品和基线未变，交付与既有模型的比较及局限。

## Task Summary

**本机模型资源**：["/Users/caishilin/.ollama/models"](file:///Users/caishilin/.ollama/models) 仅新增 qwen3.5:2b 模型，保留既有 0.8B，未升级 Ollama 或依赖、未安装 4B、未切换生产分类器。

**2B 评估产物**：[本任务产物](../artifacts/compare-qwen35-2b-reply-classification/) 新增复用既有固定协议的单模型采集脚本、推理前冻结清单、120 次正式分类与加载延迟原始记录、统计复核及比较报告；前任务证据只读引用，没有覆盖或重复执行。

## Result

- T1: 复用Ollama0.40.6，仅新增qwen3.5:2b，3117475695字节，digest dfaf2605162e689c8cac330dc4a190c4c50ad30aa47814a8fe9b79fa5127e97e；MLX/mxfp8，120次正式推理全部返回合法JSON标签。见evidence/results-20261020T101359Z.json。
- T2: 样本、最终提示词与参数和前轮完全一致，三轮均37/40，合计111/120=92.5%；误报3/60，漏报6/60，截图原文3次均normal；热态p50 282.6ms、p95 392.2ms、最大724.2ms，冷加载首次2688.1ms。独立重算120行与配对、矩阵及分位数一致，历史Vela/0.8B未重跑。报告reports/comparison.md明确合成集和非同场延迟局限，证据evidence/verification.json。
- T3: 当前/api/tags仅0.8B与2B，未安装4B。66个受保护产品/配置/基线/二进制哈希未变；前轮23项快照全部一致，原App与Bridge进程未重启；未运行项目测试，未切换分类器。见evidence/verification.json和protected-files.json。
- Review gate: Skipped — 当前R1四项具体依据成立，无显式或继承独立审查义务；复用前轮已审查协议，本轮120条计数/矩阵/分位数及不变边界已由主Agent独立重算和核验。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 本轮仅可删除的本机模型下载与固定协议的单模型采集/报告，不安装新运行时、不改变生产行为，观测与统计可直接复核。
- Snapshot: evidence/snapshot.json sha256:f8d9af73d49cbbb782b5d7c488150bfe9502a2227ef92d41e86f77d7b712a2cd
- Evidence: evidence/verification.json核对120条全部组合、输出结构、协议与前轮一致、独立重算矩阵和延迟、66个保护文件及前轮23项身份一致；报告限制为本样本本配置。
- Result clarity: 用户确认仅测试2B且沿用原样本提示词；安装、分类计数、误报漏报与延迟均有可直接判定的完成条件，无未定需求。
- Bounded impact: 仅新增本机2B权重与任务产物，生成设置和分类业务定义继承已独立审查的固定协议；脚本只请求本机Ollama，不调用Vela或0.8B，不改产品和运行时。
- Low risk: 下载与产物可删除，未触及生产配置、权限或外部数据发送；无Homebrew升级、无进程重启、无登录启动变更，失败只影响本次离线评估。
- Sufficient verification: 120条逐轮样本组合与JSON标签核查、原始统计独立重算、样本提示词协议哈希核对、保护范围内容身份和安装列表/进程检查均通过；不夸大生产泛化，无项目测试或并发/UI验收。
- Task fingerprint: 973a8b03258eeebcf00f000978775e4c7111fbfac26f29eef69ef9b512656e25

## Verification

- Passed: 终态前重核9项产物与66个外部保护文件哈希全部一致，2B digest固定且仅0.8B/2B安装，原App/Bridge进程未变；Context validate与任务diff空白检查通过。120条分类统计已独立重算，无额外推理重跑或项目测试；报告保留冷启动和历史基线非同场局限。
