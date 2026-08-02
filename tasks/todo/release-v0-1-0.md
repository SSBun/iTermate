# 发布 iTermate v0.1.0

Status: In Progress (2026-08-02 09:45)

## Scope

- 包含：完成 Sparkle 2 基线集成后提交全部修改，统一 0.1.0 版本元数据，构建并验证 macOS DMG，将 `main`、`v0.1.0` 与 GitHub Release 发布到公开仓库 `SSBun/iTermate`。
- 包含：发布可供 0.1.0 客户端访问的 GitHub Pages HTTPS 基线 appcast。
- 不包含：Developer ID、notarization、安装到 `/Applications` 或 0.1.0 → 0.1.1 双版本升级验收；用户选择先完成开发验证。

## Target

- [x] T1：包括 Sparkle 集成在内的全部本地项目改动进入可追溯提交，发布前工作区干净。
- [x] T2：App marketing version 为 0.1.0、build number 为 1，CHANGELOG 与 Sparkle/发布元数据一致。
- [x] T3：完整测试与 Release 构建通过，最终 0.1.0 DMG 包含 Sparkle、可挂载且校验通过，并记录 SHA-256 与开发签名限制。
- [ ] T4：用户确认完整远端动作后，远端 `main`、`v0.1.0` tag 与稳定 GitHub Release 指向同一已验证提交，Release asset 可公开下载。
- [ ] T5：GitHub Pages 的 HTTPS appcast 可公开访问，0.1.0 基线 App 的标准更新检查能够读取它。

## Plan

1. 等待用户确认 tag、push、GitHub Release 与 appcast 的完整远端动作。
2. 让远端 `main`、`v0.1.0`、Release asset 与公开 HTTPS appcast 指向同一已验证发布。

## Result

- T1：Session 生命周期与标题刷新修复及当时全部本地改动已提交为 `6292e0e`（`fix: refresh sessions after iTerm restart`）；记录发布证据前，`git status --short --branch --untracked-files=all` 无本地改动。
- T2：`xcodebuild -showBuildSettings` 与挂载后 App 的 `Info.plist` 均确认 marketing version `0.1.0`、build number `1`、bundle ID `com.caishilin.iTermate`；`CHANGELOG.md` 已包含 0.1.0，Sparkle feed 配置指向公开 HTTPS 基线 appcast。
- T3：Xcode 全量测试 35/35 通过；`scripts/create-dmg.sh 0.1.0` 完成 Release 构建，DMG 可只读挂载，包含 Sparkle、Applications 链接及与源码一致的 Bridge/Pi/Codex 资源；`hdiutil verify`、checksum 和深度 `codesign --verify` 均通过。SHA-256 为 `7f7eef6b9b2b26c3401068c21bec4fd2dc64ea4a32ee11284bc18e931625737e`。当前签名为 ad hoc（`Signature=adhoc`、无 Team ID），未执行 Developer ID 签名或 notarization。
- Review gate: Skipped — no explicit user request.
