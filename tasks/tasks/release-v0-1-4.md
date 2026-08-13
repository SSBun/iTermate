# 发布 iTermate v0.1.4

Status: Completed (2026-08-13 14:07)
Kind: Queue

## Target
- [x] T1: v0.1.4 build 5 的本地发布提交、tag、GitHub Release、DMG 与 Sparkle appcast 相互一致。
- [x] T2: 全部本地改动已安全提交，发布资产通过测试、版本、架构、签名、可读性、checksum 与 EdDSA 验证。
- [x] T3: 经远端确认后，公开 Release 资产先验证成功，再发布 main 中的 appcast，且公开 URL 可用。

## Children

1. [准备 iTermate v0.1.4 本地发布提交与资产](prepare-release-v0-1-4.md)
2. [发布 iTermate v0.1.4 到 GitHub 与 Sparkle](publish-release-v0-1-4.md)

## Result

- T1: v0.1.4 build 5 release commit 1555776、annotated tag、GitHub Release、DMG 与公开 Sparkle appcast 的版本、build、URL、长度和签名一致。
- T2: 全部本地改动进入 release commit；46/46 tests、Release build、DMG 可读性、deep codesign、SHA-256、Sparkle EdDSA 和隔离远端下载验证通过。
- T3: 用户确认后按 tag → 已验证 Release 资产 → main/appcast 顺序发布；公开资产 HTTP 200，公开 appcast 已验证为 v0.1.4。
- Review gate: Skipped — 用户未要求独立或对抗审查。

## Verification

- Passed: 两个子任务均完成；远端 tag/Release/main 指向 release commit，公开 appcast 与远端 DMG metadata、checksum、EdDSA 完全一致。
