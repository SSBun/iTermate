# 调查已更新 Pi 集成仍未显示问号的运行时原因

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-10 14:39) |
| Artifacts | [Artifacts](../artifacts/investigate-live-pi-question-state/) |
| Kind | Plan |

## Target

- [ ] T1: 查明新截图中“确认后，我会修改解析逻辑并重新评审。”未显示问号的实际运行时原因，以该Session读取的回答、集成加载状态和上报/接收状态为证据，区分已确认事实与假设。
- [x] T2: 新增并运行Laya回答类型识别的定向测试，覆盖普通回答、明确问题、无问号确认请求及易混淆反例，包含截图句子；以真实本地Laya结果判断区分能力，记录分类、置信度和失败原因，不用mock或正则结果代替真实模型能力证据。

## Scope

- 保留原运行时调查；本次新增Laya类型识别测试与测试样本/证据，不修改产品识别规则。
- 用户确认并说明Laya已运行后，本次新增并运行真实本地Laya样例验证；不运行无关测试套件。
- 不修改安装文件或配置，不重载或重启Pi、App、Bridge或模型服务；本地模型不可用时明确报告阻塞，不调用云端模型代替。

## Decisions

- 已新增 `integrations/laya/answer-types.test.ts`：16条固定中英文样例，覆盖普通完成陈述、明确问题、无问号确认、否定回复、引用/代码、自问自答、过去完成及未来条件。使用Node test断言真实 `/v1/session` 返回，并调用产品的modelReplyDecision检查采用门槛，不使用mock或needsReply正则。
- 测试默认不调用模型，须显式 `ITERMATE_LAYA_LIVE=1`；只允许127.0.0.1 HTTP且拒绝重定向，读取既有本地凭据但不写日志。5秒请求上限用来观察模型能力，另报告是否在Pi的800ms内返回；只有明确429允许有限重试，服务错误与语义错误分开记录。
- 两轮16样例均获得真实模型响应，服务错误0、重试0、全部小于800ms，模型名为aac6fef/laya-multilingual-mlx；两轮分类和概率完全一致。期望状态分类仅1/16命中（10条unknown、2条running、3条awaitingInput、1条idle）；按现有state≥0.85和needs_reply门槛，16条全部未被产品采用，因此测试runner为0通过/16失败，断言保持原样，未为变绿修改样例或产品。
- 截图句“确认后，我会修改解析逻辑并重新评审。”两轮都为unknown，选中状态概率0.6252，needs_reply=0.1516，modelReplyDecision=undefined。首轮HTTP约30.234ms，第二轮相同分类。此结果证明当前提示/模型/门槛组合在该样例上未提供有效待回复判断，不证明整个Laya模型的普遍准确率，也不单独证明历史截图根因（当前正则兜底本应匹配该句）。
- 证据：`../artifacts/investigate-live-pi-question-state/evidence/laya-answer-types.json`、`laya-answer-types-repeat.json`及对应TAP日志；可重跑 `ITERMATE_LAYA_LIVE=1 ITERMATE_LAYA_REPORT=<报告路径> tsx --test integrations/laya/answer-types.test.ts`。无live环境开关时明确skip、不生成真实模型通过假象。严格tsc noEmit、默认opt-in检查和git diff --check通过；测试/相关生产源码身份见test-snapshot.json。
- 本次只创建测试与任务证据，未更改模型提示、门槛、正则、安装文件或服务配置，未重启任何服务。原T1的进程加载/历史状态因果证据仍缺失，本次仅完成T2的能力验证。

