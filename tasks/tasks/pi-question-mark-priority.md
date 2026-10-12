# 确保 Pi 待回复问题显示问号而非空闲图标

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 10:22) |
| Artifacts | [Artifacts](../artifacts/pi-question-mark-priority/) |
| Kind | Task |

## Target
- [x] T1: Pi 最后一条回答是在向用户提问或请求确认且仍待回复时，iTermate 显示问号，不显示空闲图标。
- [x] T2: 判定依据是实际待用户回应的语义，不仅是问号字符；覆盖无问号的确认请求，排除引用、示例和自问自答。

## Scope

只修改 Pi 待回复判定与等待符号样式，不修改 Codex，不覆盖用户安装目录，不启动或重启应用。工作区存在其他任务的并发未提交变更，必须保留。

## Plan

1. 保留模型或明确文本请求产生的肯定待回复信号，避免否定模型结果或关闭模型开关撤销已识别问题。
2. 补齐直接结尾问题和隐含确认请求；等待样式仅允许问号，沿用已有 Canvas 动画和颜色设置。
3. 生命周期夹具与状态保持验证已完成，完成独立审查及最终验证后交付；真实终端 UI 未启动验收。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/pi-question-mark-priority/reviews/round-01.md) | snapshot-01.json sha256:c09d61563c43b28bf4ce6c50769c0e095aaf25ea0b3ab9bf4f0e61603db37995 | findings: TR-1；主会话复算全部8文件哈希一致 |
| 02 | [Round 02](../artifacts/pi-question-mark-priority/reviews/round-02.md) | snapshot-02.json sha256:8bb3a1da31736e300dae481f11b08bfed88213677c62bcee0918c71bcb108c5f | TR-1 substantive progress，新增TR-2；主会话复算全部8文件哈希一致 |
| 03 | [Round 03](../artifacts/pi-question-mark-priority/reviews/round-03.md) | snapshot-03.json sha256:b5791d942b5561bc316ab32145542f93604a581510c73089ce5847e800738225 | TR-1 substantive progress，TR-2 resolved；主会话复算全部8文件哈希一致 |
| 04 | [Round 04](../artifacts/pi-question-mark-priority/reviews/round-04.md) | snapshot-04.json sha256:6a10237536eaecc50b71e1b3b82a3c830b62f8857142bff3a8cc03b93b92931f | TR-1 substantive progress，TR-2 resolved；主会话复算全部8文件哈希一致 |
| 05 | [Round 05](../artifacts/pi-question-mark-priority/reviews/round-05.md) | snapshot-05.json sha256:658dcac846aa208161d06307e7191b461796a11aa125634bccf0a9ccc74d7094 | TR-1/TR-2 resolved，新增TR-3；主会话复算全部8文件哈希一致 |
| 06 | [Round 06](../artifacts/pi-question-mark-priority/reviews/round-06.md) | snapshot-06.json sha256:2901b0152f93760611130a6f65b1e07833c00bbad60c83a769b6575cbf7e7651 | no blocking findings；TR-1/TR-2/TR-3 resolved；主会话复算清单及全部8文件一致；run=dfdae7d0-951e-4ff3-addc-9839b890f295 |

## Decisions

- 第6轮前自检：复现TR-3未来计划被结果排除的false。动作匹配保留未来情态词捕获，明确会/将/再/才/就或直到/直至的终止条件不按已发生结果处理；完成体了/过仍独立排除，防止历史动作放行。新增所有情态词及终止条件正例和完成叙述负例，模型禁用下生命周期保持确认请求。文本12/12、生命周期18/18、Bridge自检及diff检查通过（*-06.log）；snapshot-06.json sha256:2901b0152f93760611130a6f65b1e07833c00bbad60c83a769b6575cbf7e7651。Swift文件未变，2/2证据有效。TR-3有实体修复与新增证据，no-progress=0；TR-1/TR-2已由第5轮解决。

- 第5轮前自检：实际复现提交成功、测试通过的无了结果叙述。新增统一动作后缀的独立完成结果分句检查（成功/失败/通过/完毕/完成/结束在逗号或句末），避免把通过校验的文件、成功后再继续误当结果；补充4个结果反例、未来与定语正例及生命周期反例。文本11/11、生命周期17/17、Bridge自检与diff检查通过（*-05.log）。snapshot-05.json sha256:658dcac846aa208161d06307e7191b461796a11aa125634bccf0a9ccc74d7094；Swift文件未变，2/2证据仍有效。TR-1有新实体判断和验证，no-progress=0，待复审。

- 第4轮前自检：复现开始了测试仍误报。移除重复的完成态动作列表，改为在唯一动作匹配后的捕获后缀检查完成标记；为全部10种动作逐一验证将来叙述和了/过/好了/完了/句末了的反例，并将开始了测试加入生命周期负例。文本10/10、生命周期17/17、Bridge自检和diff检查通过（*-04.log）。snapshot-04.json sha256:6a10237536eaecc50b71e1b3b82a3c830b62f8857142bff3a8cc03b93b92931f；Swift文件未变，2/2证据仍有效。TR-1实体改动和覆盖扩展，no-progress=0；TR-2已由第3轮解决。

