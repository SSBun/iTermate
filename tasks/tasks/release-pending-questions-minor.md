# 升级 minor 版本并公开发布待回复提醒功能

Status: Completed (2026-09-17 16:03)
Kind: Task

## Target
- [x] T1: 将 iTermate 升级至下一个 minor 版本，同步版本信息与更新说明，包含已提交的待回复提醒功能。
- [x] T2: 按项目既有发布渠道公开发布新版本，验证发布产物及更新入口可用并汇报发布链接。

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
- 用户明确回复 confirm publish 后按安全顺序完成远端发布；未运行测试。

## Publication

- release commit 33e4e87868e739fd425ed6b5b1aa0b35778c47cb；annotated v0.5.0、GitHub Release及初次main推送一致。
- https://github.com/SSBun/iTermate/releases/tag/v0.5.0 为公开稳定Release；两个资产独立下载、HTTP200、checksum、字节比较及hdiutil通过。
- https://ssbun.github.io/iTermate/appcast.xml 已公开0.5.0/build12；Pages run 35197434874成功，公开元数据和EdDSA对独立下载DMG验证通过。
- 最终证据：../artifacts/release-pending-questions-minor/evidence/published-release.txt。签名/未公证/未测试/未实测客户端升级限制保留，未覆盖旧版资产。
- 后续仅提交并推送任务完成记录，不修改release tag、DMG、checksum或feed内容。

## Result

- T1: project.yml、生成工程、CHANGELOG/appcast均为0.5.0/build12；Release build、DMG只读挂载、版本/arm64/资源/deep codesign/校验和/EdDSA通过。ad hoc未公证，测试未执行，详见local-release.txt。
- T2: 用户明确确认后完成tag→Release资产→独立下载校验→main/feed发布；Release非draft/prerelease、两资产HTTP200且SHA256/字节/hdiutil一致；公开appcast为0.5.0/build12，EdDSA验证下载DMG通过，tag/main发布提交一致。见published-release.txt。
- Review gate: Skipped — R1常规发布元数据与已知管线，无新增产品逻辑；版本、归档、签名、远端下载和公开feed已确定性核验。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 常规minor版本元数据更新与既有发布流程，没有修改产品逻辑、更新密钥或签名策略；所有版本和资产关联可确定核验。
- Snapshot: release commit 33e4e87868e739fd425ed6b5b1aa0b35778c47cb; tag v0.5.0; DMG sha256:5bf1d471a3545fcd40647a29a6d299cbf345e5e256082cd90f8a434d3446da0f; public feed build12
- Evidence: local-release.txt及published-release.txt；Release构建、镜像、deep codesign、Keychain公钥一致、EdDSA、远端独立下载、HTTP及公开feed检查全部通过；测试未运行。
- Result clarity: 明确0.4.0/build11→0.5.0/build12，公开版本已可下载，用户明确接受签名限制。
- Bounded impact: 仅版本/更新说明/生成工程/appcast，既有产品实现不变；沿用固定发布管线和同一公钥。
- Low risk: 不修改安全校验或密钥，不覆盖历史资产；新版本独立tag和资产，公开前用户确认并在feed前校验远端字节。
- Sufficient verification: 构建产物、独立下载和公开feed逐项确定性一致，架构/版本/校验/签名/HTTP已观察；不声称未授权测试或客户端升级实测。
- Task fingerprint: 7449082815e7fbae7d687f62ff4eb4d3c33d8432f833b4e9dfec55009986ba03

## Verification

- Passed: 公开稳定Release、tag提交33e4e87、main包含发布提交、两资产HTTP200；独立下载SHA256及公开appcast EdDSA验证通过，feed0.5.0/build12已生效。ad hoc未公证，测试与客户端升级未实测。
