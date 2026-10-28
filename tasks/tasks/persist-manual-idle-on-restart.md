# 修复手动空闲状态在重启后丢失

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-28 11:37) |
| Artifacts | [Artifacts](../artifacts/persist-manual-idle-on-restart/) |
| Kind | Task |

## Scope

修复 finished/awaitingInput 手动展示确认的重启恢复，不更改真实生命周期、通知统计或像素图标。保留原有未提交改动；不运行测试、不启动或重启 App/Bridge、不改用户安装目录。

## Plan

1. 持久化绑定状态事件与终端身份的手动确认，区分启动/断连暂缺与真实新活动。
2. 为 Pi 推送及只读恢复提供由集成持有的稳定状态时间，避免 Bridge 重建时间戳使确认失效；旧集成缺少稳定时间时保持保守匹配。
3. 补充回归用例但不执行，完成隔离 Debug 构建、语法及静态核对，进行独立只读审查。

## Task Summary

**Swift 状态 Store**：["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 将手动空闲确认按完整状态与终端身份持久化；连接暂缺与 Agent 监控未恢复时保留但不强行应用，确认新事件或移除会话时保存释放结果。Codex 进程身份支持编码，匹配原始观察而非焦点确认后的展示；Pi 只读恢复透传稳定事件时间并校验输入。

**iTerm2 Bridge**：["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge) 校验并使用集成提供的状态时间，保留旧集成的时间兜底与完成时间语义。

**Pi 集成**：["/Users/caishilin/Desktop/personal/iTermate/integrations/pi"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi) 为推送与只读查询提供按状态及 turn 身份更新的稳定事件时间，增加心跳与新轮次回归用例。

**Swift 回归用例**：["/Users/caishilin/Desktop/personal/iTermate/iTermateTests"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests) 增加 Store 重建、启动暂缺、新活动、移除会话与 Codex 进程替换的隔离偏好用例。

**项目上下文**：["/Users/caishilin/Desktop/personal/iTermate/tasks/context.md"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/context.md) 更新手动展示持久化、状态暂缺与 Pi 稳定时间来源的边界。

## Target
- [x] T1: 点击状态图标置为空闲后，重启 iTermate 仍保持该空闲状态，不因重启本身恢复为活跃
- [x] T2: 会话产生新的真实活动后，仍可按原有规则更新状态

## Result

- T1: 源码逐路径核对：markSessionIdle立即编码完整身份到独立UserDefaults键，init恢复；stop不清除，连接未就绪不裁剪，Agent/监控暂缺不套用不删除，同事件精确匹配显示idle。Pi statusChangedAt贯通推送与readonly→Swift→Bridge，避免重建时间。Debug build与build-for-testing仅编译成功，日志见evidence/build.log和compile-tests.log；未执行测试或真实App重启。Pi awaitingInput须更新集成并reload；旧集成无稳定时间时仍保守释放，不保证跨Bridge恢复。
- T2: 源码对照store-change.diff和other-changes.diff：身份不等及权威快照会话移除均保存释放，running仍不能手动清除；Codex含进程启动时间/thread/turn，Pi状态或turn变化更新时间；lifecycleWindows仍发布原始观察，统计/通知未改。新增4个Swift及1个Pi回归用例仅编译/语法检查；Swift parse、Python AST、TS transform语法与node --check、diff --check通过，未执行测试。当前App与Bridge PID保持85010/88373，未修改安装态。
- Review gate: Passed — fresh只读Reviewer eb068771-3771-4ad4-8511-3044241a03b6无确认问题及源码Target阻断风险，round-01已保存核对。主Agent审查前后check-evidence验证15项冻结内容与报告一致，补足Reviewer无法哈希的限制；未执行运行验收。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨Swift持久化、Pi事件时间、Bridge重建与异步状态恢复，包含暂缺证据与真实新事件的区分，需要独立审查。
- Snapshot: snapshot:tasks/artifacts/persist-manual-idle-on-restart/evidence/9be50c6c541dc8089624101eeec4ef7a15b4e6917ec0060457b1179f63e6950f.json#9be50c6c541dc8089624101eeec4ef7a15b4e6917ec0060457b1179f63e6950f
- Evidence: Result T1/T2及evidence/store-change.diff、other-changes.diff；Debug构建与测试bundle编译通过，无测试执行及真实重启，旧Pi集成限制已记录。
- Task fingerprint: 1c16b366534dfd72e5282a52aef05fc8e2738ceeafe07c6b683591962fe6de62

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/persist-manual-idle-on-restart/reviews/round-01.md) | snapshot:tasks/artifacts/persist-manual-idle-on-restart/evidence/9be50c6c541dc8089624101eeec4ef7a15b4e6917ec0060457b1179f63e6950f.json#9be50c6c541dc8089624101eeec4ef7a15b4e6917ec0060457b1179f63e6950f | no blocking findings | 78b751a4718b7b81c1ccb44ca132ca9d2cfaea5f96b6b3d17c593efeea721917 |

## Verification

- Passed: 审查后最终复查：Swift parse、Python AST、TS transform语法、node --check与diff --check再次通过；check-evidence验证15项快照和round-01报告一致，含Debug构建及仅编译测试日志；App/Bridge仍为85010/88373。源码交付已验证，无测试执行、真实点击或重启验收，无安装态更改；Pi等待恢复需更新集成并reload。
