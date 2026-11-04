# 构建并发布 iTermate 0.8.0

| Field | Value |
| --- | --- |
| Status | In Progress (2026-11-04 15:34) |
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

## Target

- [ ] T1: 版本0.8.0 build15及发布说明一致，最终DMG和Sparkle签名验证通过
- [ ] T2: GitHub稳定发布、远端标签和公开appcast相互一致，下载产物校验通过
