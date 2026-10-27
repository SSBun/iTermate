# 修复 Pi 与 Codex 状态监听的准确性和恢复问题

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-23 14:12) |
| Artifacts | [Artifacts](../artifacts/fix-pi-codex-state-monitoring/) |
| Kind | Task |

## Target
- [x] T1: Pi 正确区分中止、完成、等待回应与未知子代理状态，辅助分类不阻塞后续输入且覆盖长回复
- [ ] T2: Codex 自动匹配终端中的对话并恢复状态与自动标题，避免明确冲突和过期关联；手动绑定仅为权宜之计，不能作为完成条件
- [x] T3: 完成通知与计数使用可靠的完成身份，避免轮询漏采与状态恢复导致的误计，并完成允许的验证

## Scope

修复上轮分析列出的 Pi/Codex 监听、恢复、分类与完成消费问题。保留用户未提交改动；不运行测试，不启动或重启 App、Bridge、Codex、Pi，不写入用户安装目录。用户明确自动匹配为目标：恢复共享daemon场景的自动关联，优先精确证据、兼容既有自动发现并检测歧义；不能把手动绑定作为目标达成。

## Plan

1. 修复 Pi 生命周期、后台问句分类与子代理快照一致性。
2. 修复 Codex 自动进程和会话身份关联：当前原生thread信号约束FD、兼容启动ID及目录/时间发现、跨进程冲突检测与持续恢复；自动接入已识别thread的官方只读状态源，保留增量读取与退出终态。
3. 同步 Bridge、Swift 状态协议、标题与完成身份、通知计数和回归用例。
4. 更新文档、执行编译与静态检查，并由新上下文 Agent 审查实际变更。

- Current artifacts: 当前源码及本记录 Restart Diagnosis / Screenshot Recheck 中的只读诊断；本轮无产品源码改动。
- Next action: 用户决定是否允许启用 Codex 原生 thread 标题；获准后最小修改配置，并由用户在现有 Codex 中应用或自行重新打开会话，再观察真实 thread 信号与状态。
- Required input: 是否允许将 Codex 用户配置的 tui.terminal_title 从 [] 改为 ["app-name", "thread-id"]；不会主动启动或重启任何 Agent/App。

## Evidence

- 用户明确纠正目标为自动匹配，任何手动绑定都是权宜之计。本轮据此恢复自动会话关联与标题状态链；之前只支持精确CLI文件FD导致共享daemon自动能力回归，不能作为完成结果。

- 用户追加反馈：已识别Agent且生命周期未知时，界面也没有未知提示。沿用同一状态修复任务，在Session行补充nil状态显示；不把unknown改写成idle/running，不改变完成计数。

- 2026-10-22 用户截图反馈延续本次修复：8个Codex CLI已被识别，但均无本进程rollout FD，daemon持有会话。排查并补齐明确绑定后的标题数据，不按cwd或时间猜对话；读取真实进程元数据和单独只读monitor诊断，不启动App或执行测试。

- 修改前工作区已有未提交改动；任务范围原文件保存在 /tmp/itermate-state-fix-before，用于区分本任务变更。当前宿主没有 task_focus 工具。
- 已读取源码、安装的 Pi 1.4.0 类型/runtime 与 Codex 0.163.0 生成协议；已确认取消信号、settled handler 排队语义及官方 thread/read 的非resume性质。

## Task Summary

Pi producer 已修复中止、后台可取消分类和子代理未知状态；Bridge/Swift贯通稳定完成事件及最近64条记录。Codex自动关联恢复原生可写FD、明确启动resume UUID和有限cwd/启动时间兼容，并新增原生terminalWindowName中的当前thread信号用于准确跟随/new和/resume；短前缀核验唯一根metadata，冲突或信号失效不沿用旧关联。自动接入既有daemon只读状态及标题输入，修复官方control socket符号链接被拒绝的问题。用户当前8个进程中4个已由只读新源码诊断自动匹配并返回daemon状态；另4个尚缺身份信号。原生标题配置启用决策仍待用户答复，未修改用户配置或运行安装态。T2不以手动绑定或仅编译通过视为完成。

## Implementation Evidence

