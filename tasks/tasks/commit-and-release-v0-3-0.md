# 提交当前改动并发布 iTermate v0.3.0

Status: In Progress (2026-08-26 11:05)
Kind: Queue

## Scope

- 包含当前工作区全部产品、文档、版本元数据与任务记录改动，并发布 iTermate v0.3.0。
- Ghostty 状态问题必须先由真实 App 运行结果验证；Agent 不启动或重启 iTermate、Bridge 或用户终端。
- 远端 tag、GitHub Release、资产和 appcast 仅在本地发布产物验证完成并取得具体操作确认后变更。

## Target

- [ ] T1: Ghostty 状态问题经真实运行验证后，全部本地改动形成可追溯提交，iTermate v0.3.0 的 tag、GitHub Release、资产与 Sparkle appcast 一致且公开可用。

## Children

1. [实现 Ghostty 实时 Session 状态](investigate-ghostty-realtime-status.md)
2. [提交 iTermate v0.3.0 全部本地改动](commit-v0-3-0-local-changes.md)
3. [发布 iTermate v0.3.0](release-v0-3-0.md)

## Plan

1. 完成 Ghostty 实时状态子任务及用户运行时验收。
2. 状态修复验收通过后，提交全部本地改动并清空工作区待提交状态。
3. 提交完成后恢复 v0.3.0 发布子任务，完成本地发布准备、具体远端确认与公开复核。
