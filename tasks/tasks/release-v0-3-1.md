# 发布 iTermate v0.3.1 修复版本

Status: In Progress (2026-08-27 14:36)
Kind: Task

## Target

- [x] T1: 版本升至 0.3.1（build 10），更新 changelog 并由 project.yml 重新生成工程，完成 Release 构建、DMG 打包、签名与 Sparkle appcast 本地验证。
- [ ] T2: 经用户确认远端操作清单后，按顺序推送 tag、创建已验证资产的 GitHub Release 并发布 appcast。

## Scope

- 遵循 `github-release-sparkle-macos` SOP；按会话规则未运行测试套件（用户未授权）。
- 不启动或重启 iTermate、Bridge 或用户终端。
- 远端 tag、Release、资产与 appcast 的变更须在本地准备完成后再次取得具体操作确认。

## Plan

1. 更新版本、构建号与 CHANGELOG，重新生成派生工程。
2. 通过既有打包脚本构建 Release DMG 并验证版本、架构、签名与 Sparkle 依赖。
3. 使用 Keychain 中的 EdDSA 私钥为最终 DMG 生成签名并写入 appcast。
4. 创建发布提交与 annotated tag，展示全部远端变更及其顺序并等待明确确认。
5. 按安全顺序发布 tag、Release 资产和 appcast，再从公开 HTTPS 独立复核。

## Progress

- project.yml 已升至 0.3.1/build 10，xcodegen 重新生成工程；CHANGELOG 新增 0.3.1 段。
- Release DMG 构建通过：`dist/iTermate-0.3.1_20260827-143845/iTermate-0.3.1.dmg`，3,924,394 bytes，SHA-256 `c46499315ddd89d0259df38ca64da693a5512299895e95d47da0aebcf0a1427b`，hdiutil verify VALID。
- 内置 App 验证：0.3.1/build 10、arm64、deep codesign OK、Sparkle 2.9.4 嵌入；沿用既有 ad hoc 签名且未公证限制。
- Sparkle `sign_update --account SSBun.iTermate` 签名生成并通过 `--verify`；`docs/appcast.xml` 已加入 0.3.1/build 10 条目，xmllint 通过。

## Result

- （待远端发布后填写）

## Verification

- （待远端发布后填写）
