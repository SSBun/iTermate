# 点击状态图标将会话标为空闲

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 20:31) |
| Artifacts | [Artifacts](../artifacts/click-status-icon-to-idle/) |
| Kind | Task |

## Scope

仅修改面板会话状态的手动展示确认，不停止终端或 Agent，不改变真实生命周期、完成通知与统计来源，不安装或重启当前 App/Bridge。

## Plan

1. 将手动空闲入口限定为 finished 与 awaitingInput，运行中及其他状态不允许清除；保留原有布局、像素动画及会话激活和关闭行为。
2. 手动覆盖仍只绑定当前观察身份；不改变真实生命周期与通知统计。
3. 使用隔离构建目录执行 Debug 构建和静态检查，不执行测试、不启动或重启 App；完成独立只读审查并披露真实点击验证限制。

并发边界：`default-reply-separate-agent-unknown` 任务同时修改 Agent 身份名称、环境图标、nil 状态展示及 Context 的相关说明，这些不归属本任务。本任务只提取既有图标渲染，并修改点击动作与观察覆盖。首轮审查无发现，但返回后 Context 中并发说明变化使整文件快照失效，已保留报告并重建当前范围审查。

## Task Summary

**会话面板与状态 Store**：["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 将状态图标拆为独立按钮，新增绑定当前观察身份的内存空闲覆盖；重复观察保留，生命周期变化释放。通知与归档继续读取未受手动覆盖的观察数据，保留现有图标渲染、激活及关闭入口。本轮修正仅允许 finished、awaitingInput 点击清除，并在 Store 按最新观察复核；其他状态禁用按钮并调整提示及辅助功能标签。

**项目上下文**：["/Users/caishilin/Desktop/personal/iTermate/tasks/context.md"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/context.md) 补充手动展示与生命周期消费方的边界，以及仅 finished、awaitingInput 允许手动空闲的状态限制。

## Target
- [x] T1: 仅在 finished 或 awaitingInput 状态下，点击状态图标才将会话显示为空闲。
- [x] T2: 状态图标保留现有像素绘制与动画，其他会话及原有行操作不受影响。
- [x] T3: running、idle、interrupted 及未知状态的图标不能触发手动空闲，真实终端或 Agent 状态不受点击影响。

## Result

- T1: 本轮源码核对：sessionButton仅在finished/awaitingInput启用，markSessionIdle再次读取合并后的当前观察并仅允许这两种状态；保持手动内存覆盖。隔离Debug构建成功，日志../artifacts/click-status-icon-to-idle/evidence/restrict-status-build.log；未实际点击或运行测试。
- T2: 本轮前后diff核对：仅调整Store状态白名单、按钮disabled/help/accessibility，未改sessionStatusIcon或Canvas/动画、标题激活与关闭动作。publishWindows仍分离lifecycleWindows与windows。两文件swiftc -parse、git diff --check及Context validate通过；Context保留原有未索引历史段落警告。真实视觉未运行。
- T3: 源码穷举枚举边界：running/idle/interrupted/nil均不满足UI与Store的finished或awaitingInput条件；Store在写manualIdleStatuses之前返回，可抵御展示与当前观察之间的状态变化。点击路径无Bridge生命周期写入或停止操作；无测试执行、无App/Bridge启动或重启。
- Review gate: Passed — fresh只读Reviewer dc59a179-4ff3-41b7-aea7-85e4b5eacc88未发现问题；round-03已保存核对。主Agent check-evidence再次验证当前快照及三份报告，补足Reviewer无法哈希的限制。真实UI未运行仍明确披露。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 继承同一任务既有Required独立审查义务；本轮收紧展示覆盖入口，核对按钮与Store当前观察校验及生命周期消费者。
- Snapshot: snapshot:tasks/artifacts/click-status-icon-to-idle/evidence/d46b62eb130c327126d87a477dfdbec2f478a924f13e890f5d378422a08c4081.json#d46b62eb130c327126d87a477dfdbec2f478a924f13e890f5d378422a08c4081
- Evidence: 当前Result T1/T2/T3；restrict-status-build.log构建成功，两Swift解析、diff --check及Context validate通过。未运行测试/真实UI，未重启现有进程。
- Task fingerprint: cb4ef84f30d0e7d3956175e9d7bdc458f5014fdb2f002415fbe68e23dc839366
## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/click-status-icon-to-idle/reviews/round-01.md) | snapshot:tasks/artifacts/click-status-icon-to-idle/evidence/fb80d29dfc444def8f388efecdfa40aa9d6fe0f4cdea8bb21228249a1ecebe3e.json#fb80d29dfc444def8f388efecdfa40aa9d6fe0f4cdea8bb21228249a1ecebe3e | invalidated by drift | 9418854945c9c46ee1c5258c28431ac62e6aed1cca93550d320a58d92d44ba58 |
| 02 | [Round 02](../artifacts/click-status-icon-to-idle/reviews/round-02.md) | snapshot:tasks/artifacts/click-status-icon-to-idle/evidence/e7efafec003c0d6c62b5825806a2098a4bf4584641f755958c60110ae7607b4c.json#e7efafec003c0d6c62b5825806a2098a4bf4584641f755958c60110ae7607b4c | no blocking findings | e57369c3b2eb133aaa4cbb6eb9d5bc513e11aff231d6fa080abc6c0f0f7a969b |
| 03 | [Round 03](../artifacts/click-status-icon-to-idle/reviews/round-03.md) | snapshot:tasks/artifacts/click-status-icon-to-idle/evidence/d46b62eb130c327126d87a477dfdbec2f478a924f13e890f5d378422a08c4081.json#d46b62eb130c327126d87a477dfdbec2f478a924f13e890f5d378422a08c4081 | no blocking findings | 5e0ddaf5812596f7d6dc9cdf1d79aa3993e2949e7e6fd2e17dbca2155c24a0cc |

## Verification

- Passed: 审查后最终复查：两Swift文件再次parse成功，git diff --check通过，check-evidence确认当前快照及三报告一致；隔离Debug构建日志与源码快照未变。无测试和真实点击验证，无App/Bridge启动重启。
