# 发布下一个 minor 版本

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-24 15:40) |
| Artifacts | [Artifacts](../artifacts/release-next-minor/) |
| Kind | Task |

## Decisions

- 当前版本 0.5.0/build 12，下一个 minor 为 0.6.0/build 13；版本权威为 project.yml，生成工程同步。
- 沿用 github-release-sparkle-macos 与现有 DMG 脚本，目标为公开仓库 SSBun/iTermate，origin/main，Sparkle feed 为 https://ssbun.github.io/iTermate/appcast.xml。
- 用户已授权相关测试，并长期接受 ad hoc 签名、未经 Apple 公证；该限制已写入项目规则，不再重复询问。具体远端发布仍单独确认。
- 不安装新 App 或覆盖已安装 Pi 集成，不重启用户正在运行的 App/Bridge。XCTest 使用独立构建目录；App 已有 XCTestConfigurationFilePath 启动保护，不进入实际服务启动链。
- 本轮规则变更及其任务记录由用户明确要求，随发布提交归档。

## Plan

1. 同步版本、构建号、更新说明与工程；执行已授权测试。
2. 使用既有脚本生成最终 DMG，核验归档、版本、架构、签名、校验和与资源。
3. 使用既有 Keychain 密钥生成并验证 appcast；完成本地自检，创建发布提交与 annotated tag。
4. 展示具体资产/校验值/提交/远端动作后等待发布确认。
5. 先推 tag，再创建 Release 并下载验证资产，最后推送 main/feed 并核验公开结果。

## Preparation

- 已将 project.yml 更新为 0.6.0/build 13，并运行 xcodegen generate 同步工程；CHANGELOG 与 release-notes.md 已准备。
- 2026-09-24 执行 python3 iTermateBridge/iTermateBridge.py --self-test 失败：check_finished_navigation 第 1592 行的 `assert activated[-1] == "2"` 未通过，涉及空闲 Agent 的循环切换场景。
- 用户授权修复后确认是测试场景缺少第二个 idle Agent；补全 fixture，保留原断言并增加激活次数/状态保持断言，不改产品逻辑。
- Bridge 自检、Pi 7 项、子代理 10 项及 XCTest 57 项均通过；Release 构建、DMG 只读挂载、deep codesign、SHA256、Sparkle EdDSA 和 appcast 元数据验证通过，详见 ../artifacts/release-next-minor/evidence/local-release.md。
- DMG 4087624 bytes，SHA256 2a13723699dd30b7e4ae6bf690fcf45198d9b7634b2145570a425342e1979f47；ad hoc/未公证限制如实保留。
- 用户确认完整远端操作清单后，发布提交 e63bf40bfa040c7861ff7a6c9f61d59f75b60a70 的 annotated v0.6.0、GitHub Release 及 main/feed 已按顺序公开。
- 独立下载两资产均 HTTP 200，checksum、字节比较、hdiutil 通过；Pages run 35970681110 成功，公开 appcast 0.6.0/build13 与本地一致，下载 DMG 的公开 EdDSA 验签通过。详见 ../artifacts/release-next-minor/evidence/published-release.md。
- 后续仅提交推送发布完成记录，不改变发布 tag、安装包或 feed 字节。

## Target
- [x] T1: iTermate 发布下一个 minor 稳定版本，版本、构建号和更新说明一致，并包含当前已提交功能。
- [x] T2: GitHub Release 安装包与校验值可公开下载，Sparkle 更新源指向已验证的同一版本。

## Result

- T1: 0.6.0/build13 的 project.yml、生成工程、CHANGELOG、DMG、tag 与 feed 一致；Bridge 自检、Pi 7 项、子代理 10 项、XCTest 57 项、Release 构建通过；只读挂载资源核对、deep codesign、SHA256 与 EdDSA 验证通过。测试 fixture 修复未改变产品逻辑。详见 local-release.md。
- T2: Release v0.6.0 非 draft/prerelease，两资产 HTTP200，独立下载 checksum/字节/hdiutil 验证通过；Pages run 35970681110 成功，公开 feed 0.6.0/build13 与本地一致，EdDSA 验证下载 DMG 通过；tag/main 发布提交 e63bf40 一致。详见 published-release.md。
- Review gate: Skipped — R1 常规发布及局部测试数据修复，完整确定性资产与公开状态证据，无独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 既有发布流程中的版本/说明/feed 更新及局部测试 fixture 修正，无产品逻辑、签名策略或密钥变更。
- Snapshot: git:e63bf40bfa040c7861ff7a6c9f61d59f75b60a70; tag:v0.6.0; DMG sha256:2a13723699dd30b7e4ae6bf690fcf45198d9b7634b2145570a425342e1979f47; public feed build13
- Evidence: local-release.md 与 published-release.md：74 项测试及 Bridge 自检、Release 构建、包/签名/资源/远端下载/公开 feed 均验证通过。
- Result clarity: 明确 minor 0.5.0/12→0.6.0/13，公开新功能版本；已接受签名限制及具体远端操作。
- Bounded impact: 仅常规版本发布文件和缺失测试数据补全，原产品实现和旧 feed 项不变。
- Low risk: 固定已验证发布管线，独立新 tag/资产，不覆盖旧版本或修改密钥；先验证公开资产后发布 feed。
- Sufficient verification: 74 项测试及自检、签名/校验和/版本/资源/远端逐字节核对与公开 EdDSA 通过；未声称真实客户端升级或 Apple 公证。
- Task fingerprint: 621cac4333266074462f8a60c2f2fb8fdb74689b0246b9a08fbfae7e92a700b6

## Verification

- Passed: 最终重新无缓存获取公开 appcast，与本地逐字节一致；发布源码/配置/规则与 e63bf40 无差异，独立下载校验和再次通过。tag/Release/main 的发布身份一致；ad hoc 未公证、真实升级未实测限制已披露。
