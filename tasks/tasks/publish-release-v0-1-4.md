# 发布 iTermate v0.1.4 到 GitHub 与 Sparkle

Status: Completed (2026-08-13 14:07)
Kind: Task
Parent: release-v0-1-4

## Target
- [x] T1: 经用户确认后，annotated v0.1.4 tag 和稳定 GitHub Release 指向已验证发布提交。
- [x] T2: 远端 DMG 与 checksum 独立下载验证通过，公开资产 URL 返回 HTTP 200。
- [x] T3: 仅在资产验证后 push main，公开 appcast 与 v0.1.4 Release 资产完全一致。

## Result

- T1: 用户在完整远端清单后确认；annotated tag v0.1.4 与稳定 GitHub Release 均指向 release commit 155577681ea63ff6ee8cd3d14bf89329e2babff5。
- T2: 从 GitHub Release 隔离下载 DMG 与 checksum；资产大小 3662689 bytes、SHA-256 a0146ca14de3be4c54df56ea974cbdd73a98ec88bbeb81ec713230f5a37460d2、shasum、hdiutil、Sparkle EdDSA 均通过，两个公开资产 URL 返回 HTTP 200。
- T3: 远端资产验证后才 push main；公开 https://ssbun.github.io/iTermate/appcast.xml 已返回 v0.1.4 build 5、13.0、arm64、正确 URL/长度/EdDSA，remote main 与 tag 均包含 release commit。
- Review gate: Skipped — 用户未要求独立或对抗审查。

## Verification

- Passed: GitHub API、隔离下载、checksum、hdiutil、EdDSA、HTTP 200、公开 appcast XML metadata、remote main/tag commit 一致性全部验证通过。
