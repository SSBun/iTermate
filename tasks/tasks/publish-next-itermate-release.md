# 推送当前代码并发布 iTermate 新版本

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-22 17:08) |
| Artifacts | [Artifacts](../artifacts/publish-next-itermate-release/) |
| Kind | Task |

## Scope

发布当前已提交代码为 minor 版本 0.7.0（build 14），沿用 SSBun/iTermate 的 main、GitHub Releases 与 docs GitHub Pages Sparkle 更新源。仅更新版本、发布说明和更新源，不修复或关闭其他未完成任务。保留 Codex 无身份信号时无法自动关联的已知限制，不擅改用户配置。沿用用户已接受的 ad hoc 签名、未经 Apple 公证限制；不运行单元测试或项目测试套件，不安装或启动／重启 iTermate。

## Plan

1. 核对已发布 0.6.0/build13 与本地、远程版本，确认项目专用 Keychain 公钥、打包脚本、GitHub 仓库和 Pages 来源。
2. 更新 0.7.0/build14 元数据、中文更新说明并重新生成 Xcode 工程；使用既有脚本生成 Release DMG，验证签名、嵌套资源、架构、镜像和校验和。
3. 为最终字节生成 Sparkle appcast，核对 EdDSA、公钥、版本、长度、URL；只读独立检查发布材料。
4. 公告具体动作后创建发布提交与 annotated tag；先推tag并创建稳定Release，独立下载核验资产后才推main发布feed。
5. 核验公开feed及远端提交一致性，执行必要独立复审，保存完成记录。若公开资产或feed不一致，停止下游发布并记录恢复条件。

## Task Summary

**版本元数据**：以 ["/Users/caishilin/Desktop/personal/iTermate/project.yml"](file:///Users/caishilin/Desktop/personal/iTermate/project.yml) 为规范源，将版本更新为 0.7.0、build 14，并同步生成 ["/Users/caishilin/Desktop/personal/iTermate/iTermate.xcodeproj/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate.xcodeproj/) 的构建设置。

**更新日志**：在 ["/Users/caishilin/Desktop/personal/iTermate/CHANGELOG.md"](file:///Users/caishilin/Desktop/personal/iTermate/CHANGELOG.md) 整理本次 minor 版本的功能、移除项、升级要求与未验证限制。

**Sparkle 发布材料**：在 ["/Users/caishilin/Desktop/personal/iTermate/docs/"](file:///Users/caishilin/Desktop/personal/iTermate/docs/) 的 appcast 中由官方工具新增 0.7.0/build14 项，绑定最终 DMG 的长度、EdDSA 签名与下载 URL，保留全部历史发布项。

## Target

- [ ] T1: 当前代码以0.7.0/build14生成新版本安装包，版本记录、发布说明与Git标签一致。
- [ ] T2: 代码与标签发布到SSBun/iTermate，稳定GitHub Release的安装包及校验和可下载且核验一致。
- [ ] T3: 对应Sparkle更新源仅在远程安装包验证成功后发布，公开更新源与最终安装包的版本、长度和签名一致。
