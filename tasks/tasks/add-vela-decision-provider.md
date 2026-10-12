# 接入 Vela 并支持切换 Laya 与 Vela 决策模型

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-12 11:19) |
| Artifacts | [Artifacts](../artifacts/add-vela-decision-provider/) |
| Kind | Task |

## Target
- [x] T1: 用户可在iTermate设置中选择Laya或Vela作为决策模型，选择持久化并用于后续判定，现有Laya能力继续可用。
- [x] T2: Vela经应用管理的本地运行路径接入，并有可理解的准备、可用及失败反馈；Agent最后回答是否向用户提问沿用已确认语义，不将未达90%的模型表现描述为可靠保证。
- [x] T3: 切换不会让旧模型迟到结果覆盖新选择，模型不可用时遵循明确且可验证的失败处理；不自动覆盖用户安装集成或重启现有App/Pi/服务。
- [ ] T4: 将已接入分类统一修正为“Agent是否需要用户继续参与”，确认请求、选择、补充信息、授权和隐含确认均为正例；单纯完成报告、自主进度、引用或自答为负例，提示词、用例及说明一致。
- [ ] T5: 按修正语义重新标注并实际测试Laya和Vela，运行相关回归测试，报告逐例输出、整体准确率、漏报误报及延迟；区分历史语法问句评估，不覆盖或混用旧结论。

## Scope

原接入阶段已完成源码/构建范围。本次用户明确修正“问题”为需要用户继续参与的回答，并要求调整后重新测试；本轮允许相关回归测试与真实本地模型评估，不启动或重启用户App/Pi/既有模型服务、不覆盖已安装集成、不上传真实会话。修订后的完整实施与重测目标待本次核对。工作树并发修改须保留。

## Decisions

- 复用LocalModelService及现有loopback服务管理，不建立第二套守护进程；默认Laya，持久化provider，Vela使用独立资产与运行时，共享控制目录保持旧客户端位置兼容。
- Vela固定模型revision及代码/权重SHA256；下载只在设置动作触发，启动离线校验并预热；同一App只保留一个所选worker，不自动回退另一模型。
- 保留通用decide与终端session接口，新增question二分类接口；启用模型辅助时Pi采用所选模型问句分类，不再与旧隐含待回复规则OR合并。超时、忙、不可用、非法输出或长消息不推测问句，仅保留明确生命周期；关闭模型辅助时保留旧规则。
- 配置revision、ready许可与端点provider/instance绑定请求和辅助缓存；切换先撤销许可，停止自有旧worker并等待退出再启动新worker，拒绝旧请求结果及缓存。
- 本次T4覆盖先前的语法问句定义；不再把命令请求或隐含确认排除。先前speech-kind及77.5%属于旧语义历史证据，不能当作修正后产品分类效果；不承诺准确率，不把模型推断当安全授权。

## Plan

1. 扩展设置、偏好、分provider安装/启动及生命周期，保护旧Laya安装和API位置。
2. 接入固定Vela模型、问句协议和客户端身份校验，更新文档与回归用例。
3. 完成Debug构建、类型/语法/资源检查；不运行测试或真实UI/服务验收。执行独立只读审查，明确未验证边界。

## 交付与验证边界

- [本任务差异](../artifacts/add-vela-decision-provider/evidence/task-02.diff)与[自检](../artifacts/add-vela-decision-provider/evidence/self-check-02.json)。
- 已补充或调整协议/生命周期回归用例，但未执行；构建、类型检查及静态追踪不能作为真实用户模型切换或视觉验收。

## Result

- T1: LocalModelService中的Picker/setProvider及decisionModelProvider持久偏好接线完成；Laya默认值、旧服务开关及安装位置保留，Vela独立资产目录。Debug build-final.log通过；仅编译与静态数据流核查，未实际点击设置。
- T2: Python helper实现固定revision/hash的Vela CPU FP32适配、离线加载预热与question接口；设置显示模型准备/错误/资源与许可说明，问句语义使用已测speech-kind并披露准确率限制。AST、helper --help、tsc及bundle资源一致性核验通过，未执行安装或真实worker。
- T3: TR-1根因修复：LocalModelExitBarrier保留终止中自有进程，所有run路径共用退出屏障，取消waiter不丢失旧进程。新增停止→切换→启动及取消→重启Swift回归源码，xcodegen仅新增4处测试成员引用；build-for-testing仅编译App/测试成功，未执行测试或启动测试worker。身份校验仍保留，self-check-02及task-02.diff记录证据；用户App/服务/安装集成未操作。
- Review gate: Required — Task reopened; rerun the applicable review after revisions
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 保留R2义务；TR-1退出屏障修复涉及所有子进程启动与取消组合路径，需独立复审。
- Snapshot: tasks/artifacts/add-vela-decision-provider/evidence/snapshot-02.json sha256:307da55d857c5cd841678fc377d16798667c9b71abe14c29f4966149eeecb790
- Evidence: self-check-02.json、task-02.diff、build-for-testing-02.log、typecheck-round02.log；App与回归用例仅编译通过，语法/类型/资源核验通过，未执行测试或启动用户服务。
- Task fingerprint: a949cd57b969e7cc296b399e247d7b532ddfbce06c9bb3927b0ba30be8197472
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [独立审查](../artifacts/add-vela-decision-provider/reviews/round-01.md) | snapshot-01.json sha256:fcf4677873684f2d6d85cc89c9e9f8a89f15849d41752f58a36cca832773a3fe | findings: TR-1；fresh Reviewer run ccd58c7f-960d-41b9-b429-f193b8376a06，34文件哈希一致。 |
| 02 | [独立复审](../artifacts/add-vela-decision-provider/reviews/round-02.md) | snapshot-02.json sha256:307da55d857c5cd841678fc377d16798667c9b71abe14c29f4966149eeecb790 | no blocking findings；TR-1 resolved；fresh Reviewer run 625771b1-8ce4-40db-8777-8654c11c167c；43文件前后及主会话哈希一致。 |