- 本任务相对修改前的精确差异及当前 SHA256 清单见 [changes.patch](../artifacts/fix-pi-codex-state-monitoring/evidence/changes.patch)、[scope.json](../artifacts/fix-pi-codex-state-monitoring/evidence/scope.json)。当前清单SHA256为 `89c82faccc6fafc9762ce6cf98080a29399b410a9957c71298b4efb233d90ddd`；截图反馈前的scope为77d4c6da。Xcode工程由既有project.yml生成以加入两份新Swift文件；原有用户移除Ghostty等未提交修改保留。
- Xcode Debug build 通过；最终 `xcodebuild ... build-for-testing` 于2026-10-22完成，仅编译App和测试bundle，未执行测试、未启动App。日志 `/tmp/itermate-state-fix-build.log` 与 `/tmp/itermate-state-fix-test-build.log`；后者为 `TEST BUILD SUCCEEDED`。Xcode仅报告既有AppIntents元数据跳过、XCTest SDK部署版本链接警告。
- 主Agent执行 TypeScript `tsc --noEmit --skipLibCheck --target esnext --module esnext --moduleResolution node`（使用本机Pi包类型）、TS与3份MJS的 `node --check`、Python `ast.parse`、`git diff --check`，均退出0；未执行脚本业务代码或测试。
- 核对Pi 1.4.0取消与settled语义、Codex 0.163.0官方schema、v0.100.0/v0.163.0官方任务结束及rollout策略：旧版失败Error不持久化且task_complete不带结果，新版error有效、success省略error。因此旧版/能力不明结果为unknown，新版能力基线还要求逐事件时间字段；不从文件增长或缺少error单独猜成功。
- 授权范围没有真实运行/测试：未连接daemon、未启动或重启App/Bridge/Pi/Codex、未写入已安装集成或用户配置。真实UI、通知送达、daemon握手兼容仍未验证。自动rollout不能恢复等待审批；显式绑定只跟踪指定thread，切换后需重绑。完成历史为有界窗口而非离线账本。
- 当前collaboration.spawn_agent支持fresh context，但没有只读工具限制参数。task-review SKILL.md明确要求host级只读tools isolation，不允许仅prompt替代；该正式R2门禁当前不可用。额外实现协作者静态自检不替代或冒称正式Review Passed。

## Screenshot Follow-up Evidence

- 用户截图中的方框是Codex Agent图标，圆圈才是普通命令；原生进程识别和嵌套PTY父子链正常。独立只读monitor诊断当前8个可见TTY均识别到Codex PID，但status unknown、sessionID nil、excerpt为空。lsof仅统计路径：8个CLI均无rollout文件FD，daemon持有36个。无需暴露对话内容即复现缺口。
- 根因：上轮严格自动绑定仅依赖CLI自身的可写FD，当前daemon托管模式无法满足；手动绑定又只读状态且丢弃Thread.path，导致即使绑定也不能提供标题输入。已把最终thread/read的可选path贯通到后台增量读取器，验证当前进程、普通文件/所有者、inode、根metadata和准确thread UUID；路径不可用不影响状态。新增回归用例覆盖绑定无FD、追加、错误thread、进程清理、子代理、符号链接、异常path字段。
- 当前Codex 0.163公开协议没有可靠的PID/TTY→当前thread映射：ClientInfo不含终端身份，thread/loaded/list仅返回ID，内部ConnectionId→多个订阅thread不公开也不等于前台thread。未恢复cwd/时间猜测；现有未绑定daemon会话仍需/status UUID显式绑定。当前补丁不声称恢复无配置全自动标题。官方依据：https://learn.chatgpt.com/docs/app-server ，https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/app-server/src/thread_state.rs#L348 。
- 当前App与测试bundle build-for-testing通过，8.480秒，日志/tmp/itermate-codex-regression-build.log；无测试执行、无live daemon请求、未启动/重启App或任何agent。原App PID49055及8个CLI PID仍存活。文档Context校验和git diff --check通过。辅助源码自检未发现确证问题，不替代正式隔离Review。

## Unknown Agent UI Follow-up

- 根因：status=nil被Session行的所有现有状态分支跳过；Agent身份正确但状态区域留白。已添加environmentAgentKind非空且status=nil分支，使用像素Canvas呼吸感叹号、减少动态效果静止、悬停说明与整行accessibilityValue。普通Shell不显示该提示；数据仍为unknown，不新增生命周期或完成事件。显式行ID已区分nil与idle。
- 当前App Debug build通过4.766秒，日志/tmp/itermate-unknown-agent-build.log；git diff --check与Context validate通过。协作者静态核对该条件覆盖Pi租约过期及旧Agent且不会按名称误标Shell，建议的行级无障碍值已补齐。未运行测试、未启动或重启App，视觉和VoiceOver实际效果尚未验证。此为补充owner自检，正式工具隔离review仍不可用。

