# 发布 iTermate v0.1.0

Status: In Progress (2026-08-02 09:30)

## Scope

- 包含：完成 Sparkle 2 基线集成后提交全部修改，统一 0.1.0 版本元数据，构建并验证 macOS DMG，将 `main`、`v0.1.0` 与 GitHub Release 发布到公开仓库 `SSBun/iTermate`。
- 包含：发布可供 0.1.0 客户端访问的 GitHub Pages HTTPS 基线 appcast。
- 不包含：Developer ID、notarization、安装到 `/Applications` 或 0.1.0 → 0.1.1 双版本升级验收；用户选择先完成开发验证。

## Target

- [ ] T1：包括 Sparkle 集成在内的全部本地项目改动进入可追溯提交，发布前工作区干净。
- [ ] T2：App marketing version 为 0.1.0、build number 为 1，CHANGELOG 与 Sparkle/发布元数据一致。
- [ ] T3：完整测试与 Release 构建通过，最终 0.1.0 DMG 包含 Sparkle、可挂载且校验通过，并记录 SHA-256 与开发签名限制。
- [ ] T4：用户确认完整远端动作后，远端 `main`、`v0.1.0` tag 与稳定 GitHub Release 指向同一已验证提交，Release asset 可公开下载。
- [ ] T5：GitHub Pages 的 HTTPS appcast 可公开访问，0.1.0 基线 App 的标准更新检查能够读取它。

## Plan

1. 提交已完成任务的全部本地修改并确认工作区干净。
2. 从发布提交重建最终 0.1.0 DMG，复核版本、framework、Info.plist、签名、checksum 与 appcast。
3. 列出 tag、push、Release 与 asset 远端动作，取得确认后执行并验证公开下载。
