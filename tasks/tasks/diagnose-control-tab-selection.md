# 排查 Control-Tab 重复选择同一会话

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-28 15:21) |
| Kind | Task |

## Scope

只读排查截图与当前源码，不修改功能、不启动或重启应用，不运行测试。未采集运行中状态，不能确认截图目标实际状态或安装版本。

## Task Summary

未修改代码或组件。

## Plan

1. 对照快捷键入口、Bridge候选排序与Codex完成确认路径解释行为。
2. 当前源码按待回复、完成、空闲、运行排序，超过五秒重置访问记录，同级不按完成时间排序；截图颜色可配置，不能据此确定运行状态。Context快捷键条目与源码存在旧描述冲突，本次只读范围内不更新，以源码为准。

## Target
- [x] T1: 根据截图和当前实现解释重复跳转的原因与证据边界

## Result

- T1: 已读取截图、FinishedSessionShortcut设置说明、ItermBridge快捷键路由和Python activate_next_finished_session；确认5秒重置、awaitingInput优先于finished、同级按终端顺序而非时间、手动idle不进入导航数据。未采集运行时状态，特定会话根因仍为条件性解释；未运行测试。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 只读源码分析，无交付文件变更
- Snapshot: R0源码分析：iTermateBridge.py 417-484及ItermBridge.swift 823-855，未改产品源码
- Evidence: T1源码与设置说明交叉核对
- Task fingerprint: 556b5473a15cfe7d354d6122edd266f1ac694110b93aa78e147352aaf0ea0430

## Verification

- Passed: 重新核对候选排除当前项和visited机制；确认不能把截图颜色或旧Context当作运行状态证据。
