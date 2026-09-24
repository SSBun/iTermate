# 0.6.0 公开发布验证

- 用户在完整远端操作清单后回复 yes，随后执行 tag → Release 资产 → 独立下载验证 → main/feed 的发布顺序。
- 发布提交：`e63bf40bfa040c7861ff7a6c9f61d59f75b60a70`；annotated tag `v0.6.0` 解引用到该提交，main 已包含该提交。
- Release：https://github.com/SSBun/iTermate/releases/tag/v0.6.0；API 确认非 draft、非 prerelease。
- DMG：https://github.com/SSBun/iTermate/releases/download/v0.6.0/iTermate-0.6.0.dmg；4087624 bytes，SHA256 `2a13723699dd30b7e4ae6bf690fcf45198d9b7634b2145570a425342e1979f47`，资产 ID 585416397。
- SHA256 文件：https://github.com/SSBun/iTermate/releases/download/v0.6.0/iTermate-0.6.0.dmg.sha256；85 bytes，文件自身 SHA256 `8cadb5d77b0523529bacabf12e806a4b796bcbec12207baa0547065e0c93146d`，资产 ID 585416399。
- 两个公开 URL 独立下载均 HTTP 200；下载到 `/tmp/itermate-060-download` 后，shasum -c、与本地两资产逐字节 cmp、hdiutil verify 全部通过。
- Pages run 35970681110 成功部署发布提交。
- https://ssbun.github.io/iTermate/appcast.xml 无缓存请求得到 0.6.0/build13，arm64、macOS13、URL、长度均正确，公开 feed 与本地 XML 逐字节一致。
- 使用公开 feed 中的 EdDSA 对独立下载 DMG 验签通过，沿用既有 Keychain 密钥及已发布公钥。
- 本轮已通过 Bridge 自检及 74 项自动化测试；版本、日志、资源和本地签名验证详见 local-release.md。
- 签名为 ad hoc，未经 Apple notarization；未进行真实客户端安装升级验证，不声称已完成 Gatekeeper 公证或客户端端到端升级。
- 后续仅归档发布完成记录；不得修改 tag、DMG 或公开 feed 字节。
