# 移除 Archive 与 Delete Archive 操作的确认弹窗

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 14:30) |
| Kind | Task |

## Target
- [x] T1: 点击 Archive Pi Session 菜单项直接执行归档，不再显示确认弹窗。
- [x] T2: 点击 Delete Archive 菜单项直接将归档移至废纸篓，不再显示确认弹窗。

## Result

- T1: 与修改前副本逐行 diff：Archive Pi Session 直接调用原 store.archivePiSession，删除 confirmArchive 与 NSAlert，菜单 canArchive 禁用条件未变；ItermBridge 与 PiSessionArchives SHA256 前后一致，执行前校验和失败提示未变；Debug BUILD SUCCEEDED，未启动 App、未运行测试。
- T2: 与修改前副本逐行 diff：Delete Archive 直接 Task await archives.delete，删除 confirmDeleteArchive 与 NSAlert，保留 destructive role、busy 禁用与底层 MainActor busy/身份校验/废纸篓/错误提示；swiftc -parse、git diff --check、Context validate 通过；未操作真实归档、未进行运行时 UI 检查。
- Review gate: Skipped — R1 四项依据已记录；用户要求的确认层移除已通过精确 diff 与完整构建检查，无独立评审要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 按用户明确要求移除两个交互确认层，直接调用原有动作，不改动底层安全校验或存储行为。
- Snapshot: iTermate/iTermateApp.swift unstaged sha256:5b59ef0897f183e82458e091ae4f94d3db99f5fd3d752dbc25c401963b61b6ce; docs/pi-session-archives.md untracked sha256:a534050cfac4ff4b60cbd6ec91ade9cd54b0ee608416468d40d2777390866db4; 本任务仅两个菜单直连、移除两个确认 helper、修正文档对应步骤。
- Evidence: T1/T2 Result；/tmp/itermate-remove-confirmations-build.log BUILD SUCCEEDED；修改前后 diff 仅预期三个源码位置。
- Result clarity: 用户确认两个菜单直接执行、不再弹窗，数据校验和错误提示保留。
- Bounded impact: 仅 UI 调用点和文档变更；store 与 archives 文件哈希前后一致，菜单禁用规则保持原样。
- Low risk: 用户明确取消二次确认；仍需主动点击菜单，归档原有身份/空闲/保存后关闭检查不变，删除仍使用可恢复的废纸篓，不涉及永久删除或权限调整。
- Sufficient verification: 精确前后 diff、底层哈希对比、完整 Debug 构建、Swift 解析、diff 格式和 Context 校验通过；未运行测试或启动 App，未声称完成真实 UI 检查。
- Task fingerprint: ca5439f325dcef7bf5a020e2766c0802c6a52843250c9d4f03059d3c7a4540bb

## Verification

- Passed: 当前源码及文档哈希与 assessment 一致，rg 未发现两个确认 helper 或弹窗文案；Debug 构建、swiftc -parse、git diff --check、Context validate 通过；底层动作哈希未变，未运行测试和运行时 UI。