- 第3轮前自检：主会话再次复现TR-1保存好了误报与TR-2旧句否定取消新问题，再将否定过滤局限到最终请求句，完成态规则覆盖动作结果补语与句末了。新增保存好了/保存完了/保存过/保存文件了反例，保存文件/保存好文件与混合旧否定新问题正例，并增加生命周期覆盖。文本9/9、生命周期17/17、Python Bridge自检及diff检查通过（*-03.log）；Swift2/2证据继续来自*-02.log，对应Swift文件哈希未变化。snapshot-03.json sha256:b5791d942b5561bc316ab32145542f93604a581510c73089ce5847e800738225；两项均有实体修复和新增证据，no-progress保持0，待独立复审。

- 第1轮 TR-1 已由主会话执行复现：两条反例修改前均返回 true。新增回归测试先失败，再补充否定请求过滤并收紧确认后动作的语法，排除已经/已及提交了/修改完毕等完成叙述。当前文本9/9、生命周期16/16、Swift2/2、Python Bridge自检与diff检查通过；日志为 evidence/*-02.log，内容身份为 snapshot-02.json（sha256:8bb3a1da31736e300dae481f11b08bfed88213677c62bcee0918c71bcb108c5f）。旧快照和日志保留为前轮证据，TR-1 待独立复审确认，no-progress=0。

- 当前修改：`integrations/pi/iTermate-integration.ts` 增加直接结尾请求与确认后写入等识别，模型肯定与正则肯定合并，待回复保留到下一轮或会话导航；`iTermate/iTermateApp.swift` 的等待 availableStyles 仅保留 questionMark，旧样式由既有偏好校验回退到问号。
- 已同步更新 `integrations/pi/iTermate-integration.test.ts` 和 `iTermateTests/PanelLayoutTests.swift` 的预期与回归用例。用户随后明确授权 run tests：tsx 文本与模型判定测试 8/8 通过，Xcode 定向运行等待样式与偏好回退测试 2/2 通过。
- 用户明确要求 continue 后，补齐生命周期夹具的纯 mock 导出；归档 I/O 被显式隔离为不可用，不接触真实文件或 socket，不修改归档实现。新增 iTerm2/Ghostty 的模型否定保留明确问题、模型肯定后关闭分析仍持续心跳、下一轮恢复 running/finished，以及模型 429 仍保留直接问题用例。生命周期测试 15/15 通过，文本分类测试再次 8/8 通过，Python Bridge --self-test 退出 0。
- Swift 命令为 xcodebuild test，scheme=iTermate，destination=platform=macOS，derivedDataPath=/tmp/itermate-question-priority-tests，仅选择 ItermBridgeTests/testWaitingStylesStayVisibleAndStatic 和 PanelLayoutTests/testWaitingStatusAlwaysUsesQuestionMarkAndPreservesColor；构建与两项测试通过。XCTest 宿主跳过 AppDelegate 正常启动流程，未主动重启用户运行中的应用或安装集成。日志 `/tmp/itermate-question-priority-xcode.log`，结果 `/tmp/itermate-question-priority-tests/Logs/Test/Test-iTermate-2026.10.10_09-48-46-+0800.xcresult`。
- 已运行 Node stripTypeScriptTypes + SourceTextModule 仅解析两份 TypeScript 文件（未链接、未执行），Swift frontend parse 两份 Swift 文件，git diff --check，均通过。语法检查不是行为验证。
- 修改前 Pi 集成与 UI 副本暂存于 `/tmp/itermate-question-priority-baseline/`；后续审查必须限定本任务差异，不能把归档功能的并发变更认领为本任务。
- 当前待 R2 独立审查：实际产物身份见 `../artifacts/pi-question-mark-priority/evidence/snapshot-01.json`；测试日志及混合工作区 diff 同目录。diff 包含同文件归档任务的既有修改，本任务范围仅文本判定、模型肯定合并与保持、问号样式及配套测试/mock。模型和规则不能对任意自然语言提供百分之百识别保证；未实际调用 Laya 推理或重启用户应用，不把 mock 的模型输出当成真实模型准确率证据。

## Result

- T1: snapshot-06：生命周期18/18，包括模型禁用下未来确认直到测试通过持续awaitingInput与心跳；其余等待优先与下一轮清理保持。Swift2/2对应源码未变，无真实UI/Laya准确率验收。
- T2: snapshot-06：文本12/12，包括完成叙述、情态未来及终止条件对比、所有动作完成体矩阵、引用示例自问自答；Bridge自检与diff检查通过。日志*-06.log。
- Review gate: Passed — fresh只读reviewer run dfdae7d0-951e-4ff3-addc-9839b890f295，第6轮无阻断发现，TR-1/TR-2/TR-3全部resolved；报告已保存reviews/round-06.md并索引，主会话复算清单与8文件哈希一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: TR-3保留情态及终止条件语义，需独立复审。
- Snapshot: snapshot-06.json sha256:2901b0152f93760611130a6f65b1e07833c00bbad60c83a769b6575cbf7e7651
- Evidence: Result、*-06.log文本12/12生命周期18/18；Swift2/2对应文件未变。
- Task fingerprint: 41c00aa62456631ce6f674359c70ff9dac6fa5db2a35d5a8fa802f4a58b1c9ac

## Verification

- Passed: 独立审查后复跑：文本12/12、生命周期18/18、Xcode定向2/2、Bridge自检全部通过，日志evidence/*-final.log；diff检查和Context校验通过；受审8文件哈希最终一致。未安装用户集成或启动正常App，真实UI和Laya准确率未验收。
