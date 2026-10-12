# 从 Session 右键菜单归档 Pi 会话并关闭终端

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 11:54) |
| Artifacts | [Artifacts](../artifacts/archive-pi-session-from-cell/) |
| Kind | Task |

## Target
- [x] T1: Session单元格提供归档菜单，将准确匹配的Pi会话记录保存到iTermate管理的本地归档位置，保留可识别和后续恢复所需信息。
- [x] T2: 仅在归档成功且校验完成后关闭被归档Pi会话对应的终端分屏；不只退出Pi后留下Shell，不关闭同一标签页的其他分屏。无法确认身份或保存失败时不关闭，不删除原始Pi记录。
- [x] T3: 提供归档列表与恢复入口，使用归档记录中的会话ID和原工作目录，在新终端以pi --session恢复；归档快照不被恢复后的写入修改。
- [x] T4: 主面板保留可折叠/展开的Archive分区；只有明确点击Resume按钮才恢复归档会话，点击归档单元格的其他区域不触发恢复；保留现有Settings归档入口和安全恢复流程。
- [x] T5: 归档时调用Pi Agent根据该会话内容生成摘要，并随归档保存；用户将鼠标悬停于归档条目时能查看摘要，了解该会话做了什么。

## Plan

1. 由Pi集成提供明确的活跃会话身份和私有本机归档接口；拒绝运行中、交互未结束、子代理活跃或无法确认安全的归档。
2. 保存原生JSONL历史、当前分支锚点与身份/工作目录/校验信息；本地私有存储，不删除原始记录。
3. Session右键菜单接入归档成功后的关闭，增加归档列表与恢复工作副本入口，支持iTerm2与Ghostty。
4. 归档前使用当前Pi模型生成摘要，生成失败保留会话；摘要随归档保存，在面板和Settings条目悬停展示。只有Resume按钮可恢复，不绑定整行点击。
5. 用户已授权隔离定向测试；完成编译、安全路径测试及独立只读审查，不调用真实模型、不归档/关闭用户真实会话、不擅自重启正常App，并披露人工验收缺口。

## Decisions

