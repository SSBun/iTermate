# 发布 iTermate v0.4.0 到 GitHub 与 Sparkle

Status: Completed (2026-09-10 11:51)
Kind: Task
Parent: release-v0-4-0

## Scope

- 包含：全部当前改动的发布提交、annotated tag、GitHub Release、DMG/checksum 上传、独立下载校验、main/appcast 发布与公开复核。
- 所有远端写操作须在展示精确提交、tag、remote、branch、资产、校验值、签名限制与命令顺序后取得明确确认。
- 不替换已公开稳定资产；任一远端步骤失败时保持 feed 未发布并记录可恢复状态。

## Target
- [x] T1: 当前工作区全部改动进入无敏感内容的发布提交，annotated v0.4.0 tag 指向该提交。
- [x] T2: 经明确安全确认后，v0.4.0 GitHub Release 资产公开可下载且校验一致，随后发布并验证 Sparkle appcast。

## Plan

1. 检查 staged 范围与敏感内容，将全部当前改动提交并创建 annotated `v0.4.0` tag。
2. 展示完整远端动作清单并等待独立安全确认。
3. 先推送 tag，再创建 GitHub Release 并上传已验证资产；独立下载复核后才推送 main。
4. 通过公开 HTTPS 校验 Release、checksum、appcast 与 tag/main 一致性。

## Result

- T1: 全部 15 个当前文件已进入 release commit 8b203de8aa90d5c4076fdcb7855b159e1cd336c4，credential-pattern scan 与 staged diff check 通过；annotated v0.4.0 tag 已创建并指向该提交。
- T2: 用户明确确认后：已推送 v0.4.0 tag；GitHub Release 公开且非 draft/prerelease；远端 DMG/checksum 独立下载、SHA-256、hdiutil 与 HTTP 200 通过；随后推送 main，公开 appcast 为 0.4.0/build 11 且 EdDSA 验证通过。
- Review gate: Skipped — 本任务未修改产品交付文件；仅执行已审查发布提交的本地 Git 与经确认的远端发布动作。

## Verification

- Passed: GitHub Release v0.4.0、两项资产 HTTP 200、远端 SHA-256/hdiutil、tag commit、origin/main、公开 appcast 元数据与 EdDSA 均已复核。
