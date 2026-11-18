# 提交全部本地改动并发布补丁版本

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-18 16:08) |
| Artifacts | [Artifacts](../artifacts/release-fix-local-changes/) |
| Kind | Task |

## Target
- [x] T1: 全部本地项目改动已提交至 Git
- [x] T2: 新补丁版本已发布且发布产物可核验

## Plan

1. 核对全部本地改动与敏感内容，更新 0.8.1/build16 版本和发布说明。
2. 使用现有脚本构建、校验并签署 DMG，提交全部改动。
3. 先推标签与发布资产，独立下载核验后推 main 更新 feed。
4. 核对公开 Release、标签及 appcast，记录验证与限制。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | S | 复用现有版本配置、构建脚本、Sparkle 工具和 GitHub 发布渠道，没有新增发布基础设施 | 无已知额外复杂度 |
| 稳定性 | A | Release、严格类型检查、挂载、资源对照、嵌套签名、App 公钥验签、独立远端下载与公开 feed 对照均通过 | ad hoc 未公证；未运行测试、真实模型、Keychain 或 GUI 升级，不能保证全部运行场景 |
| 完整性 | S | 全部原本地改动提交为 4885a12；0.8.1/build16 的 tag、稳定 Release、两资产及公开 feed 一致 | 后续仅提交发布核验记录，不改变已发布字节 |

## Execution Log

### 001 — 发布范围与版本确定

当前稳定版本为 0.8.0/build15；按用户要求发布补丁 0.8.1/build16。远端为公开 SSBun/iTermate，认证账号 SSBun，Pages 来源 main/docs；本地 main 比 origin/main 多三提交，没有落后。全部本地改动含 AI 提供商、模型选择、Keychain 代理修复、文档、记忆及已有任务证据。沿用 ad hoc 未公证限制，不运行测试套件或真实模型请求，不安装或启动 App。

### 002 — 本地产物完成

0.8.1/build16 Release 构建、严格 tsc noEmit、git diff --check、DMG verify、只读挂载、包内版本与资源逐字节对照、deep strict codesign 均通过。首次构建被工具超时中断，改用后台执行现有脚本后成功；首次类型检查配置不符当前编译器，改用 ESNext/Bundler 后通过，未修改产品代码。DMG 4,960,592 字节，SHA256 为 26a12cbd8e44a384b887a0661e55bd2e6dca0f0a3abbd30f322a2ffa317baf58。由既有 Keychain 账号 SSBun.iTermate 生成 appcast，保留全部历史条目，Sparkle 与 App 内公钥 OpenSSL 双重验签通过。敏感模式扫描唯一命中为任务名称中的 task-target 字符串，已确认不是凭据。证据见 evidence/local-release.json、release-build.log 与 typecheck.log。

### 003 — 发布与公开核验

发布提交为 4885a12c112db666aa4f55b5ad8bb7256b8b1fa0，annotated tag v0.8.1 解引用到相同提交。首次 push 使用系统 credential helper 超时，核对远端尚无标签后以当前 gh 账号完成推送；未改 Git 全局配置。首次 Release 创建上传中超时，检查只产生草稿和 checksum，确认 DMG 缺失后补充上传并公开，没有覆盖公开稳定资产。两资产独立下载均 HTTP200，长度、GitHub digest、checksum 和本地逐字节相同。随后才推 main。Pages built 为发布提交，公开 appcast 经无缓存请求与本地 XML 完全一致；13 个历史条目保留。全量 diff 检查只在原始构建日志空行及历史审查 Markdown 硬换行报告空白，保留不可变证据原文；产品、配置与正文范围 diff --check 通过。未执行单元测试或项目套件。

## Task Summary

**发布版本**（[项目配置](../../project.yml)）：将版本递增为 0.8.1/build16，同步生成 Xcode 工程。

**发布说明与更新源**（[文档](../../docs/)）：补充补丁版更新说明，为已校验 DMG 生成 Sparkle 更新条目；本次提交包含用户要求的全部既有本地修改。

## Result

- T1: 全部既有本地改动已提交4885a12c112db666aa4f55b5ad8bb7256b8b1fa0并推至origin/main；git提交清单含全部67文件，后续仅发布核验记录。
- T2: 0.8.1/build16；v0.8.1 annotated tag指向4885a12，稳定Release两资产HTTP200、独立下载checksum与本地逐字节一致；公开appcast与docs/appcast.xml完全一致。证据见local-release.json、remote-release.json、remote-verification.json与public-appcast.xml。
- Review gate: Passed — 独立只读round-01无发现；审后check-evidence验证20文件快照未漂移。owner重新核对67文件提交、远端main/tag绑定及稳定Release资产digest与公开feed完全一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 整体发布包含跨Swift/Pi的AI提供商与凭据边界变更，需独立复核当前集成和发布产物。
- Snapshot: snapshot:tasks/artifacts/release-fix-local-changes/evidence/20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f.json#20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f
- Evidence: T1/T2、Execution Log 002/003及发布证据；Release/tsc、资源与签名、远端字节、标签及公开feed核对通过；未测试或真实API/GUI验证。
- Task fingerprint: 09a57a4c68332ff7e3c5c6ff00d4024007f0f7a95844da8e54f1fb12edf7cf7a

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/release-fix-local-changes/reviews/round-01.md) | snapshot:tasks/artifacts/release-fix-local-changes/evidence/20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f.json#20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f | no blocking findings | 3502550cb5c206778b8a1346132f5e14c5f2227f2504154ce8bb608c2e2acac2 |

## Verification

- Passed: 审后快照与报告校验通过；远端main和v0.8.1均指向4885a12，稳定Release与4960592字节DMG摘要保持；无缓存公开feed与已审XML完全一致。自评依据未变；未运行测试、真实API/Keychain或GUI升级，ad hoc未公证。
