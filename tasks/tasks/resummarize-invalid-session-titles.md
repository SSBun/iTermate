# 通过本地模型重新摘要不合格的实时会话标题

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-22 16:44) |
| Artifacts | [Artifacts](../artifacts/resummarize-invalid-session-titles/) |
| Kind | Task |

## Scope

实时 Pi 与原生 Codex 的标题生成、校验及相关文档；不修改布局、归档多句摘要、其他任务的标题持久化与 Commands 分组，不运行测试或重启应用。

## Target
- [x] T1: 实时会话生成标题须符合短标题要求且不含换行，不直接展示不合格生成结果。
- [x] T2: 首次生成标题不合格时，由本地 LLM 再次摘要生成，而不是在界面层隐藏换行或直接截断原文。
- [x] T3: 重新摘要仍失败时保留上一有效标题或原有终端标题，不无限重试；保留现有会话身份、取消及过期结果保护。

## Decisions

- 沿用 Codex 现有 80 字符提炼阈值作为两条链路的硬上限，统一按 Unicode 标量计数；不允许 CR/LF、NEL、Unicode 行/段分隔符等换行。空白标题也无效。其他空格、数字、标点仍不做额外强过滤或机械改写。
- 每次生成最多两轮模型调用；第一轮无效时用原对话和草稿请求本地模型再次提炼，第二轮仍无效则失败，不发布草稿。保留已有外层自动重试预算，不增加无限循环。
- 当前工作区另有标题持久化和 Commands 分组改动；以 evidence/before 的完整脏工作区副本为本任务基线，只修改目标方法和相关引用。

## Plan

1. 为 Pi 与 Codex 的生成结果加入一致的短单行校验，并补上有界再摘要。
2. 保持模型身份、取消、超时与会话身份保护，补充回归用例但不执行测试；同步当前文档和 Context。
3. 执行 Debug 构建、TypeScript 类型检查、Swift 解析及差异检查，自检后进行独立只读审查。

## Task Summary

**本地标题与发现**：[iTermate](../../iTermate/) 增加非空、无换行且最多80个Unicode标量的共享校验；Codex首轮无效或截断时再摘要一次，第二轮仍无效则抛错；Pi发现和Codex缓存恢复复用校验，不改归档摘要、缓存机制或会话身份保护。

**Pi 集成**：[integrations/pi](../../integrations/pi/) 为无效草稿增加一次有界本地再摘要，首轮token截断仅作草稿；两轮绑定同一配置与库存digest，共用取消与总截止。更新短单行、两轮失败、取消和截断草稿的回归用例，但未执行测试。

**Swift 回归用例**：[iTermateTests](../../iTermateTests/) 补充标题校验的80/81边界、Unicode换行和代理对案例，并调整Pi发现的有效标题与回退预期；未执行测试。

**说明文档**：[docs](../../docs/) 同步Pi与Codex的校验、最多一次再摘要、失败回退和比较调用预算说明，保留同期其他任务的自动补全与持久化内容。

## Result

- T2: 检查 Swift generateSessionTitle 与 TS summarizeTask：首轮无效或length仅作草稿，使用原对话与草稿再调用一次本地模型，第二轮必须正常结束并通过同一校验；没有UI换行清洗或substring截断。TS完整生产请求在两轮间绑定配置和库存digest；Swift延用原有selection/digest绑定。仅进行静态路径核对和编译，未运行模型或行为测试。
- T3: 静态核对无第三轮调用或新增循环；失败沿原有catch路径保留旧标题，Pi任务摘要只在成功后赋值。总截止、取消、HTTP/模型身份、会话/leaf/请求过期保护保留，分类请求仍严格要求stop，归档多句摘要未改。未执行启动/重启/安装命令，也未运行单元测试或测试套件；共享工作区用户运行进程由外部变化，未将PID不变作为证据。
- T1: 用户确认其他任务结束后恢复；标题生成核心方法与第2轮已审查内容一致。第03轮直接在当前工作区Debug构建、TS类型检查、Swift解析与mjs语法检查通过；round-03/build-source.json、build.log、content-check.json证明82个文件在构建前后无漂移。先前两轮只作历史证据，不代替本轮当前版本核验。非空、80 Unicode标量、无换行与Pi发现/Codex缓存校验保留；新增回归用例未执行，无真实模型请求。
- Review gate: Passed — fresh只读Reviewer run 721844c5-38b6-4b51-ac60-cfb81d8590a9 第03轮无finding或阻塞证据缺口，TR-1明确resolved；报告已保存并索引。主会话接收后重算82个文件及证据字节，均匹配当前快照，无漂移。
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/resummarize-invalid-session-titles/reviews/round-01.md) | sha256:fd16407911787cedf13ea7f2bf30e526e4f3ddebf74cd318049d550a1d435536 | findings: TR-1（阻塞证据缺口）；随后当前源码又漂移，旧构建不作为最终证明 |
| 02 | [第 02 轮](../artifacts/resummarize-invalid-session-titles/reviews/round-02.md) | sha256:c1af572a7ffb62eda5928cb0ccdae953486968b3efa89615d1386af48093c955 | no blocking findings on frozen snapshot；TR-1 resolved for frozen copy；当前工作区再次漂移，不能据此完成 |
| 03 | [第 03 轮](../artifacts/resummarize-invalid-session-titles/reviews/round-03.md) | sha256:127b8f86374837d78df82d60e05dfeba35c4115597a4412849ac44700e7eae26 | no blocking findings；TR-1 resolved；主会话重算实际产品及证据字节无漂移 |

## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 保持跨Swift/Pi标题生成的R2独立审查义务；用户确认其他任务完成后，当前工作区重新构建且无漂移，需复核TR-1当前版本绑定。
- Snapshot: sha256:127b8f86374837d78df82d60e05dfeba35c4115597a4412849ac44700e7eae26 (tasks/artifacts/resummarize-invalid-session-titles/evidence/round-03/snapshot.json)
- Evidence: Result T1–T3；round-03/build-source.json、content-check.json、build.log、typecheck.log；当前工作区Debug构建/类型/解析/语法检查通过，82文件在构建前后及生成快照前一致；未执行测试或真实模型。
- Task fingerprint: 0a62220a4035043eb0545dd1c09c5ab688c65f71c22fabf3bde31acb47a0b7d9

## Verification

- Passed: 第03轮审查Passed后再次重算82个产品/工程/文档文件及本轮全部证据SHA-256，均匹配127b8f86…快照；报告与TR-1 resolved记录一致，当前源码与已成功Debug构建版本相同；diff --check和Context validate通过。类型/解析/语法检查已记录，未运行测试或真实模型，不启动或重启App/Bridge，不声称运行时模型质量通过。
