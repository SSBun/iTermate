# 发布 iTermate v0.1.1

Status: Completed (2026-08-03 14:23)

## Scope

- 包含：提交当前全部本地修改，将 marketing version 更新为 0.1.1、build number 更新为 2，生成并验证 DMG，创建 `v0.1.1` tag 与公开 GitHub Release，并在 Release 资产验证后发布 Sparkle appcast。
- 不包含：Developer ID 签名、Apple notarization 或 Mac App Store 发布；当前机器没有 Developer ID Application identity，既有发布基线也明确采用 ad hoc 开发签名。

## Target

- [x] T1：当前全部本地修改与 0.1.1 版本元数据进入一个经验证且无敏感文件的发布提交。
- [x] T2：App、CHANGELOG、Xcode 工程、DMG 与 Sparkle appcast 的版本为 0.1.1，build number 为 2。
- [x] T3：完整测试、Release 构建、DMG 挂载、SHA-256、Sparkle EdDSA 签名与 codesign 检查通过，并明确记录 ad hoc、未 notarized 限制。
- [x] T4：经用户确认远端动作后，`v0.1.1` 与公开 GitHub Release 指向同一发布提交，`origin/main` 包含该提交，DMG 和 checksum 可公开下载。
- [x] T5：GitHub Pages appcast 在 Release 资产验证后发布，公开 feed 的版本、build、URL、长度与 EdDSA 签名和最终 DMG 一致。

## Result

- T1：提交前检查 9 个 staged 文件并扫描敏感新增内容，未发现 credential/private key；全部本地项目修改与版本元数据已提交为 `61320f1`（`fix: stabilize working status icon`）。
- T2：[`project.yml`](../../project.yml) 作为版本权威源更新为 marketing version 0.1.1、build 2，并由 XcodeGen 同步生成工程；`xcodebuild -showBuildSettings`、Release App、挂载后的 DMG App、CHANGELOG 与 appcast 均确认 0.1.1 (2)。
- T3：完整 Xcode 测试 35/35 通过；`scripts/create-dmg.sh 0.1.1` 完成 arm64 Release 构建，DMG 为 [`iTermate-0.1.1.dmg`](../../dist/iTermate-0.1.1_20260803-141539/iTermate-0.1.1.dmg)，大小 3,655,524 bytes，SHA-256 为 `6b7d0f6d2277df5a5da1846768d039769b3b08b74e65a0f8d1a824b5a8a69e5a`。`hdiutil verify`、只读挂载、Sparkle 与 integration 资源哈希、深度 codesign 均通过；签名为 ad hoc、无 Team ID，未 notarized。Sparkle Keychain account `SSBun.iTermate` 的公钥与 App 中 `SUPublicEDKey` 一致，`generate_appcast` 已生成 build 2 item，EdDSA 归档签名验证与 XML metadata 检查通过。
- T4：annotated tag `v0.1.1` 与稳定公开 GitHub Release 均指向 `61320f1`；远端 DMG 和 checksum 返回 HTTP 200。隔离目录重新下载的 DMG 大小为 3,655,524 bytes，`shasum -c`、SHA-256 与 `hdiutil verify` 均通过；Release 非 draft、非 prerelease，URL 为 `https://github.com/SSBun/iTermate/releases/tag/v0.1.1`。
- T5：Release 资产验证完成后才 push `main`；GitHub Pages build 在 `61320f1` 上成功，公开 `https://ssbun.github.io/iTermate/appcast.xml` 与仓库文件 SHA-256 同为 `aeffda13a42f817c6a608b7e16e0e57187e00300e3ea62193c5358f0adc1ac75`。公开 feed 的 0.1.1、build 2、arm64、macOS 13、下载 URL、3,655,524 bytes 长度均正确，远端 DMG 的 EdDSA 签名复核通过。
- Review gate: Skipped — no explicit user request.
