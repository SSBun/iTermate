# 安装并比较 Qwen3.5-0.8B 回复状态分类

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-20 17:51) |
| Artifacts | [Artifacts](../artifacts/compare-qwen35-08b-reply-classification/) |
| Kind | Task |

## Target
- [x] T1: 本机安装 Qwen3.5-0.8B 及必要运行环境，并验证模型可用于本地回复状态分类。
- [x] T2: 将 Qwen3.5-0.8B 与现有 Vela 在截图原文及同一组代表性回复上进行比较，报告分类正确性、误报、漏报与推理延迟。
- [x] T3: 本轮先评估 0.8B，不安装 2B 或 4B，不替换 iTermate 当前生产分类器。

## Scope

- 本机安装 Ollama 与单个 Qwen3.5-0.8B 模型，进行独立本地推理比较并保存可复跑的样本、脚本与结果。
- 不改动 iTermate 产品代码、用户安装的 Pi 集成或当前模型配置，不启动或重启 iTermate/Bridge，不运行项目单元测试或测试套件。

## Decisions

- 用户已确认先评估 0.8B，不在本轮下载其他模型。
- 分类对象是最新助手回复是否请求或等待用户参与；比较标签为 question/normal，而非语法上是否出现疑问句。
- 采用 Ollama 本机回环服务、关闭云功能和思考输出；保留现有 Vela 本机服务作为基线，不替换运行态。
- 样本与期望标签在首轮比较前冻结，两种模型处理相同原文；分别报告有效分类、错误/拒绝、首次调用和热态延迟，以及现有 800 毫秒截止下的结果。比较仅代表这组样本，不视为生产准确率。
- Homebrew 安装 Ollama 0.40.6 时自动安装 Python 3.15、MLX、mlx-c，并升级 readline、sqlite 与 ca-certificates；安装日志显示 python3 等无版本链接被重链接，旧链接由 Homebrew 备份。该环境副作用须在交付中披露。

## Plan

1. 安装必要环境与 0.8B 模型，确认本机 GPU 推理、模型身份和离线分类可用。
2. 冻结含截图原文的代表性中英文助手回复样本与标签；采用相同业务语义进行双模型比较，保留原始结果与延迟。
3. 独立重算混淆矩阵与延迟，检查产品文件和设置未变，记录结论、局限与可复跑证据。

## Task Summary

**本机 Ollama 与模型环境**：安装 ["/opt/homebrew/Cellar/ollama/0.40.6"](file:///opt/homebrew/Cellar/ollama/0.40.6) 和单个 ["/Users/caishilin/.ollama/models"](file:///Users/caishilin/.ollama/models) 模型，提供仅回环、禁用云功能的手动启动服务；Homebrew 自动安装或升级的依赖及 Python 默认链接变化已在报告中披露，未设置登录启动。

**模型评估证据**：[本任务产物](../artifacts/compare-qwen35-08b-reply-classification/) 新增冻结的 40 条双语回复、可复跑标准库脚本、正式三轮原始结果、兼容性预检历史、加载延迟和比较报告；没有修改 iTermate 产品组件或现有分类器配置。

## Result

- T1: Ollama 0.40.6 本机回环服务可用，仅安装 qwen3.5:0.8b，digest d9c89605f39a…；MLX/mxfp8 实测 120/120 合法分类输出，禁用云功能与思考输出。见任务 evidence/installation-observations.json、正式 results-20261020T094324Z.json 和 verification.json。
- T2: 固定 40 条双语助手回复三轮，每模型120次：Vela 99/120、Qwen68/120；误报18/60与52/60，漏报3/60与0/60；热态p50为71.9/109.3ms，Qwen卸载后首次1015.2ms。截图原文均3次误判。完整行数、配对、样本与脚本哈希、混淆矩阵和延迟经独立重算一致；见 reports/comparison.md 及 evidence/verification.json。仅限本配置和小型合成集，不宣称总体准确率。
- T3: 读取 Ollama /api/tags 仅有0.8B；61个产品文件、Pi安装副本和模型配置哈希与前置快照一致；iTermate PID94088与Bridge PID86437仍为原进程。未运行项目套件，未替换生产分类器。见 evidence/protected-files.json 与 verification.json。
- Review gate: Passed — 独立只读fresh Reviewer运行59e99bcc-d834-47f4-898a-3a9ac6a57050完成，报告reviews/round-01.md：无确认问题或阻塞风险。主Agent已复核当前snapshot.json SHA-256仍为876b72719eed7765385ee3f75638977a7d2be5ab097b1130e0d0e1901d47dce5，其23项与61个受保护文件全部一致；外部模型digest及Ollama二进制未变。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 本机安装含全局依赖链接副作用，且双模型基准含输出适配、冷/热态及重复样本解释边界，需独立只读核查实际产物与结论。
- Snapshot: evidence/snapshot.json sha256:876b72719eed7765385ee3f75638977a7d2be5ab097b1130e0d0e1901d47dce5
- Evidence: evidence/verification.json 已复核240行、无重复缺失、统计和哈希一致、受保护文件无变化；reports/comparison.md 披露小样本、协议预检调整、无并发验收和安装副作用。
- Task fingerprint: 464c5f72b51f7b6a52ee8e10ebcc91b54ce85c4700a65a39f5289176c460b8b0

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/compare-qwen35-08b-reply-classification/reviews/round-01.md) | evidence/snapshot.json sha256:876b72719eed7765385ee3f75638977a7d2be5ab097b1130e0d0e1901d47dce5 | no blocking findings；独立只读子代理运行 59e99bcc-d834-47f4-898a-3a9ac6a57050 |

## Verification

- Passed: 终态前只读复核23项审查产物及61个受保护文件哈希无漂移；仅安装qwen3.5:0.8b且digest一致，Ollama可用，原App/Bridge进程未变；审查报告与索引可恢复；Context validate及任务diff空白检查通过。不重跑模型评估或项目测试，原240次分类与局限见正式报告。
