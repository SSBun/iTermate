# 生成并运行本地2B模型标题生成测试

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 10:31) |
| Artifacts | [Artifacts](../artifacts/test-qwen2b-title-generation/) |
| Kind | Task |

## Scope

- 仅测试本地 Qwen3.5-2B；使用固定合成会话，不读取真实会话或远程凭据，不调用云端模型，不更改生产标题逻辑或模型偏好。
- 仅运行本次标题生成测试，不运行项目其他测试；不启动、重启或安装 App/Bridge。

## Plan

1. 复用生产标题提示词、可见文本摘录和现有 Ollama 测试适配器，添加可单独启用的本地实测入口。
2. 执行中文目标、目标切换和英文输入案例，记录输入、真实标题、耗时及格式与目标匹配检查。
3. 复核结果和任务相关差异，在聊天中展示结果与局限。

## Task Summary

**Pi 标题测试**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 的既有标题对比测试中新增独立启用的本地 2B 实测入口，复用生产摘录与标题提示词，核对原始及归一化标题、当前目标关键词、长度偏好并输出合成输入和耗时；未改动生产逻辑。

## Decisions

- 用户已确认本轮完整 Target，明确要求生成并运行标题测试；仅运行这一份标题测试文件，不执行项目全套测试。
- 三个案例均为既有固定合成数据，覆盖中文分页目标、从点赞格式转向登录白屏、英文 macOS 侧边栏目标；不会读取用户真实会话、凭据或调用远程模型。
- 实测 3/3 生成有效标题，原始与归一化输出一致，均不超过24字符；当前目标语义已人工复核。平均端到端耗时542.49ms，未控制冷启动/缓存，不是性能基准或整体准确率证据。
- 现有 Lessons 为旧格式，由原文核查；本任务不启动/安装 App、Bridge 或替换用户运行态，不改写 Lessons。
- 实测日志与离线回归日志在 [证据目录](../artifacts/test-qwen2b-title-generation/evidence/)；结构化复核为 verified-results.json，内容身份清单为 manifest.json。

## Target
- [x] T1: 为当前本地Qwen3.5-2B模型准备并运行标题生成测试。
- [x] T2: 展示测试输入、模型实际生成标题及运行结果。

## Result

- T1: 本地实测仅匹配live local 2B title generation，退出码0：1项测试通过、三个合成案例3/3；同文件离线回归8通过0失败2跳过。日志与内容身份见tasks/artifacts/test-qwen2b-title-generation/evidence/manifest.json。
- T2: local-title-test.tap与verified-results.json记录完整合成输入、实际原始标题与耗时；三个标题分别20/9/22字符，耗时679.80/398.33/549.33ms，格式与当前目标核对通过；聊天交付展示同一结果，样本小且未控制冷启动。
- Review gate: Skipped — 当前R1四项豁免理由与实测证据齐全；仅新增隔离本地标题测试，未要求独立评审，内容身份已重新核验。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅增加显式启用的本地标题测试，复用现有生产提示词与适配器，实际输出与回归结果可直接验证。
- Snapshot: sha256:3187a93e42cd574653fdec64d7e35806db11ce6bec6603290a7ea4dcb482169a; tasks/artifacts/test-qwen2b-title-generation/evidence/manifest.json
- Evidence: 本地实测3/3案例、离线8通过0失败、原始与归一化标题一致、git diff --check通过。
- Result clarity: 用户确认本地2B标题实测与结果展示；三个完整输入和实际输出已记录。
- Bounded impact: 新增独立环境变量门的测试入口，现有函数与生产逻辑未改；离线入口默认跳过本地实测。
- Low risk: 仅对固定回环Ollama发送合成文本，断言本地URL且无鉴权头，不读真实会话或远程凭据，失败仅使测试失败。
- Sufficient verification: 实测1项测试含3案例通过；既有标题离线8通过0失败；检查原始/归一化格式、80字符上限、24字符偏好与目标关键词并人工核对语义。
- Task fingerprint: 8db149381a6fa7bce95fb2b057025b5f720e02b83b64877997faf8d76991990f

## Verification

- Passed: 完成前再次校验manifest及全部源文件/日志SHA256与assessment一致；实测三个案例有效且<=24字符、平均542.49ms，离线8通过0失败，git diff --check通过；仅运行本份标题测试，未运行项目全套测试。