## Automatic Matching Follow-up

- 根因回证：严格FD-only版本在当前共享daemon环境对8个可见CLI全部无thread/摘录；恢复兼容关联后4/8获得thread与可见摘录。只读真实daemon查询均成功，分别返回running、finished、finished、running；其中一个rollout状态unknown由daemon补为running。没有输出对话文本或完整thread ID。
- Codex官方terminal_title=["app-name", "thread-id"]可输出当前显示thread的29字符UUID前缀；Bridge每快照读取原始terminalWindowName，匹配完整UUID并核验根metadata。当前信号优先于陈旧FD；信号丢失、子代理/歧义无回退；仍支持没有原生信号时的启动兼容。自动关联与标题无需逐次手动绑定。
- Codex用户配置目前禁用了terminal_title。本轮已向用户询问一次性启用偏好，尚未收到答复，因此未写配置；未把时间经过当作许可。未启动/重启App、Bridge、CLI或daemon。现有四个无关联会话和真实终端标题转发仍未验证恢复。
- daemon官方control路径实际是同用户符号链接；旧lstat仅接受socket导致请求入口直接失败，已验证link+resolved socket均属当前用户并支持它。真实只读initialize/thread/read/turns/list/final thread/read已返回状态、8条完成历史及rollout路径。
- Store自动关联随PID/start/TTY/terminalID/thread变化失效，文件生命周期更新后旧daemon响应不能覆盖；查询失败保留原生证据。Bridge身份信号变化立即取消旧标题与runtime，完成时间合并保留rollout小数精度。完成最终读取仍有界且不重复。
- 补充协作者源码自检未发现Bridge/daemon/Monitor的新确证问题；该检查不具有宿主工具隔离，不替代正式R2审查。回归fixtures已增加但不执行。

- 最终自动匹配版本scope SHA256：`797c2ec8ffd218cd3efcc3cbb2fa85e0e0414560eec5d1906e5af54afedf09f2`（21文件）。App与测试bundle编译通过（TEST BUILD SUCCEEDED，3.456秒），日志/tmp/itermate-automatic-match-build.log；只余既有XCTest部署版本与AppIntents元数据警告。Python AST、Context validate与diff检查通过，未执行测试、未启动安装态。

## Restart Diagnosis

- 用户反馈重启后仍存在问题；具体会话与实际/显示状态已异步询问，尚待补充。沿用T2自动匹配目标，不把本次反馈当作允许修改Codex用户配置。
- 2026-10-22 20:36新App PID26273及Bridge PID26386已运行。App debug dylib具有本次自动关联与原生thread字段，source/bundle/installed Bridge哈希均2592aa918fe7fdbe39b3f7c13f022804ad09c6ab0e7d8bc0578141bdb75e4a56；21文件scope与上轮编译版本无漂移。
- 当前19个Bridge终端均无原生thread hint，Codex tui.terminal_title仍为空。只读Monitor诊断识别10个Codex，5个自动匹配（TTY012/024/028/047/060），5个缺关联（002/004/010/014/055）；已匹配5个均有可见摘录且现有daemon查询成功。采样时4个finished、060为running，后者rollout本身unknown。
- 已匹配5个均存在非空标题缓存、thread身份及摘录摘要，PID与当前匹配；成功生成不记日志，不能从零失败断言每个均在本次重新调用模型。当前App标题日志仅一次20:36:23手动session_unavailable，无自动失败记录；自动补全采用默认开启。
- 仅只读诊断及任务记录更新；未更改源码、用户配置、模型或运行进程，未执行测试。仍需用户指出具体异常以区分已知未映射与其他显示问题。

- 20:44用户截图明确显示5个默认标题/unknown Codex：iTermate2、MyTwitter1、skills2，数量与未映射进程一致。已确认目标失败仍在自动身份关联，并非Agent未识别。
- 对这5个CLI补充只读检查：CODEX_HOME均为默认、ITERM_SESSION_ID存在，但无CODEX_THREAD_ID或其他当前thread环境身份。日志数据库虽有精确进程UUID，其thread_id列对5个CLI均无非空记录；日志正文含测试fixture UUID，不能通过任意UUID提取绑定。状态数据库未提供PID/TTY归属表。结论限定于已检查的运行日志/元数据，未声称穷尽所有机制。
- 已向用户提供具体一次性配置选择：terminal_title从[]改为["app-name","thread-id"]，会改变原生标题并需新启动/重新加载配置的Codex生效；仍待回复，未把截图视为修改配置许可。无新增源码修改、测试执行或进程启动。

