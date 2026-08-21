# 发布 iTermate v0.2.1

Status: Completed (2026-08-21 17:20)
Kind: Task

## Scope

- 以当前 `main` 尚未发布的提交为基础，准备并公开 iTermate `0.2.1`（build `8`）DMG、checksum、GitHub Release 与 Sparkle appcast。
- 不安装或启动 App，不加入无关功能；远端 tag、Release、资产和 feed 仅在本地验证完成并通过具体发布确认门后执行。

## Target
- [x] T1: iTermate 0.2.1 的版本元数据、更新日志、Release 构建、DMG、checksum 与 Sparkle appcast 相互一致并通过验证。
- [x] T2: v0.2.1 tag 与公开 GitHub Release 指向正确发布提交，并提供经验证的 DMG 与 checksum。
- [x] T3: 公开 Sparkle appcast 以 0.2.1 为最新版本，下载 URL、版本、build、系统与架构要求及签名均匹配发布资产。

## Plan

1. 核验工作区、版本来源、远端、认证、签名、公证、Sparkle 密钥与待发布功能验收状态。
2. 更新 0.2.1（build 8）版本元数据和更新日志，并从规范来源同步 Xcode 工程。
3. 在不启动 App 的前提下完成所需测试授权、Release 构建、DMG、checksum、代码签名与 Sparkle appcast 验证。
4. 展示具体远端发布清单并取得确认。
5. 按 tag、GitHub Release 资产验证、默认分支/feed 的顺序发布并复核公开状态。

## Local Preparation

- `project.yml` 与生成的 Xcode 工程均为版本 `0.2.1`、build `8`，CHANGELOG 与首条 appcast item 一致。
- 50/50 XCTest、Bridge self-test、Release 构建、DMG checksum、`hdiutil verify`、深度代码签名检查、XML 解析、Sparkle EdDSA 签名验证和 `git diff --check` 均通过。
- 待发布 DMG 大小为 `3,748,924` bytes，SHA-256 为 `4ea5acff3d4351ca60234b81f32442c49784539ae07243166e9591cd20f01c91`。
- 未安装或启动 App；产物为 arm64、ad hoc 签名且未经过 Apple notarization。

## Decisions

- 用户明确授权本次运行完整 Xcode 项目测试，并确认 Focused Section Opacity 已完成真实 App 验收。
- 用户接受 `0.2.1` arm64 产物继续使用 ad hoc 签名且未经过 Apple notarization。

## Result

- T1: project.yml、生成的 Xcode 工程、CHANGELOG、Release App、DMG 与 appcast 均为 0.2.1/build 8；50/50 XCTest、Bridge self-test、checksum、hdiutil、codesign、XML 与 EdDSA 验证通过。
- T2: 远端 annotated tag v0.2.1 与稳定 GitHub Release 均指向发布提交 cd666c5；独立下载的 DMG/checksum 匹配 SHA-256 4ea5acff3d4351ca60234b81f32442c49784539ae07243166e9591cd20f01c91，资产 HTTP 200。
- T3: 无缓存获取的公开 Sparkle feed 首项为 0.2.1/build 8、macOS 13.0、arm64，URL/长度匹配远端 DMG，EdDSA 签名与下载资产验证通过。
- Review gate: Skipped — 用户未要求独立 Reviewer、对抗审查或双 Agent 审批。

## Verification

- Passed: GitHub Release 为 stable、non-draft、non-prerelease 且 latest；远端资产、tag、main 与公开 appcast 均按发布 SOP 完成独立复核。
