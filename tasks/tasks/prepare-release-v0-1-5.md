# 准备 iTermate v0.1.5 本地发布提交与资产

Status: Completed (2026-08-19 14:37)
Kind: Task
Parent: release-v0-1-5

## Target
- [x] T1: 全部本地源码、测试、任务记录与 v0.1.5 build 6 元数据进入一个无敏感内容的发布提交
- [x] T2: 完整测试和 Release build 通过，最终 DMG 的版本、build、架构、codesign、可读性与 SHA-256 验证通过
- [x] T3: Sparkle appcast 使用最终 DMG 生成，EdDSA、公钥、URL、版本、build、长度与最低系统版本一致

## Result

- T1: Commit 91f14aa contains version bump, changelog, appcast, regenerated xcodeproj and task records; staged credential-pattern scan found none
- T2: Xcode tests 47/47 passed; Release DMG is 0.1.5 build 6 arm64, 3672457 bytes, hdiutil-readable, deep codesign-valid ad hoc, SHA-256 083485b9bdeb503646c9979a08d3881d6377ed21dcbec63fc6de70803c1c948e
- T3: generate_appcast signed final DMG with Keychain EdDSA key; XML metadata matches build 6, 13.0, arm64, v0.1.5 URL and length 3672457; openssl Ed25519 signature verified and derived public key equals SUPublicEDKey
- Review gate: Skipped — User did not request adversarial review

## Verification

- Passed: Tests, Release build, DMG checks, appcast XML/EdDSA and credential scan all passed
