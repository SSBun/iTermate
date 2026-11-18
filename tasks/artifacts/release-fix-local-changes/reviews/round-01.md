# Review round 01

- Schema: task-review-report/v1
- Task: release-fix-local-changes
- Round: 01
- Snapshot: snapshot:tasks/artifacts/release-fix-local-changes/evidence/20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f.json#20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f
- Task fingerprint: 09a57a4c68332ff7e3c5c6ff00d4024007f0f7a95844da8e54f1fb12edf7cf7a
- Outcome: no blocking findings
- Mode: independent subagent
- Run: 1f2805cb-9556-4ff2-a91d-f641a8b70aa0

## Reviewer feedback

Review mode: independent subagent（独立子代理，单轮只读）。

Reviewed scope / snapshot:
对照原请求“commit all local changes and release a new fix version”，检查 T1 全部原有本地改动提交、T2 既有 GitHub Release／Sparkle 渠道补丁发布，以及本次 AI 集成的凭据与交付边界。

快照：`snapshot:tasks/artifacts/release-fix-local-changes/evidence/20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f.json#20fee03945f1ce7f87bd69ab77d777013e8456e09ac9dc44078312752d75766f`。已读取完整 20 文件 manifest，并在审查末尾重读；manifest 文本未见变化。

Findings: none。

No issues found.

Unverified risks:

- **快照时效性，涉及 T1/T2**：本轮不能重算文件哈希或执行 `check-evidence`。manifest 重读一致不能证明文件字节持续匹配快照。此项由 owner 约定的审后核验闭合；若核验失败或发现相关内容漂移，则阻断受影响 Target 的当前结论。
- **提交完整性与标签绑定，涉及 T1**：现有只读差异工具仅显示 reviewer 启动后相对 HEAD 的变化，不提供已提交范围。因此“全部 67 文件已进入发布提交”及 annotated tag 解引用到 `4885a12c112db666aa4f55b5ad8bb7256b8b1fa0`，本轮依赖作者记录，未独立复核 Git 历史。按已提供检查记录，不新增阻断项，但本报告不应被引用为该项独立 Git 验证。
- **安装后运行行为，涉及 T2，不阻断**：真实远程提供商、Keychain 权限／锁定状态、GUI 更新流程未验证。现有证据支持静态集成和发布产物一致性，不能证明所有安装后的运行场景。此限制符合本轮明确边界。

Checks performed:

- 先核对原请求、Target 和真实配置／源码，再读取详细作者证据。
- 确认项目配置和生成工程均为 **0.8.1/build16**；feed 最新条目对应 `v0.8.1`，最低 macOS 13、arm64，DMG 长度为 **4,960,592**。Release 元数据中的资产 URL、长度及 SHA-256 与本地发布记录一致。
- 确认生成工程包含 `AIModelService.swift` 和 Pi 集成资源；构建日志记录了实际 Pi 文件资源复制。App 启动路径调用 `startRequestBroker()`，并执行既有集成更新入口。
- 静态追踪 Pi／App 协议：双方使用同一 `AI/requests.sock` 路径和换行 JSON 协议，字段为 `account`、`body`，响应为 `ok`、`value`；输入和响应大小边界相容。
- 确认代理账户仅映射三个固定 HTTPS 端点，后台 Keychain 查询指定禁止交互授权；错误响应不返回密钥或提供商原始错误。目录／socket 权限、Pi 属主与类型检查、四连接限制、断连取消路径均可见。
- 确认 AI 设置、当前 AI 文档、changelog 与 Release 正文披露远程摘录发送、App 运行要求、Pi `/reload`、ad hoc 未公证及未执行的验收。
- 工作区差异摘要仅显示任务索引／任务记录变更和本次新增发布证据，未显示产品源码在审查启动后变化；这不替代哈希核验。

Author evidence examined:

- `local-release.json`：版本、架构／系统要求、DMG 长度与摘要、公钥、渠道及检查清单。
- `release-build.log`：Release arm64 编译、Pi 资源复制、ad hoc 签名、`BUILD SUCCEEDED` 和 DMG checksum VALID。
- `typecheck.log`：为空；严格 TypeScript 检查通过属于作者记录，空日志本身不证明退出状态。
- `remote-release.json`：稳定 Release，非 draft、非 prerelease，两资产已上传，DMG 大小和 digest 一致，发布说明包含升级及隐私边界。
- `remote-verification.json`、`public-appcast.xml`：作者记录两资产独立下载 HTTP 200、字节与摘要一致；已静态核对公开 feed 副本的最新条目。网络下载、完整 XML 字节比较、挂载资源对照和密码学验签均未重跑。
- 已阅读 Keychain 修复的历史独立审查报告作为背景，没有用历史结论替代本轮源码检查。

Coverage limits:
本轮为发布与指定 AI 接口的定向静态审查，不是全部历史改动审计。未独立读取提交 diff、重新下载或挂载 DMG、重算哈希、执行验签、运行 CLI／构建／类型检查／测试，也未请求真实 API 或 Keychain、安装或启动 App。未编辑文件、写报告或改变任务状态。本反馈不构成批准或完成授权。