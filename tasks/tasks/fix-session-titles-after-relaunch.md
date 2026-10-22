# 修复重启后摘要标题缺失并自动补全无标题会话

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-22 16:32) |
| Artifacts | [Artifacts](../artifacts/fix-session-titles-after-relaunch/) |
| Kind | Task |

## Scope

仅处理 App 重开后的摘要恢复、AI 页缺失标题补全偏好以及 Pi/Codex 的受控补全。保留已有标题随新任务完成而更新的行为和手动刷新，不改变终端原标题、Agent 状态或无关布局。工作区其他会话的未提交变更不属于本任务。用户进一步明确：本任务只控制自动生成，生成问题由另一个任务负责；标题长度、换行、生成质量及新旧标题格式校验均不由本任务决定或修改。恢复仅消费生成任务认可的有效标题。

## Target
- [x] T1: 重新打开 iTermate 后，符合独立生成任务现行标题规则的已有摘要标题仍能恢复显示，本任务不修改标题校验规则。
- [x] T2: 在 AI 设置页提供持久化的自动补全缺失摘要标题开关；启用时，对没有摘要标题且有可用会话内容的会话自动生成标题，不覆盖已有有效标题；关闭时不自动补全缺失标题。
- [x] T3: 针对用户反馈 Codex 不自动生成标题，复核当前运行态与自动补全条件，说明有证据支持的阻断原因或明确仍缺少的证据；不改生成规则。

## Plan

1. 确认标题来源、内存生命周期和缺失标题生成条件。
2. 保存并恢复既有标题，为缺失标题接入 AI 页共享偏好及受控生成。
3. 编译 App 与回归用例、静态检查 TypeScript，独立复审当前改动；不执行测试、不自行启动或安装 App/集成。

## Decisions

- 开关默认开启，仅控制缺失标题补全；已有有效标题自然更新与手动刷新保留。
- 用户明确职责：“You just control the automatic generation of title. The other task is to fix the generation issue.” 此为既有任务边界澄清，不要求重新选择旧标题格式策略；TR-1 以另一任务的生成/校验责任重新分类，由下一新鲜复审验证。
- 常规配置写入拒绝覆盖无效或不可读文件；配置损坏时提供需用户确认的备份并重置入口，先保存私有原始副本，不下载/启动模型，补全默认关闭。
- Codex 缓存绑定终端与进程身份，只持久化标题和摘录哈希；不保存会话原文。重开后的缺失补全不再要求已知或非运行状态，只依赖已识别身份、会话映射、可见摘录及开关；已有标题自动更新仍要求finished。本任务不修改30秒会话映射或生命周期判定。
- Pi 仍从活跃实例发现信息恢复标题；独立 ensureTitle 动作检查缺失与偏好，复用自动去重、失败预算和会话核验。旧集成需要更新并 reload。

## Task Summary

**应用标题与 AI 设置**：[iTermate](../../iTermate/) 增加摘要标题持久化恢复、共享的缺失标题补全偏好与 AI 页开关，以及受控的 Pi 自动补全调度；修正 Codex 补全被运行/未知状态阻断的问题，保留身份、摘录、偏好与请求核验；原有手动刷新保持可用；为共享配置保护引入的损坏配置恢复回归增加明确确认、私有备份后重置的入口。

**Pi 集成**：[Pi](../../integrations/pi/) 增加受共享偏好控制、仅补缺失标题的认证动作，复用现有生成和身份保护。

**回归用例**：[iTermateTests](../../iTermateTests/) 补充重开恢复、身份复用、开关持久化和共享配置保留用例，并隔离标题缓存偏好；补充Codex运行/未知状态下的开关关闭阻断、开启补全与成功去重用例。

**使用说明**：[docs](../../docs/) 说明 AI 开关、缓存身份、Pi 更新要求和缺失标题补全边界。

## Result

- T1: 缓存保存/恢复在本轮未改，身份保护与生成任务现行校验仍在生成门之前；本轮Debug App/回归目标仅编译成功。见self-check-round03.md。
- T2: 修正Codex缺失补全的运行/未知状态阻断；已有标题更新仍等finished，偏好/身份/摘录/request核验保留。新增nil/running开关用例仅编译成功；TS noEmit/diff/context通过。见self-check-round03.md。
- T3: 只读运行态观察：当前App已16:18重开、补全默认开启；3个已匹配Codex会话尾部有可见消息却无生命周期事件，旧状态门阻止补全。另一进程最近会话时间差63.1秒超30秒且无明确Session参数，属独立映射限制未改；日志当前App手动session_unavailable不等于模型生成失败。详见self-check-round03.md。
- Review gate: Passed — fresh只读reviewer ea5b7d01-8827-4cc4-a878-d849e7291226无新发现，round-03.md已保存；owner重算snapshot-03自身、11个源/文档和2个证据哈希全部匹配，无相关漂移。已披露新App实际运行未验证。
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/fix-session-titles-after-relaunch/reviews/round-01.md) | sha256:420c0758b5e155e7def500c6004bc0421124ac640f42d4bb92c2d59e96142fba | invalidated by drift；findings: TR-1、TR-2 |
| 02 | [Round 02](../artifacts/fix-session-titles-after-relaunch/reviews/round-02.md) | sha256:9df2fcbe8aecb1493a1cc296783e929a49fcdac2e81113c7fe5062b32d50d701 | no blocking findings；TR-1、TR-2 resolved；内容绑定经 owner 重算与范围外 Commands 用例差异核验 |
| 03 | [Round 03](../artifacts/fix-session-titles-after-relaunch/reviews/round-03.md) | sha256:f5e3e0762f7505470cd3917cc56f0ade5c9d9ddb5872447ec0fb5a2c63f5cffc | no blocking findings；owner重算所有源/文档/证据哈希一致，drift_count=0 |

## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 重开补全触发涉及在途结果与状态门边界，保持原Required并复审本轮修正。
- Snapshot: evidence/snapshot-03.json:sha256:f5e3e0762f7505470cd3917cc56f0ade5c9d9ddb5872447ec0fb5a2c63f5cffc
- Evidence: ../artifacts/fix-session-titles-after-relaunch/evidence/self-check-round03.md；Debug build-for-testing仅编译成功；TS/diff/context通过；运行态排查仅只读元数据，无测试/模型/新App执行。
- Task fingerprint: 8be2d758dd47b1f84cce1cc6a3492a6f8e4a3541fe914556dc05c8f9df4f7027

## Verification

- Passed: round03独立复审无阻塞且最终scope drift=[]；16:31 Debug App BUILD SUCCEEDED，TS noEmit、diff和Context校验通过。已有补全逻辑与根因解释经静态核验；未执行测试、真实模型/RPC、新App或重启。独立63.1秒映射问题保留并披露，未承诺该未映射会话已补全。