- 当前自检快照：evidence/snapshot-03.json sha256:59e7d328e4f25d8f302aa0992666b85a08e1e4511d7a2b741ad8576a21a2cb37，13个源/测试/配置/文档文件；新建文件由哈希清单定位，scope-03.diff含跟踪文件混合差异。本任务不认领此前已完成的问号规则或另一任务的配色/行距变化。evidence/*-03.log保存本次测试证据。入口/输出均为隔离测试；正常App、真实模型及真实终端视觉验收仍未执行。

- 当前会话用户接受了只关闭归档分屏、显式Resume、Pi生成悬停摘要的完整Target。新摘要通过目标Pi进程的modelRegistry.complete使用其当前模型，工具为空，不生成第二条CLI、不修改原会话消息；读取buildSessionProjection以尊重活动分支、压缩和context_edit，仅保留用户/助手可见文本与既有摘要；长输入保留首尾摘录，最大摘要1200字符。
- 摘要调用60秒截止，连接关闭会取消，失败/空结果/超长/非正常完成不写归档或退出。完成后重验sessionId、leafId与空闲条件。App RPC截止90秒，服务连接75秒。新归档要求supportsSummary与非空summary；旧归档缺省summary仍可恢复。
- 修复成功响应发送后的退出时序：响应开始发送即保持关闭锁，发送完成请求正常退出，不因App读到响应后断开连接而跳过退出；发送错误释放关闭锁，不强杀进程。
- iTerm2关闭仍按唯一Session ID、原Shell与空闲状态校验，最多约3秒等待Pi退出后前台信息刷新；发现另一存活进程立即拒绝，始终force=False，仅关闭分屏。Ghostty仍调用单一terminal close，不关闭Tab集合。
- 面板归档行改为普通HStack，只有Resume按钮有恢复action；摘要通过原生help悬停显示并保留身份/时间信息，Settings同样增加摘要help。
- 用户授权后已运行隔离测试：摘要6项、归档IPC生命周期6项、分屏关闭6项、Swift归档5项全通过；另问号文本12项、原生命周期18项及Bridge自检通过。归档IPC使用临时目录与假socket/假shutdown，覆盖无效凭据和会话ID、成功后客户端断开仍退出、摘要失败/取消、分支或忙碌变化、响应写入失败；分屏关闭只用mock验证目标ID、force=False、新活跃进程拒绝、未知/忙碌超时和幂等关闭。未操作真实会话或调用真实模型。
- 已通过TypeScript严格noEmit检查、Swift parse、Python AST、git diff --check、Context校验；Xcode build-for-testing成功（只编译，不执行测试、不启动正常App）。证据evidence/summary-build.log；之后仅修改了同一行help文本且Swift parse通过。未调用真实模型、未安装集成、未操作真实归档/分屏。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [启动依赖故障](../artifacts/archive-pi-session-from-cell/reviews/round-01.md) | evidence/snapshot-01.json | incomplete：宿主缺少pi-agent-core/node，未获得审查反馈 |
| 02 | [独立审查](../artifacts/archive-pi-session-from-cell/reviews/round-02.md) | snapshot-03.json sha256:59e7d328e4f25d8f302aa0992666b85a08e1e4511d7a2b741ad8576a21a2cb37 | no blocking findings；主会话复算清单及13文件一致；run=bc9ea578-16cf-427f-90da-0e565ad71269 |

## Result

- T1: snapshot-03：隔离IPC测试验证凭据/会话ID失败不调用模型，成功写出原生header、完整条目和当前分支锚点，SHA256一致；临时目录mock，不是实际用户会话归档。
- T2: snapshot-03：6项归档IPC测试+6项分屏关闭测试通过；成功响应后断开仍调用假shutdown，失败/取消/分支变化不退出；只对target-pane调用force=False，不关闭other pane，存活替代进程/忙碌/未知身份不关闭。未真实关闭终端，Ghostty单terminal脚本只做源码核查。
- T3: snapshot-03：Swift5项通过包含旧manifest缺少summary仍可读、summary持久化、SHA/header/路径/符号链接校验；prepareResume仍写独立副本，Pi ID/分支恢复格式证据沿用format-check.json，未运行真实CLI恢复。
- T4: snapshot-03：归档行普通HStack只有Resume Button绑定store.resumePiArchive，名称/目录/空白无恢复action；面板与Settings均help展示summary，原颜色/折叠逻辑保留；Xcode构建与归档测试通过，实际鼠标UI未验收。
- T5: snapshot-03：摘要6项mock验证当前Pi模型、活动投影可见文本、无工具/隐藏思考/原始工具输出、首尾限长、60秒截止、失败/取消拒绝；IPC测试验证summary先持久化后退出，Swift验证读取及旧档兼容。未调用真实模型，未证明实际摘要质量。
- Review gate: Passed — fresh只读reviewer bc9ea578-16cf-427f-90da-0e565ad71269 无确定问题；round-02报告已保存并索引；主会话复算snapshot-03清单与13文件完全一致，解除快照证据限制；保留真实UI/模型/终端未验收说明。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 涉及归档数据完整性、模型调用取消、响应/退出竞态与精准关闭分屏，维持Required并进行独立审查。
- Snapshot: snapshot-03.json sha256:59e7d328e4f25d8f302aa0992666b85a08e1e4511d7a2b741ad8576a21a2cb37
- Evidence: Result及evidence/*-03.log：6摘要+6归档IPC+6关闭+5Swift+12文本+18生命周期全通过，Bridge自检、类型检查、构建与diff检查通过。
- Task fingerprint: af2cd47555790a71bdefb5040028cb03b3d0a7d99929adb6ea3339a7c759eaa6

## Verification

- Passed: 审查后最终复跑53项隔离定向测试（18摘要/文本、24归档/生命周期、6分屏关闭、5Swift）及Bridge自检通过；tsc严格检查、diff与Context检查通过；13文件最终哈希一致，日志evidence/*-final.log。未调用真实模型/安装集成/操作用户会话，真实摘要质量与UI/终端端到端仍未验收。
