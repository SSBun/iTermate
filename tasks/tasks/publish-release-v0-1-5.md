# 发布 iTermate v0.1.5 到 GitHub 与 Sparkle

Status: Completed (2026-08-19 14:44)
Kind: Task
Parent: release-v0-1-5

## Target
- [x] T1: 经用户确认后，annotated v0.1.5 tag 和稳定 GitHub Release 指向已验证发布提交
- [x] T2: 远端 DMG 与 checksum 独立下载验证通过，公开资产 URL 返回 HTTP 200
- [x] T3: 仅在资产验证后 push main，公开 appcast 与 v0.1.5 Release 资产完全一致

## Result

- T1: User confirmed full remote list; annotated tag v0.1.5 pushed and stable non-draft GitHub Release created with --verify-tag pointing at release commit 91f14aa
- T2: Isolated gh release download matched SHA-256 083485b9...948e and hdiutil-valid; both public asset URLs returned HTTP 200
- T3: main pushed only after asset verification; public https://ssbun.github.io/iTermate/appcast.xml serves 0.1.5 build 6, 13.0, arm64, correct URL/length/EdDSA; remote main and tag contain release commit
- Review gate: Skipped — User did not request adversarial review

## Verification

- Passed: GitHub API, isolated download, checksum, hdiutil, HTTP 200 and public appcast metadata all verified
