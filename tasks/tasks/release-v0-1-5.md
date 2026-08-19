# 发布 iTermate v0.1.5

Status: Completed (2026-08-19 14:44)
Kind: Queue

## Target
- [x] T1: v0.1.5 build 6 的本地发布提交、tag、GitHub Release、DMG 与 Sparkle appcast 相互一致
- [x] T2: 全部本地改动已安全提交，发布资产通过测试、版本、架构、签名、可读性、checksum 与 EdDSA 验证
- [x] T3: 经远端确认后，公开 Release 资产先验证成功，再发布 main 中的 appcast，且公开 URL 可用

## Children

1. [准备 iTermate v0.1.5 本地发布提交与资产](prepare-release-v0-1-5.md)
2. [发布 iTermate v0.1.5 到 GitHub 与 Sparkle](publish-release-v0-1-5.md)

## Result

- T1: v0.1.5 build 6 release commit 91f14aa, tag, GitHub Release, DMG and public appcast all consistent
- T2: 47/47 tests, Release build, DMG readability, deep codesign, SHA-256, EdDSA and isolated remote download verified; all local changes committed
- T3: Published in order tag -> verified Release assets -> main/appcast after user confirmation; public assets HTTP 200, appcast verified as 0.1.5
- Review gate: Skipped — User did not request adversarial review

## Verification

- Passed: Both children completed; remote tag/Release/main point at release commit, public appcast matches remote DMG metadata
