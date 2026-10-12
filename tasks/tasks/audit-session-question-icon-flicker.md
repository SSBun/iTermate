# 审计本地改动导致的 Session 问号泛滥与闪烁

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-12 15:56) |
| Kind | Plan |

## Target

- [ ] T1: 审计当前本地改动，解释 Session 列表大量显示问号及图标反复出现消失的原因，给出证据并区分已确认问题与待验证假设。

## Scope

- 只读审计与该现象有关的本地差异、实际运行副本及 Bridge 快照；不修复产品代码，不启动或重启 App、Bridge 或模型，不运行测试套件。
- 工作区存在并发修改；本记录将观测时运行版本和交付时工作区分别说明，不对所有未提交改动作全面质量背书。

## Decisions

### 已确认：轮询周期大于缓存寿命导致问号周期性消失

- 运行副本 `/Users/caishilin/Library/Application Support/iTerm2/Scripts/AutoLaunch/iTermateBridge.py` 第20、804–875、925–935行：每2秒选择一个缺失真实状态的Session分析；model_observations只保留8秒，model_state也在8秒后返回空。
- 连续45.9秒读取153份真实快照：22个Session中9个没有生命周期状态；起始仅1个真实awaitingInput、4个模型awaitingInput。9个无生命周期状态的Session在modelState=awaitingInput与null之间各切换4至5次，status和activityKind始终为空。
- 例：iTermate会话9212594F在相对2.0秒变空，12.0秒变awaitingInput，20.1秒变空，30.5秒再次变awaitingInput；skills会话440F5086在6.0秒变空、16.1秒恢复、24.1秒变空、34.3秒恢复。9个候选轮询一圈约18秒，8秒有效期必然留下约10秒空窗。
- 该2秒轮询/8秒缓存设计在HEAD已经存在，并非本轮新引入；新UI将辅助估计显示为正式问号，使已有缺陷变得明显。这里不是模型反复改变分类，更不是仅凭UI动画推断的闪烁：直接观测到了数据字段过期。

### 已确认：辅助估计被呈现成与真实待回复相同的问号

- 审计开始时本地 `iTermate/iTermateApp.swift` 差异中，原有brain图标和Reply?弱提示被替换为AgentWaitingStatusView(.questionMark)，只以tooltip/accessibility文字区分“local model estimate”。它与真实awaitingInput的可见问号相同。
- 因此大量问号不等于大量会话确实在等待回复。此次观测的9个轮换问号来自modelState通道，不是Pi生命周期报告。初始1个真实待回复没有出现这种周期性消失；观测期间另1个会话从真实running正常转为awaitingInput。

### 已确认的风险放大：二分类与阈值移除，但未证明每个分类都错误

- HEAD的Bridge要求分类概率至少0.85，awaitingInput还要求needs_reply至少0.6。运行副本第863–874行改为只验证二分类概率合法且所选类别胜出，无高置信度门槛。
- 运行中模型helper第36–54行把终端SESSION_QUESTIONS从running/awaitingInput/idle/unknown改为idle/awaitingInput，复用“助手最后回复是否请求用户参与”的提示词；Bridge第846行实际传入的是终端屏幕最后1500字符，而不是经过角色和轮次识别的最后助手回复。它还对所有无真实状态的Session分析，不要求已确认Agent身份。
- 这些改动移除了未知/运行中出口，并可能把屏幕中的历史问题、引用或其他文本当作当前请求。此次9个候选都曾被标为awaitingInput；但没有逐个阅读用户会话内容并标注真值，因此不能声称这9个分类全部错误，也没有实际概率值来断言全是低置信结果。
- 异常、800ms请求超时、屏幕在推理期间改变都会删除估计，可进一步加剧消失；本次周期性证据已由轮询/TTL完整解释，没有证据把这些异常列为已发生主因。

### 版本与证据边界

- HEAD为2cf8858f347979f78b16f0d2eecac1fa1b0de7d6。观测期间App PID67453、Bridge PID67525保持未变，均于2026-10-12 15:44启动；没有由本会话启动或重启。
- 运行Bridge磁盘副本与App bundle资源一致，SHA-256为b7e8ea509df91251b3af8419433ac9676056c4b89d0ac9a87c9ed183e96debc7，观测前后未变。运行模型helper为faed5192fb1ff8bf9ff29a7f3bca23c2e3b5832dbccc152f3755a91ad5c349e0。
- 另一路修改在本次审计期间已移除工作区Bridge模型观察和Swift模型估计展示；结束时工作区Bridge为42b54bb983a83cda45cd12acfc8407cb1995b5c95a177994f37c001318a11f4c，App Swift为06ce2a9efb5974bc5e8be29e97fbc0edaf3897ec936145e9d73615021ddf33a9。这些不是本任务所作修复，也尚未证明已经构建运行。
- Pi集成源码、bundle资源与安装磁盘副本hash一致，但不据此断言所有既有Pi进程已reload。此项不是9个modelState轮换现象的必要解释。

## Plan

1. 将真实待回复与屏幕估计明确分离。建议保留Pi生命周期和最后回复判定，移除终端屏幕推测对正式问号的贡献；当前并发修改正在沿该方向进行，不重复实施。
2. 若未来仍保留屏幕估计，单独展示不确定来源；解决候选数量增长导致轮询大于有效期的问题，不能仅延长TTL或给UI加防抖来掩盖过期与语义不可靠。
3. 由对应修改的拥有者完成后续构建与运行验证：同批会话跨至少两轮原轮询周期观察，确认无真实状态的Session不再周期显示问号，真实待回复仍保留且收到新输入后正确清除。本任务不执行修复或启动验收。