- 真实回答已定位：Pi原生Session `01a0ccf5-d411-70bb-a6bb-bce49667fbf0`，JSONL末条消息 `9b2731f9`，时间 `2026-10-10T02:48:47.697Z`，`stopReason=stop`，完整正文198字符。原始文件为 `/Users/caishilin/.pi/agent/sessions/--Users-caishilin-Documents-SharkSpace-native-short-reader--/2026-09-23T06-30-57-811Z_01a0ccf5-d411-70bb-a6bb-bce49667fbf0.jsonl`。未发现该回答之后的消息。
- iTerm2只读屏幕查询直接匹配该末句及同一Task Target，确认对应终端Session `517EB844-8E2B-44EC-9294-D3BA38151363`，不是仅凭目录/标题推测。外层TTY为`ttys000`，jobPid 20822；进程父子链为20822→20832→25979，Pi位于嵌套TTY `ttys001`。
- 当前源码与已安装扩展SHA-256均为`50e720000da9f06aa04a11fee5a1c9bbe2af57f130d02fd43620010bd022a72d`。对上述完整真实正文提取并执行当前纯`needsReply`函数，返回true；未导入扩展、未向运行会话注入代码、未运行测试套件。当前磁盘规则不会漏掉该完整回答。
- Pi进程25979启动于2026-10-08 14:21:15；安装扩展mtime为2026-10-10 10:38:16。该时间差不证明未执行过reload，也不能给出Pi内存中实际代码哈希。
- 当前`/Users/caishilin/.iTermate/pi-live`没有该Pi进程/原生Session的发现描述；其他进程存在持续更新的描述。这与旧集成未加载新功能相容，但描述发布失败也可能导致缺失，不能单独定案。
- Bridge进程52558启动于2026-10-10 11:11:05，晚于目标回答10:48:47。因此当前快照不能还原截图发生时的接收状态。只读连接Bridge，连续10.42秒观察18份快照，目标Session始终`status=null`、`activityKind=null`、`statusChangedAt=null`、`hasRunningSubagents=false`。当前问题不只是UI把已收到的awaitingInput画错：接收层本身没有该状态。
- 当前集成在agent_end提取最后assistant文本，在agent_settled发布状态；awaitingInput应每2秒续报，能在Bridge重建后重新建立状态。目标目前没有形成这条有效状态链，但现有证据无法区分旧内存集成、生命周期未执行、上报失败或上报到其他接收端。
- 无目标进程的加载版本指纹、历史agent_end/agent_settled事件及上报回执日志；不把“未重新加载”或“上报失败”写成已证实根因。未修改或重启任何运行实例。

## Plan

1. 已完成真实JSONL末条回答、屏幕、终端ID及进程父子链交叉定位。
2. 已完成当前磁盘完整正文分类与Bridge实时快照观察，排除当前正文被当前规则漏判以及当前接收状态正确而纯UI漏画两种解释。
3. 仍需取得目标进程历史或现有只读诊断中的加载版本、生命周期事件与上报回执，才能确定截图时根因；若无此证据，保持未定案，不通过重启或修改观测逻辑绕过只读边界。
4. 本次已完成16样例的真实Laya能力测试及复测，交付失败证据；是否修改模型提示或采用门槛属于后续另行对齐的工作，本次不执行。

## Result

- T2: 真实Laya连续两轮各16样例：服务失败0，全部800ms内；状态命中1/16，符合产品门槛0/16，runner保持16失败。两轮预测完全一致；截图句unknown/0.6252、needs_reply0.1516。测试源码、两份JSON/TAP及test-snapshot.json已保存；未修改产品规则。
- Review gate: Skipped — 当前R1测试文件变更具备有界范围和真实验证，无既有独立审查义务；不将模型失败或T1未定案改为已解决。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 本次仅新增单文件显式启用的本地模型测试与证据，不修改产品；红测是所检验模型表现而非声称修复成功。
- Snapshot: test-snapshot.json sha256:e07843bf59022e11ac59ee2ebb16e8959ca0f3e45571e81bf40f3d7bf387dd23
- Evidence: tsc严格noEmit、默认live关闭检查、两轮实测与预测对比、git diff --check。T1历史因果调查仍未完成，仅T2完成。
- Result clarity: 目标是检验并记录模型能力，不要求修改模型使测试变绿；已明确区分模型分类与应用采用门槛。
- Bounded impact: 仅新增answer-types.test.ts；读取现有回环服务与合成样例，重用产品modelReplyDecision，不改服务或用户会话。
- Low risk: live默认关闭；凭据只发127.0.0.1且禁重定向，不入日志；请求有界，报告写入显式路径，未启动服务。
- Sufficient verification: 两轮16真实响应和所有预测一致；无服务错误，失败按原断言记录；类型检查和opt-in保护通过。
- Task fingerprint: 70cce79de3d08d4b7eab339925201827c1e1c96b07345ee67b1aaac7d969966c
