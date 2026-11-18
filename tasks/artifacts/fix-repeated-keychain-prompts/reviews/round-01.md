# Review round 01

- Schema: task-review-report/v1
- Task: fix-repeated-keychain-prompts
- Round: 01
- Snapshot: snapshot:tasks/artifacts/fix-repeated-keychain-prompts/evidence/3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f.json#3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f
- Task fingerprint: c8d7d3dc0aafb81bd9c3e11b898fcbc0ac3215e0491bb315f8c398a143367397
- Outcome: no blocking findings
- Mode: independent subagent
- Run: 6165c795-8f2d-40c7-be3c-15fbcb69f20e

## Reviewer feedback

Review mode: independent subagent（独立子代理，只读单轮）。

Reviewed scope / snapshot:
本轮检查指定的五个源码／文档工件，以及必要调用方与失败路径。按任务包界定本次改动，没有将前任务的提供商改造归入本任务。

快照：`snapshot:tasks/artifacts/fix-repeated-keychain-prompts/evidence/3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f.json#3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f`

Findings: none。

No issues found.

Checks performed:

- T1：确认 App 唯一 `SecItemCopyMatching` 入口强制指定 `kSecUseAuthenticationUIFail`；Pi 已无 `readAIKey`、`find-generic-password` 或直接携密钥的 HTTPS 调用。
- T2：确认 broker 仅将三个账户映射至固定 HTTPS 端点，拒绝重定向；密钥仅由 App 读取并加入请求头。凭据失败返回通用错误，不返回密钥或提供商错误响应体。
- 确认目录与 socket 权限分别设为 `0700`、`0600`，Pi 检查属主、类型和权限；启动锁使用非阻塞独占锁，只有持锁实例清理旧 socket。
- 确认 broker 限制四个连接、64 KiB 输入、2 MiB 编码响应及连接总时限；可变连接状态归主 actor 管理，断连会取消所属任务。Pi 超时、取消和异常路径都会销毁连接。
- 确认 LLM 与 Decision 路由、配置身份复核、问题判断十秒截止和失败默认值仍保留。Decision 两端仍固定使用 `gpt-6-luna`，保留单个 predicate 答案及有限 `[0, 1]` 概率校验。
- 确认设置页与文档说明 App 运行要求、凭据恢复方式，以及同时更新 App、Pi 集成并 `/reload` 的交付边界。

Author evidence examined:

- `build.log`：记录 Debug 禁签名构建及 `BUILD SUCCEEDED`；保留非交互常量弃用警告。
- `typecheck.log`：为空文件。严格类型检查成功属于作者记录，本轮未独立重跑，空日志本身不能证明退出状态。
- `broker-smoke.py` 与 `broker-smoke.log`：脚本从实际源码提取 broker 和 client，在临时目录替换提供商处理器；日志记录模拟请求、客户端取消、服务端任务取消、权限拒绝及 App 不可用路径通过。其证据不覆盖真实 Keychain 或 API。

Unverified risks:

- 真实 Keychain 权限、锁定状态、GUI 弹窗及远程提供商未实测。因此不能声称安装后的弹窗问题已获端到端验证。按本次源码交付与禁止真实凭据验证的边界，此项不阻断 T1/T2 的静态审查结论。
- 本轮前后重读 manifest，内容一致，但没有重算文件哈希或执行 `check-evidence`，不能独立证明实际文件字节持续匹配快照。Owner 采纳本报告前仍需完成约定的审查后核验；若核验失败，则阻断当前快照结论，需复查受影响内容。

Coverage limits:
仅使用只读文件、搜索及工作区差异工具；未修改文件或状态，未委派，未运行 CLI、构建、类型检查或测试，未读取真实密钥、发送真实会话或替换安装态。结论限于指定任务范围与已读取证据。
