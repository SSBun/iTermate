# 集成 Sparkle 2 自动更新

Status (2026-07-30 00:58): In Progress

## Scope

- 包含：通过 Swift Package Manager 集成稳定版 Sparkle 2，配置 EdDSA 公钥与 HTTPS appcast，提供标准手动检查更新入口，并构建可作为 0.1.0 基线版本的 App/DMG。
- 包含：为公开仓库 `SSBun/iTermate` 准备 GitHub Pages appcast 与 GitHub Releases 更新资产路径。
- 不包含：Developer ID、notarization 或生产签名；用户选择先完成本机开发验证。
- 不包含：从版本 A 实际升级到版本 B 的生产级双版本验收；该步骤需要后续发布至少 0.1.1。

## Target

- [x] T1：Sparkle 2.9.4 通过 SPM 固定解析并只链接到 macOS App target，Release App 内嵌 Sparkle framework。
- [x] T2：App 包含 HTTPS `SUFeedURL` 与 Keychain 私钥对应的 `SUPublicEDKey`，仓库、命令日志和构建产物不包含 EdDSA 私钥。
- [x] T3：App 启动时创建长生命周期的标准 updater，About 设置页提供可用的手动检查更新入口，不实现自定义下载或安装逻辑。
- [ ] T4：仓库包含可由 GitHub Pages 发布的合法基线 appcast；在尚无更新时检查更新不会报 XML、ATS 或签名配置错误。
- [x] T5：Swift parse、项目测试、Release 构建、DMG、版本/build、Sparkle framework、Info.plist、SHA-256 与代码签名检查通过，并明确记录开发签名与未 notarized 限制。

## Plan

1. 添加并固定 Sparkle SPM 依赖，生成 EdDSA 密钥并只保存公钥。
2. 接入标准 updater、About 检查入口、Info.plist 配置和基线 appcast。
3. 运行测试、Release/DMG 静态检查与本机手动检查更新验证。
4. 在远端动作确认后推送公开仓库、启用 Pages，并验证 appcast HTTPS 地址。

## Result

- T1：[`project.yml`](../../project.yml) 以 exact version `2.9.4` 声明 Sparkle SPM package，生成并提交的 `Package.resolved` 固定 revision `b6496a74a087257ef5e6da1c5b29a447a60f5bd7`。Release App 内嵌 Sparkle 2.9.4、Updater、Autoupdate、Installer.xpc 与 Downloader.xpc，主二进制链接 `@rpath/Sparkle.framework/Versions/B/Sparkle`。
- T2：Sparkle `generate_keys --account SSBun.iTermate` 将新 EdDSA 私钥保存在登录 Keychain，仅将公钥写入 App Info.plist；`generate_keys -p` 输出与 bundle `SUPublicEDKey` 一致。`SUFeedURL` 为 `https://ssbun.github.io/iTermate/appcast.xml`，未添加 ATS 例外；未导出私钥文件，pending diff 的密钥/凭据扫描只包含可公开公钥。
- T3：AppDelegate 持有 `SPUStandardUpdaterController(startingUpdater: false)`，通过 XCTest 启动 guard 后在正常 App 启动阶段调用 `startUpdater()`；About 设置页的 `Check for Updates…` 仅调用标准 controller。运行 Release App 后截图确认按钮与 `Version 0.1.0 (1)` 正确显示。
- T5：`xmllint`、Swift parse、`git diff --check` 与全新 Derived Data 的完整 Xcode 测试通过，31/31 测试成功。0.1.0 DMG 可只读挂载并包含 `/Applications` 链接；Info.plist 为 `0.1.0 (1)`、Sparkle 2.9.4、HTTPS feed 与匹配公钥，`hdiutil verify`、SHA-256、Sparkle XPC 完整性和 `codesign --verify --deep --strict` 均通过。DMG SHA-256 为 `dbed7fbca3676e55a91c30032ac9089f6070ecf314cf5f551792eebbffc60076`；App 为 arm64 ad-hoc 开发签名且未 notarized，未宣称生产分发完成。
- Review gate: Skipped — no explicit user request.
