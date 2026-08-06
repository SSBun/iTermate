# 发布 iTermate v0.1.2

Status: Completed (2026-08-06 11:03)

## Scope

- 包含：提交当前全部本地修改，将 marketing version 更新为 0.1.2、build number 更新为 3，生成并验证 DMG，创建 `v0.1.2` tag 与公开 GitHub Release，并在 Release 资产验证后发布 Sparkle appcast。
- 不包含：Developer ID 签名、Apple notarization 或 Mac App Store 发布；当前机器没有 Developer ID Application identity 或 notarytool profile，远端发布前必须由用户明确接受 ad hoc、未 notarized 限制。

## Target

- [x] T1：当前全部本地修改与 0.1.2 版本元数据进入一个经验证且无敏感文件的发布提交。
- [x] T2：App、CHANGELOG、Xcode 工程、DMG 与 Sparkle appcast 的版本为 0.1.2，build number 为 3。
- [x] T3：完整测试、Release 构建、DMG 挂载、SHA-256、Sparkle EdDSA 签名与 codesign 检查通过，并明确记录 ad hoc、未 notarized 限制。
- [x] T4：经用户确认完整远端动作后，`v0.1.2` 与公开 GitHub Release 指向同一发布提交，`origin/main` 包含该提交，DMG 和 checksum 可公开下载。
- [x] T5：GitHub Pages appcast 在 Release 资产验证后发布，公开 feed 的版本、build、URL、长度与 EdDSA 签名和最终 DMG 一致。

## Plan

1. 更新版本、CHANGELOG 和生成工程，运行测试并构建、签名与验证最终 DMG/appcast。
2. 检查 staged diff 与敏感文件后创建单一发布提交，并列出完整远端动作确认门。
3. 用户确认后按 tag → Release 资产验证 → main/appcast 的顺序发布并复核公开结果。

## Evidence

- `xcodebuild ... build test`：35 tests，0 failures，`TEST SUCCEEDED`。
- `scripts/create-dmg.sh 0.1.2`：Release arm64 构建与 `hdiutil verify` 通过；最终 DMG 为 3,660,249 bytes，SHA-256 为 `c29a6f3ac760982e9188ba97f8f69750325e340370ab4e046e4ea370ec033df0`。
- App 与挂载后的 DMG 内容均为 0.1.2（build 3），Bridge、Pi 与 Codex 内嵌资源哈希和源码一致，Sparkle framework 完整。
- `codesign --verify --deep --strict` 与 Sparkle EdDSA 签名验证通过；Release 配置关闭 Xcode base entitlement 注入，因此没有 `get-task-allow`。
- 分发限制：应用仍为 ad hoc 签名（无 Team ID），未经过 Apple notarization。
- 用户确认后已创建并推送 `v0.1.2`，公开 GitHub Release 指向提交 `e2fecf30e973212f26d85d5421b9e09c434e79b1`；远端 DMG 与 checksum 下载后逐字节匹配本地产物，SHA-256 与 Sparkle EdDSA 签名验证通过。
- GitHub Pages 部署成功；公开 appcast 返回 0.1.2（build 3）、macOS 13.0、arm64、3,660,249 bytes 与最终 Release URL，公开下载资产的 SHA-256 再次验证通过。
