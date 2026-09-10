# 准备 iTermate v0.4.0 本地发布版本与资产

Status: Completed (2026-09-10 11:31)
Kind: Task
Parent: release-v0-4-0

## Scope

- 包含：版本/build、CHANGELOG、XcodeGen 派生工程、Release DMG/checksum、Sparkle 签名 appcast 与本地校验。
- 不运行测试套件，不启动 App，不覆盖 `/Applications` 或用户安装态。
- 产物沿用现有 arm64 ad hoc 签名且未公证；该限制必须在发布清单与 release notes 中明确。

## Target
- [x] T1: 项目版本更新为 0.4.0、build 11，CHANGELOG 与生成工程准确反映本次发布。
- [x] T2: 最终 arm64 Release DMG、SHA-256 与 Sparkle appcast 在本地生成，并通过版本、架构、签名、镜像、长度和 EdDSA 一致性验证。

## Plan

1. 更新 0.4.0/build 11 与用户可见发布说明，并重新生成 Xcode 工程。
2. 通过现有发布入口生成最终 Release DMG 与 checksum。
3. 检查版本、架构、资源、签名、镜像及校验值，并使用 Keychain 中的 Sparkle EdDSA key 生成和验证 appcast。
4. 完成静态检查与强制 task-review 闭环。

## Result

- T1: project.yml 与重新生成的 project.pbxproj 已升为 0.4.0/build 11；Release App Info.plist 实测同值，CHANGELOG 与中英文 README 已记录终端独立面板开关。
- T2: 最终 arm64 DMG 为 dist/iTermate-0.4.0_20260910-111638/iTermate-0.4.0.dmg，3928253 bytes，SHA-256 14d65e8e4bc174cc7bdb2f5f8030bc5161b8e747b182b71518ff9802100d1191；Release build、hdiutil、只读挂载、deep codesign、XML、EdDSA 与 Keychain 公钥一致性均通过。
- Review gate: Passed — 独立 reviewer 完成只读审查：Findings none；未运行测试/UI smoke check 为非阻塞限制，ad hoc 且未公证已准确披露。

## Verification

- Passed: 审查后复验：DMG hdiutil VALID、Sparkle EdDSA signature verified、appcast XML 有效、git diff --check 通过；未运行测试或启动 App。
