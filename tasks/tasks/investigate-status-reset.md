# 调查手动重置后状态不刷新根因

| Field | Value |
| --- | --- |
| Status | Blocked (2026-11-13 10:26) |
| Kind | Task |

## Target

- [ ] T1: 查明问号重置与状态停止刷新之间的代码因果链，并说明证据与限制

## Plan

1. 已核对问号点击、手动覆盖、Pi 上报、Bridge 接收和自动恢复链路。
2. 需取得故障发生时的原始状态事件，确认是否遗漏 running、事件身份未变，或 Pi 本身停止正确上报。

## Execution Log

### 001 — 核对手动覆盖与本机版本

问号按钮先调用 markSessionIdle 再 activate。markSessionIdle 仅存储当前 SessionStatusIdentity 并重新发布视图；publishWindows 仍保留原始 lifecycleWindows。applyingManualIdleStatuses 在身份变化时删除覆盖，因此点击本身不会停止 Pi 推送。实际安装的 ~/.pi/agent/extensions/iTermate-integration.ts 缺少仓库已有的 statusChangedAt；agent_settled 的旧分类路径也仍可生成 null。Bridge set_session_status 对相同 status 保留旧时间。因此若下一轮 running 未送达，随后 awaitingInput 会被视为同一事件，手动 idle 覆盖可持续。这是已确认的条件性缺陷路径，尚无本次故障的历史事件证明前提发生。

### 002 — 只读核对当前运行状态

连接本机 bridge.sock 仅接收快照；native-short-reader 两个会话分别上报 awaitingInput 与 running。defaults export 读取当前 manualIdleStatuses 为 {}，目前没有残留覆盖。恢复扫描读取 iTermWindows 原始状态，仅补未知状态，不会主动纠正仍有 awaitingInput/idle 的已知状态。重启前事件未留存在本次证据中，无法将条件性缺陷确定为本次唯一根因。没有重置会话、更新集成或运行测试；产品源码未修改。

## Task Summary

本次未修改代码或产品组件。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | S | 只读追踪现有调用与状态身份，没有增加实现。 | 无已知额外复杂度。 |
| 稳定性 | A | 区分代码可确认的条件性缺陷和本次事故归因；当前快照与偏好均只读检查。 | 未主动复现，不将推测当作事故事实。 |
| 完整性 | B | 已定位旧集成缺失事件时间和相同状态覆盖不释放的链路。 | 缺少故障前事件，不能确认本次 running 是否丢失，或 Pi 实际上报是否停滞。 |

## Block

- Reason: 缺少重启前的状态事件，无法证明本次事故是否满足条件性缺陷的触发前提。
- Unblock when: 获得再次发生时同一会话的原始 Bridge 状态、manualIdleStatuses 及 Pi 上报序列，或获准进行受控复现并取得对应事件证据。
