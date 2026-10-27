# 推送当前代码并发布 iTermate 新版本

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 14:50) |
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
- [x] T1: 当前代码以0.7.0/build14生成新版本安装包，版本记录、发布说明与Git标签一致。
- [x] T2: 代码与标签发布到SSBun/iTermate，稳定GitHub Release的安装包及校验和可下载且核验一致。
- [x] T3: 对应Sparkle更新源仅在远程安装包验证成功后发布，公开更新源与最终安装包的版本、长度和签名一致。

## Result

- T1: v0.7.0 annotated tag指向8a737da4db542024bbd36adbdf9813c14b7d9996；project.yml及生成工程为0.7.0/build14。Release构建、DMG只读挂载、资源cmp、codesign deep strict、hdiutil和SHA256通过。最终DMG 4603641字节，SHA256 ab2240d48c0809bebdea0c08c7b5924c88818f403321ed002f488113c44a375b；appcast SHA256 e1f1741638cf438f7fd2264c639b6e22fba984fe3ab33d8a4aea165446244f43、官方生成EdDSA验签通过，11历史项保持。见../artifacts/publish-next-itermate-release/evidence/local-release.txt和release-build.log。未测试/未GUI升级/未公证，Codex关联限制已写更新说明。
- T2: 已按tag→Release→资产独立校验→main顺序发布；远程v0.7.0 annotated tag解引用及main均为8a737da4db542024bbd36adbdf9813c14b7d9996。https://github.com/SSBun/iTermate/releases/tag/v0.7.0 为stable/non-draft/non-prerelease；DMG与85字节sha256文件公开URL均HTTP200。独立临时目录下载后checksum、与本地cmp及EdDSA验证通过，GitHub API DMG digest及长度一致。见../artifacts/publish-next-itermate-release/evidence/remote-release.json和published-verification.json。
- T3: 远程资产14:44:21+08验证成功后才推main；Pages对8a737da构建于06:45:09Z成功。缓存绕过获取https://ssbun.github.io/iTermate/appcast.xml返回HTTP200，新项0.7.0/build14、13.0/arm64、长度4603641、URL和EdDSA均匹配最终已下载DMG；公开feed与docs/appcast.xml逐字节相同，SHA256 e1f1741638cf438f7fd2264c639b6e22fba984fe3ab33d8a4aea165446244f43。11历史项完整保留；见public-appcast.xml与published-verification.json。未执行GUI两版本升级。
- Review gate: Passed — fresh独立只读round-02无confirmed findings或Target-blocking风险，TR-1被判resolved；owner重读保存报告并重核release commit、DMG/appcast/proof摘要及公开feed字节、远程稳定Release资产digest/大小与refs，均符合当前snapshot。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 公开稳定Release与Sparkle信任边界，保留既有Required义务；全部Target已有本地和公开证据，需fresh最终复审并核销TR-1身份闭环。
- Snapshot: git:8a737da4db542024bbd36adbdf9813c14b7d9996;dmg:ab2240d48c0809bebdea0c08c7b5924c88818f403321ed002f488113c44a375b;appcast:e1f1741638cf438f7fd2264c639b6e22fba984fe3ab33d8a4aea165446244f43;proof:310a6a23222e1145ed4c3ff819ded671eb0c0adb9d464df87c8b004e72e9ab90
- Evidence: T1/T2/T3及published-verification.json：Git/annotated tag、本地与独立下载字节、签名及公开feed一致；未测试/未GUI升级/未公证限制保持。Context无新增稳定事实，无需写入版本或发布状态。
- Task fingerprint: 3d207da89b0456cd15eb6ba8f0b4ba4e8bfde59f1cacc2aebe3b4558044e26b0
## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/publish-next-itermate-release/reviews/round-01.md) | git:8a737da4db542024bbd36adbdf9813c14b7d9996;dmg:ab2240d48c0809bebdea0c08c7b5924c88818f403321ed002f488113c44a375b;appcast:e1f1741638cf438f7fd2264c639b6e22fba984fe3ab33d8a4aea165446244f43 | incomplete | a408fd51e44fc95e2ba3f43aa63ecff4975f67689c45234accb61a6bbf589ce5 |
| 02 | [Round 02](../artifacts/publish-next-itermate-release/reviews/round-02.md) | git:8a737da4db542024bbd36adbdf9813c14b7d9996;dmg:ab2240d48c0809bebdea0c08c7b5924c88818f403321ed002f488113c44a375b;appcast:e1f1741638cf438f7fd2264c639b6e22fba984fe3ab33d8a4aea165446244f43;proof:310a6a23222e1145ed4c3ff819ded671eb0c0adb9d464df87c8b004e72e9ab90 | no blocking findings | c74105d76ea6be9f77a92fa5fa8969f06e0c01eb11de82e50fc6b8f7c7955b30 |

## Verification

- Passed: 终审后check-evidence验证两份报告及当前assessment；再次无缓存获取公开feed为HTTP200且cmp与已审docs字节一致，四份release文件与8a737da无diff。远程stable Release及两个资产digest/长度、annotated tag/main已重核；T1/T2/T3证据完整。未运行测试/GUI升级，ad hoc未公证及Codex关联边界持续披露。完成后仅补交核验记录，不改release字节或tag。
