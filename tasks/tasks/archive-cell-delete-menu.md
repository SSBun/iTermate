# 为 Archive 条目增加右键删除菜单

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 11:42) |
| Kind | Task |

## Scope

仅修改主面板 Archive 行的删除入口及归档存储动作，保留其他区域交互和现有未提交改动；不操作真实用户归档、不启动或重启 App、不运行测试。

## Plan

1. 添加归档行右键菜单与确认提示，取消不改变数据。
2. 通过现有归档状态拥有者校验目标后移至废纸篓，刷新列表并展示失败原因；不影响原始会话和恢复副本。
3. 完成 Debug 构建、源码边界检查及风险分级，记录无法代替人工交互验证的限制。

## Target
- [x] T1: Archive 区域的条目提供右键删除菜单，执行后对应归档条目被删除。

## Result

- T1: 源码逐项检查：Archive 每行原生 contextMenu 调用 confirmDeleteArchive，Cancel 默认且仅第二按钮启动删除；共享 isBusy 在菜单、确认与 MainActor 存储入口阻止冲突；UUID 校验后固定 archiveRoot 路径，复用 readManifest 拒绝符号链接并核对完整记录，只调用系统 trashItem，无永久删除或原始/恢复副本写入，defer 刷新 records，错误由既有面板展示。macOS 13 Debug xcodebuild build 成功（/tmp/itermate-archive-delete-build.log），swiftc -parse 与 git diff --check 通过；未运行测试、未启动 App、未操作用户归档，真实菜单/确认窗口及废纸篓交互未现场验证。
- Review gate: Skipped — R1 四项具体依据已记录；局部可恢复操作的源码路径和 Debug 构建已验证，无独立评审请求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 局部原生菜单到系统废纸篓的单一操作，沿用现有确认、状态、路径验证和错误展示，无永久删除。
- Snapshot: iTermate/PiSessionArchives.swift(untracked) sha256:9842477c96f99210e5b830ff102efcb88bf6bccc1947843ef99fe3457d8f1197; iTermate/iTermateApp.swift(unstaged) sha256:712367d54ec01a04da082a9460472d66ae4139f4aa37224ba08dc9879bcf31b5; 本任务增量仅 delete 方法、Archive 行 contextMenu、confirmDeleteArchive，其他现有变更不属于本任务。
- Evidence: T1 Result；/tmp/itermate-archive-delete-build.log BUILD SUCCEEDED；swiftc -parse、git diff --check、Context validate 通过。
- Result clarity: 用户已确认 Archive 行右键删除；确认后从归档列表移除，取消不变，其他区域未改动。
- Bounded impact: 直接调用链仅行菜单→确认→PiSessionArchives.delete；共享 busy 防止恢复/归档冲突，defer 刷新与既有 error 展示覆盖结束路径。
- Low risk: 系统废纸篓可恢复；默认取消；固定根目录下 UUID 子目录、既有非符号链接检查及当前完整 manifest 比较限制目标；不改变权限/协议，不修改原始会话、恢复副本或工作目录。
- Sufficient verification: 完整 Debug 编译链接成功；逐分支检查取消、忙碌、无效身份、过期元数据、系统失败与成功刷新；Swift 解析和 diff 检查通过。按用户约束未运行测试或启动 App，真实 UI 交互仍需用户自行运行检查。
- Task fingerprint: 9b89f09e1098033640048dd7559a856a4abfa5ab9ce5db3b857bc2a92e118ecd

## Verification

- Passed: 最终两个源码 SHA256 与 assessment 一致；再次 git diff --check、swiftc -parse 通过，当前内容已有 Debug BUILD SUCCEEDED。未运行测试及真实 App 交互，不主动启动/重启进程或删除真实归档。
