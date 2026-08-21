# 发布 iTermate v0.2.0

Status: Completed (2026-08-21 14:30)
Kind: Task

## Scope

- 将现有 Agent idle 状态功能及其 Context/任务记录独立提交，再准备 iTermate `0.2.0` build `7` 发布提交。
- 按项目现有 GitHub Release + Sparkle 流程构建和发布 arm64 DMG；不安装或启动 App。
- 当前机器没有 Developer ID Application 证书，分发产物预计继续使用 ad hoc 签名且不执行 notarization；必须在 tag、push、GitHub Release 或 feed 发布前取得用户对具体资产、命令和该限制的再次确认。

## Target
- [x] T1: 当前所有本地改动按逻辑关注点形成 conventional-style 提交，远端操作前工作区干净
- [x] T2: iTermate 0.2.0 build 7 的版本元数据、更新日志、测试、Release DMG、checksum 与 Sparkle appcast 相互一致并通过本地验证
- [x] T3: 经具体远端动作确认后，annotated v0.2.0 tag、稳定 GitHub Release 资产和公开 Sparkle appcast 指向同一发布提交且完成远端复核

## Plan

1. 验证并独立提交现有 Agent idle 功能、Context 与对应任务记录。
2. 更新 0.2.0 build 7 版本元数据和用户可见更新日志，并同步生成 Xcode 工程。
3. 运行完整测试与 Release 打包，验证最终 DMG、checksum、架构、签名状态和 Sparkle appcast。
4. 创建本地发布提交，列出 tag、remote、资产、checksum、限制和精确远端命令，等待发布确认。
5. 确认后按 tag、已验证 Release 资产、main/appcast 的顺序发布并复核公开结果。

## Result

- T2: 0.2.0 build 7 元数据与更新日志一致；49/49 XCTest、Bridge self-test、arm64 Release build、3,738,559-byte DMG、SHA-256 b72adff7…cee06、deep codesign、hdiutil、Sparkle EdDSA/公钥/XML metadata 均通过；签名为 ad hoc，未 notarized。
- T1: Agent idle 功能与 0.2.0 发布准备分别进入独立 conventional-style 提交；git status --porcelain 在发布提交后无输出。
- T3: 用户确认后按 tag→Release 资产验证→main/appcast 顺序发布；v0.2.0 与稳定 Release 指向发布提交，隔离下载、checksum、hdiutil、EdDSA、HTTP 200 均通过，公开 appcast 为 0.2.0 build 7 且与仓库文件逐字节一致。
- Review gate: Skipped — 用户未要求独立 Reviewer 审批。

## Verification

- Passed: 远端 tag 解引用为发布提交，GitHub Release 非 draft/prerelease，DMG digest b72adff7…cee06，公开资产 HTTP 200，remote main 指向发布提交，公开 appcast SHA-256 2dc612a6…224b 且 XML/EdDSA metadata 通过。
