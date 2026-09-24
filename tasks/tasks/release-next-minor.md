# 发布下一个 minor 版本

| Field | Value |
| --- | --- |
| Status | In Progress (2026-09-24 15:30) |
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
- 本地准备完成，等待具体远端发布清单确认；尚未进行远端发布。

## Target

- [ ] T1: iTermate 发布下一个 minor 稳定版本，版本、构建号和更新说明一致，并包含当前已提交功能。
- [ ] T2: GitHub Release 安装包与校验值可公开下载，Sparkle 更新源指向已验证的同一版本。
