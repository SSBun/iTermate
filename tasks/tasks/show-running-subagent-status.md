# 增加子代理运行中的 Session 状态图标

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-24 14:25) |
| Artifacts | [Artifacts](../artifacts/show-running-subagent-status/) |
| Kind | Task |

## Scope

仅增加 Pi 子代理运行状态的采集、传输和 Session 图标；保留明确待回复提示及现有完成统计语义。不覆盖用户已安装集成，不启动或重启 App/Bridge。用户已授权仅对子代理生命周期与 RPC 恢复执行隔离测试，不启动真实子代理。

## Plan

1. 通过 pi-subagents 公开的当前会话 Fleet RPC 观察活跃工作，处理完成、恢复、不可用与退出。
2. 使用现有运行状态及心跳传输独立子代理标识，在两种终端快照中保留该标识并展示专用图标。
3. 检查语法、构建及状态转换边界，记录无法执行的真实界面验证，完成独立只读审查。

## Target
- [x] T1: Session 存在仍在运行的子代理时显示专用状态图标，包括主 Agent 已结束当前回复的情况。
- [x] T2: 子代理全部结束后移除该运行标识，恢复与 Session 实际状态一致的显示。

## Result

- T1: snapshot-02.json 六个文件绑定实现及隔离测试；node --experimental-vm-modules --test integrations/pi/subagent-lifecycle.test.mjs 的 10 项测试通过，包括主回复结束后继续运行、零计数恢复、待回复并列、启动恢复、Ghostty TTY、非 TUI 隔离。Debug build 与打包集成 cmp 通过；真实界面未运行验证。
- T2: TR-1 在恢复出的原被审版本 fd8b7f33a5b664c9e076a185472e063ff581d119d4d16652c710264c9afba8c4 上确定性失败（14100 != 16700）；修复后同场景通过，后续 12 秒仍续报。10 项隔离测试还覆盖过期无伪完成、恢复、非法响应及退出清理。证据为 evidence/tr1-before.log、lifecycle-after.log；严格 tsc、Swift/Python 语法与 diff 检查通过。
- Review gate: Passed — 独立只读 round-02.md，run 5d95afd2-ea39-4bfc-bc2c-926cc04a7e98：无阻断发现，TR-1 resolved；主会话复核六文件和测试日志哈希完全一致。保留真实 UI/接收端运行链未观察的非阻断限制。
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/show-running-subagent-status/reviews/round-01.md) | sha256:9e6ef22b2bd03dfd7f817106b6447c372ccf0e0e7afbcd25a591bd4933862953 | findings: TR-1；独立运行 0c904e99-413c-4f68-9576-1275797376ee；主会话复核五文件哈希全部一致 |
| 02 | [Round 02](../artifacts/show-running-subagent-status/reviews/round-02.md) | sha256:857916a7c3975bcfddc6902597054b115985349b3e57fc92aca2f6eff46a65fb | no blocking findings；TR-1 resolved；独立运行 5d95afd2-ea39-4bfc-bc2c-926cc04a7e98；主会话复核六文件及测试证据哈希一致 |

## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨语言状态及异步租约恢复；保持原有独立审查义务。
- Snapshot: sha256:857916a7c3975bcfddc6902597054b115985349b3e57fc92aca2f6eff46a65fb; tasks/artifacts/show-running-subagent-status/evidence/snapshot-02.json
- Evidence: T1/T2 Result、10 项隔离测试通过、旧版 TR-1 红灯、修复绿灯；/tmp/itermate-subagent-build-02.log BUILD SUCCEEDED。
- Task fingerprint: a603e9993df599c25ec4c5e4d12375d621eeeb634c4698a83c3e1e6a5a16835f

## Verification

- Passed: 审查通过后重新执行 10 项隔离生命周期测试全部通过（/tmp/itermate-lifecycle-final.log），严格 tsc、git diff --check、Context validate 通过；六文件与审查快照一致。未启动真实子代理或 App，未覆盖用户安装态；实际 UI/接收端端到端运行仍需用户自行重新构建运行后观察。
