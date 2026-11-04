# 构建并发布 iTermate 0.8.0

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-04 15:39) |
| Artifacts | [Artifacts](../artifacts/release-v080/) |
| Kind | Task |
| Parent | commit-and-release-next-minor |

## Plan

1. 更新0.8.0/build15版本及中文发布说明，按既有脚本构建DMG。
2. 校验最终包、签名和更新源，创建发布提交与标签。
3. 先推标签并上传GitHub资产，独立下载验证后再推main发布appcast。
4. 核对公开更新源并记录终态。

## Execution Log

### 001 — 本地发布产物验证

project.yml与生成工程已更新0.8.0/build15。现有脚本Release构建成功；DMG校验、只读挂载、包内版本和deep strict codesign均通过，arm64/macOS13，ad hoc未公证。默认Keychain账号ed25519不存在；查到历史发布使用SSBun.iTermate，使用该既有账号成功签署，无换钥。generate_appcast保留全部12个旧版本并加入新条目。Sparkle verify及OpenSSL使用App内既有公钥独立验签通过；Python cryptography不可用，未安装依赖。未运行测试或真实GUI升级。

产物：dist/iTermate-0.8.0_20261104-153526/iTermate-0.8.0.dmg，4747975字节，SHA256 2852d3aa575e6c1395b3674a5495b6957f5c981fd33ba6d1ce06f81a96dc8027。远端SSBun/iTermate默认分支main，Pages源main/docs，当前v0.8.0标签不存在。

### 002 — 远端发布与更新源验证

发布提交e85d4cc85ee3dc41449c912cd1734d33c2a4fbb4，annotated tag v0.8.0解析至同一提交。先推tag，创建稳定非草稿非预发布Release，上传DMG及85字节SHA256文件；两条公开下载URL均HTTP200。独立下载4747975字节DMG，随附checksum验证通过，与本地逐字节相同，并用App公钥独立验签成功。随后推main；Pages短暂提供旧版本，等待两轮后公开appcast首条与本地XML逐项一致（版本15/0.8.0、URL、长度、EdDSA、arm64、macOS13）。未发布或替换旧资产。

发布地址：https://github.com/SSBun/iTermate/releases/tag/v0.8.0
更新源：https://ssbun.github.io/iTermate/appcast.xml

## Task Summary

**版本配置**：更新 ["/Users/caishilin/Desktop/personal/iTermate/project.yml"](file:///Users/caishilin/Desktop/personal/iTermate/project.yml) 及其生成的Xcode工程版本为0.8.0/build15。

**发布说明**：更新 ["/Users/caishilin/Desktop/personal/iTermate/CHANGELOG.md"](file:///Users/caishilin/Desktop/personal/iTermate/CHANGELOG.md)，归纳本次版本用户可见变化及签名、测试限制。

**自动更新源**：更新 ["/Users/caishilin/Desktop/personal/iTermate/docs"](file:///Users/caishilin/Desktop/personal/iTermate/docs) 中的appcast，增加最终安装包签名条目，保留旧版本。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | S | 复用现有XcodeGen、打包脚本与Sparkle工具，只更新版本和发布元数据 | 无新增基础设施 |
| 稳定性 | A | Release构建、DMG校验及挂载、嵌套codesign、App公钥验签、独立远端下载及公开feed核对通过；资产先于feed发布 | 已接受ad hoc未公证；未运行测试及GUI升级，不能保证全部功能无缺陷 |
| 完整性 | S | 0.8.0/build15、发布说明、tag、稳定Release与公开feed一致；全部原改动已提交 | 无已知发布验收缺口；真实安装不在本次范围 |

## Target
- [x] T1: 版本0.8.0 build15及发布说明一致，最终DMG和Sparkle签名验证通过
- [x] T2: GitHub稳定发布、远端标签和公开appcast相互一致，下载产物校验通过

## Result

- T1: 0.8.0/build15元数据一致；Release构建、最终DMG校验及挂载、包内版本、嵌套codesign通过；4747975字节，SHA256 2852d3aa575e6c1395b3674a5495b6957f5c981fd33ba6d1ce06f81a96dc8027；Sparkle及App公钥OpenSSL验签通过。
- T2: v0.8.0与main发布提交均为e85d4cc；稳定Release两资产公开HTTP200，独立下载checksum、逐字节及公钥验签通过；Pages built并公开0.8.0/build15，与本地新条目完全一致。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 日常发布仅机械版本元数据、说明及生成的签名feed变更；未修改应用逻辑或发布基础设施，既有流程的各外部结果均可直接验证。
- Snapshot: snapshot:tasks/artifacts/release-v080/evidence/8e360512d9314aa10b51cf3dbfac7e91c6bce6ed2ae9e04a724daaab6208c6d2.json#8e360512d9314aa10b51cf3dbfac7e91c6bce6ed2ae9e04a724daaab6208c6d2
- Evidence: Execution Log 001/002及T1/T2；最终Release与Pages API复核仍为稳定发布、built e85d4cc。
- Result clarity: 用户要求minor发布；0.7.0/build14递增为0.8.0/build15，无渠道或密钥变更。
- Bounded impact: 只更新版本、发布说明和单个新feed条目；保留旧条目，产品变更来自已保存前置提交。
- Low risk: 无权限、协议、密钥或数据迁移变更；先验证签名资产再公开feed，不覆盖旧稳定资产；既定ad hoc未公证限制明确披露。
- Sufficient verification: 构建、DMG与嵌套代码签名、App公钥EdDSA、远端下载checksum和逐字节对照、公开feed与tag/Pages提交一致性均通过；未运行测试或GUI升级。
- Task fingerprint: 94af33e1fdd25eb38e02972497e51ee099105490bac80565def1c20d206e84c7

## Verification

- Passed: 终态公开feed匹配本地0.8.0/build15条目；Release仍非草稿非预发布，Pages built e85d4cc；源文件快照和diff检查通过，产物签名后未修改。
