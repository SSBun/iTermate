# 修复问号转空闲后仍被导航选中及重启恢复问号

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-28 15:32) |
| Kind | Task |

## Plan

1. 修复导航对手动确认状态的读取：当前面板使用 manualIdleStatuses，Pi 导航仍读取 Bridge 原始 awaitingInput；只调整导航优先级，不改通知统计或实际 Agent 生命周期。
2. 用户在截图对应 Pi 会话执行 /reload 后，重新查询只读 status，确认新事件包含稳定 statusChangedAt；随后验证重启恢复。不得自行重启 App、Bridge 或覆盖安装态。
3. 完成源码检查、自检与风险分级，按实际结果执行必要独立审查。

- Current artifacts: 当前仅完成只读诊断，未修改产品源码。
- Next action: 修复导航与展示确认不一致；运行态恢复验证需截图对应 Pi 会话加载新版集成。
- Required input: 用户在目标 Pi 会话执行 /reload；真实 App 重启由用户操作。

## Diagnosis

- 只读 Bridge 快照确认截图对应 Session 的底层状态为 awaitingInput，时间与 UserDefaults 保存的 manualIdleStatuses 完全一致，说明空闲确认已落盘，而不是写入失败。
- ItermStore.activateNextFinishedSession 仅传递 Codex 覆盖，Pi 导航继续使用 Bridge session_statuses；markSessionIdle 只更新 Swift 展示覆盖。因此 Pi 手动空闲不影响导航优先级。
- 对目标 Pi 私有端点进行认证只读 status 查询，响应包含 awaitingInput、reporterId、sequence 和 latestCompletion，但没有 statusChangedAt。仓库与已安装集成文件都有该字段，说明目标进程仍持有旧版集成。Bridge 重建后的时间兜底可使手动确认身份失配；尚未主动重启复现。
- 未运行测试、未重启任何进程、未覆盖安装态；未声称已修复。Context 现有 Pack 已记录上述展示/生命周期分离与旧集成恢复边界，不新增重复事实。

## Target

- [ ] T1: 问号状态标为空闲后不再因旧的待处理状态被Control-Tab反复选中
- [ ] T2: 无新活动时重启应用保持已确认的空闲状态
