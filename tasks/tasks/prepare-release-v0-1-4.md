# 准备 iTermate v0.1.4 本地发布提交与资产

Status: Completed (2026-08-13 14:00)
Kind: Task
Parent: release-v0-1-4

## Target
- [x] T1: 全部本地源码、测试、任务记录与 v0.1.4 build 5 元数据进入一个无敏感内容的发布提交。
- [x] T2: 完整测试和 Release build 通过，最终 DMG 的版本、build、架构、codesign、可读性与 SHA-256 验证通过。
- [x] T3: Sparkle appcast 使用最终 DMG 生成，EdDSA、公钥、URL、版本、build、长度与最低系统版本一致。

## Result

- T1: Commit 1555776 (release: prepare iTermate 0.1.4) contains all 18 staged source, test, task, changelog, appcast and version files; staged credential-pattern scan found none.
- T2: Xcode test passed 46/46; Release DMG is 0.1.4 build 5 arm64, 3662689 bytes, readable, deep codesign-valid ad hoc, SHA-256 a0146ca14de3be4c54df56ea974cbdd73a98ec88bbeb81ec713230f5a37460d2.
- T3: Sparkle generate_appcast used the final DMG and Keychain account; XML metadata matches build 5, 13.0, arm64, future v0.1.4 URL and byte length; EdDSA verification passed and public key matches the app bundle.
- Review gate: Skipped — 用户未要求独立或对抗审查。

## Verification

- Passed: Bridge self-test、py_compile、Xcode 46/46 tests、Release build、DMG hdiutil/挂载/codesign/SHA-256、Sparkle XML/EdDSA 与 git diff --check 全部通过。