## Screenshot Recheck

- 2026-10-23 用户确认继续排查截图中的无有效状态会话，保留不测试、不重启、不擅改配置的边界。本轮从真实 Bridge socket 只读采样17个终端，原生thread hint为0；Codex配置的tui.terminal_title仍为[]。
- 用当前仓库的CodexSessionMonitor.swift和CodexAppServerClient.swift编译现有独立只读诊断入口并观察全部可见TTY：6个原生Codex中4个自动匹配且daemon读取成功，另外2个无匹配，分别属于skills和MyTwitter。截图后的会话集合已变化，skills另一个终端当前由Pi报告idle，不能把旧截图当作当前全部会话状态。
- 两个未匹配CLI均无rollout文件FD、无resume参数和UUID参数，启动±30秒内同目录根会话候选均为0；在所查启动日前后一天范围内，最近同目录根会话分别相距75.663秒与63.124秒。不能仅扩大时间窗口便认定为当前对话。
- 4个已匹配会话的原生rollout状态/daemon状态分别为running/running、unknown/running、finished/finished、unknown/running；证明daemon通路可用，但不能代替另两个终端缺失的thread身份。未输出对话正文、完整thread UUID或凭据。
- 本轮未改产品源码、用户配置或安装态，未执行测试、未启动或重启App/Bridge/Agent；独立只读诊断不是测试套件，也不作为正式R2审查。本任务T2仍未满足，原有Required门禁保留。
- Context维护：完整元数据索引与相关Pack已经覆盖原生thread标题、有限启动匹配和unknown语义，本轮无新增稳定事实或源码变化需要写入Context。

## Block

- Reason: 当前两个Codex终端缺少可确认的当前thread身份，原生标题信号被用户配置显式关闭；现有可用自动路径不能关联，不能伪造状态或擅自修改用户配置。T2尚未达成，原有R2 Required审查义务保留。
- Unblock when: 用户明确授权启用原生thread标题，并在现有Codex会话应用新配置或自行重开后提供真实身份信号；或出现另一条可验证的当前终端到thread的准确身份来源。恢复后继续只读观察，不因许可配置修改而自动重启进程。

## Result

- T1: Pi取消/后台分类/完整输入预算/子代理三态与push-query共享派生已静态核对，TS noEmit和node语法检查通过；回归用例已编写未执行，见Implementation Evidence。
- 实现协作者只读自检发现并已修复：显式绑定退出前缺少最终daemon历史读取；启动小数秒与Codex整秒时间造成漏计；首版同秒补偿可串用其他thread运行证据。现在退出做最终有界只读历史查询，未加载thread仅提供完成事件；同秒补偿使用贯通producer/Store/snapshot的完整completionInProgressID，不能借用同终端的其他thread/turn。对应fixture已编写且测试bundle重新编译成功，未执行测试。该协作者未改文件，不宣称正式隔离Reviewer。
- T2: 当前scope 77d4c6da的Codex FD/增量/最终文件与daemon历史读取和显式绑定已静态核对，正式schema核实unloaded只读turns/list可行；App与测试bundle重新编译通过，未连接真实daemon或启动App。
- T3: 当前scope 77d4c6da完成历史/去重与跨数据源统一ID已贯通，同秒补偿精确绑定completionInProgressID，新增跨thread历史和小数基线fixtures；最终测试bundle编译通过7.332秒，Python AST/diff检查通过，未执行测试。
- 最终实现协作者自检：对同turn ID补偿及字段贯通未发现确证问题，21个scope哈希前后均一致（77d4c6da…cd3438）；结果仅作为owner self-check补充，不代替缺失的正式工具隔离审查。
- Review gate: Required — R2正式门禁要求工具级只读fresh Reviewer，当前宿主无法提供该能力；实现协作者自检不替代。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 自动thread关联、daemon状态与异步标题跨进程链路，延续Required审查义务。
- Snapshot: sha256:797c2ec8ffd218cd3efcc3cbb2fa85e0e0414560eec5d1906e5af54afedf09f2 (tasks/artifacts/fix-pi-codex-state-monitoring/evidence/scope.json)
- Evidence: Automatic Matching Follow-up：App与测试bundle编译通过3.456秒；真实8进程只读诊断4个自动关联且daemon查询成功；AST/Context/diff校验通过。未执行测试或重启应用；另4个缺身份信号，原生title配置偏好待回复。
- Task fingerprint: 009b263a93fc0add1a5191609b8c43f145e21c18024b47ae9768f014ddabc3bc
