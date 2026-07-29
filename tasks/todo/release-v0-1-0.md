# 发布 iTermate v0.1.0

Status (2026-07-29 23:36): In Progress

## Scope

- 包含：提交当前工作区全部本地修改，统一 0.1.0 版本元数据，构建并验证本地 macOS DMG，创建本地 `v0.1.0` tag。
- 不包含：GitHub Release、push、notarization 或安装到 `/Applications`；当前仓库未配置 remote，也没有匹配 macOS App 远端发布的 SOP。

## Target

- [ ] T1：当前全部 tracked/untracked 项目改动进入一个可追溯提交，且提交后工作区干净。
- [x] T2：App marketing version 为 0.1.0，build number 单调有效，CHANGELOG 与发布元数据一致且不包含旧名称或错误安装说明。
- [x] T3：完整测试与 Release 构建通过，生成可挂载、校验通过且包含 iTermate.app 的 0.1.0 DMG，并记录 SHA-256 与签名状态。
- [ ] T4：用户确认具体 tag 动作后，本地 `v0.1.0` tag 指向已验证的 release commit。

## Plan

1. 审查全部本地差异、版本源、发布元数据与现有功能任务结果，排除生成缓存和敏感内容。
2. 补齐最小版本记录与可维护 DMG 打包流程，完成测试、Release 构建、DMG 和签名验证。
3. 提交全部项目改动并确认工作区干净。
4. 列出 tag 动作和当前无 remote 的发布边界，取得确认后创建本地 tag。

## Result

- T2：[`project.yml`](../../project.yml) 与生成的 Xcode 工程一致，marketing version 为 `0.1.0`、首发 build number 为 `1`；Release App 的 Info.plist 实测为 `0.1.0 (1)`、bundle ID 为 `com.caishilin.iTermate`。新增 [`CHANGELOG.md`](../../CHANGELOG.md) 记录 0.1.0 用户可见功能与修复；仓库没有 README、installer、appcast 或 remote，非任务/报告源码中未发现旧产品名或旧版本发布引用。
- T3：新增 [`scripts/create-dmg.sh`](../../scripts/create-dmg.sh)，以 Xcode Release build 和原生 `hdiutil` 生成 DMG 与 SHA-256。Bridge self-test/py_compile、Swift parse、`git diff --check` 和全新 Derived Data 的完整 Xcode 测试通过，29/29 测试成功。最终 DMG 可只读挂载，包含 `iTermate.app` 与 `/Applications` 链接，`hdiutil verify`、checksum 与 `codesign --verify --deep --strict` 均通过；产物为 arm64、ad-hoc 签名、未 notarized，SHA-256 为 `08653708502e2b4f4f48536c1e1e9b60cebaec4173e918c92a8006aae4f6ccb7`。
- Review gate: Skipped — no explicit user request.
