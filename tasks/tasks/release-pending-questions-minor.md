# 升级 minor 版本并公开发布待回复提醒功能

Status: In Progress (2026-09-17 15:43)
Kind: Task

## Target
- [x] T1: 将 iTermate 升级至下一个 minor 版本，同步版本信息与更新说明，包含已提交的待回复提醒功能。
- [ ] T2: 按项目既有发布渠道公开发布新版本，验证发布产物及更新入口可用并汇报发布链接。

## Decisions

- 版本权威为 project.yml；当前 0.4.0/build 11，目标 0.5.0/build 12，重新生成 Xcode 工程同步。
- 使用既有 github-release-sparkle-macos 发布流程及 create-dmg.sh；遵守本次不运行测试的明确边界，改做 Release build、包和签名验证，不声称测试通过。
- 已查询公共仓库 SSBun/iTermate，origin HTTPS，默认 main；远端 main 仍为 0c79ef6，最新公开 Release 是 v0.4.0，v0.5.0 tag 尚不存在。
- 无 Developer ID Application 身份；拟沿用 ad hoc/未公证的 arm64 发布方式，公开前必须获用户对该限制及完整动作清单的明确接受。不上传 Apple notary service、不轮换 Sparkle 密钥。
- 不替换或重启本机 App、Bridge 或 Pi 集成。运行 App 位于独立 Xcode Debug 产物，既有 Release 打包目录不覆盖它。

## Plan

1. 同步版本、更新日志和生成工程；用既有脚本构建并验证最终 DMG、checksum、签名及 Sparkle 资源。
2. 使用既有 Keychain EdDSA 密钥生成 appcast，保留既有发布项并验证版本、架构、长度、签名与未来资产 URL。
3. 自检发布范围和资产身份；按实际风险完成必要独立审查，创建发布提交及 annotated tag。
4. 展示完整远端动作/资产/校验/签名限制，等待单独安全确认。
5. 先推 tag，创建 Release 并上传 DMG/checksum；独立下载验证通过后才推 main/feed，最后检查公共 appcast 与资产一致性。

## Preparation

- 0.5.0/build12 已同步，Release构建、DMG校验、只读挂载、deep codesign、包内资源一致性通过。
- 最终DMG为3963748 bytes，SHA256为5bf1d471a3545fcd40647a29a6d299cbf345e5e256082cd90f8a434d3446da0f，路径见 ../artifacts/release-pending-questions-minor/evidence/local-release.txt。
- appcast由项目既有Keychain account SSBun.iTermate签署，公钥匹配、EdDSA验签、版本/架构/长度/URL校验通过；旧item保持不变。
- 详细本地证据：../artifacts/release-pending-questions-minor/evidence/local-release.txt；公开说明：../artifacts/release-pending-questions-minor/reports/release-notes.md。
- 仍未执行远端写操作，等待用户接受ad hoc/未公证限制与完整公开清单；未运行测试。

## Result

- T1: project.yml、生成工程、CHANGELOG/appcast均为0.5.0/build12；Release build、DMG只读挂载、版本/arm64/资源/deep codesign/校验和/EdDSA通过。ad hoc未公证，测试未执行，详见local-release.txt。
