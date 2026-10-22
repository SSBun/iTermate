# iTermate 产品介绍与能力宣讲文档

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-15 18:14) |
| Kind | Task |

## Scope

仅新增中文产品宣讲文档，不修改产品代码、现有宣传稿或用户安装态，不对外发布。以当前工作区实现为准，不将源码能力等同于发布版本或运行时验收。

## Plan

1. 对照项目说明与实现梳理完整用户能力及终端、Agent 差异。
2. 编写突出并发管理和状态监控的宣讲正文与分类能力清单。
3. 核对事实、边界、文档格式和变更范围，完成交付。

## Task Summary

**产品文档**：[文档目录](../../docs/) 新增中文产品介绍与宣讲稿，涵盖并发会话组织、状态监控、注意力管理、Pi 上下文延续及完整分类能力清单，并说明后端差异、模型调用与归档隐私边界。根据用户反馈重写开头，以任务状态面板的直白定义、三项核心用途和并发场景说明实际帮助。

## Target
- [x] T3: 开头用通俗语言直接介绍产品是什么、主要能做什么，以及为用户减少哪些操作负担。
- [x] T1: 交付一篇中文 iTermate 介绍宣讲文档，突出多任务并发管理与状态监控的价值。
- [x] T2: 按类别完整列出经项目资料和实现核实的现有能力，以专业且有感染力的语言呈现，不虚构功能或性能承诺。

## Result

- T1: 已新增 docs/product-introduction.zh-CN.md；正文围绕并发组织、状态监控、注意力调度和Pi上下文延续展开，含使用场景、结语与六类能力清单。
- T2: 逐项对照中文README、快捷键及Pi文档、SettingsViews、iTermateApp、ItermBridge、SessionNotifications、LocalModelService、VenomDebugMonitor、Pi集成与Python Bridge；明确Ghostty TTY、iTerm2专属导航、Pi专属能力、摘要额度与服务方、归档未加密及未公证边界。格式与关键边界静态检查通过；未做运行时验收或测试。
- T3: 开头已改为终端旁任务状态面板的定义，列出集中管理、查看状态、直接处理三项用途，并用两个Agent加构建的场景说明减少查状态和切换；Pi专属能力及接入条件保留，正文清单未变。
- Review gate: Skipped — R1本地文案改写，已直接核对，无独立审阅要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅按反馈改写文档开头，原有事实与功能边界不变。
- Snapshot: docs/product-introduction.zh-CN.md sha256:238c40ca76d4b92575a04770c9ed0abcc51575d49b010ddd89b3068e8092b160
- Evidence: 人工逐句核对产品定义、三项用途、示例和能力前提；git diff --check通过。
- Result clarity: 直接回答是什么、做什么、有什么帮助。
- Bounded impact: 仅介绍文档开头，正文及代码未改动。
- Low risk: 本地文案可逆变更，无发布或执行副作用。
- Sufficient verification: 开头与已核实能力逐句对照；保留Pi限定和终端集成前提。
- Task fingerprint: ca991f5638339b256e9c68dbc79b7d3be5f35e014830190d4a38f1438e9b83cb

## Verification

- Passed: 最终文件哈希已核对，开头直白描述面板、能力与用户收益，未改变正文能力边界；diff空白检查通过，未运行测试。
