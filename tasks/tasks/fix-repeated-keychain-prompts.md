# 修复后台 AI 重复钥匙串授权弹窗

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-13 16:05) |
| Artifacts | [Artifacts](../artifacts/fix-repeated-keychain-prompts/) |
| Kind | Task |

## Target
- [x] T1: 后台 AI 调用不会通过反复读取钥匙串持续触发授权弹窗
- [x] T2: 保留密钥安全存储与 AI 功能，在凭据不可访问时明确失败且不泄露密钥

## Plan

1. 确认钥匙串弹窗触发路径及后台调用边界。
2. 由 App 代理固定远程 AI 请求，移除 Pi 直接读取密钥，并禁止后台钥匙串交互。
3. 执行编译、类型检查和本地非敏感通信验证，再独立审查。

## Execution Log

### 001 — 确认直接调用来源

截图的调用者为 security。源码中 Pi 每次远程请求均启动 /usr/bin/security find-generic-password，且三秒后超时终止；并发或后续请求会重新启动，可能反复触发授权。App 的模型目录已有非交互读取，但其他请求仍默认允许交互。截图不足以证明每个弹窗的具体调用进程，以上为确认存在的重复触发路径。

为保留功能并避免把密钥交给通用命令行程序，改由运行中的 App 通过受限本机 Unix socket 代理固定提供商请求。Pi 不接收密钥；App 后台读取一律禁止授权交互。App 不可用或凭据不可访问则失败，不回退 security。不会读取真实密钥、改系统 ACL 或运行测试套件。

### 002 — App 代理与非交互读取完成

App 启动受限 Unix socket 服务，目录 0700、socket 0600；锁文件防止第二实例移除活动端点。仅接受 openai、deepseek、decision 三类账户并由 App 映射固定 HTTPS 地址，不向 Pi 返回凭据。限制四个并发连接、64 KiB 输入、2 MiB 输出和连接总时限；客户端关闭会取消所属请求。Pi 校验目录和 socket 属主及权限，移除 security 和直接 HTTPS 密钥调用。App 的所有 AI 读取一律指定非交互，保存密钥仍为用户主动操作。设置说明、Pi 失败提示及文档同步。

### 003 — 编译与非敏感通信验证

Debug 禁签名构建成功，TypeScript strict noEmit 成功，git diff --check 成功。broker-smoke.py 从当前源码提取实际 broker 与客户端，在临时目录编译执行；模拟请求成功，客户端取消与 App 所属模拟任务取消均通过，权限过宽 socket 被拒绝，App 不可用直接失败。没有访问真实钥匙串或远程 API，未运行单元测试或套件，未安装产物。构建保留 kSecUseAuthenticationUIFail 的 SDK 弃用警告；该标志用于当前支持的非交互行为，没有降低为允许交互。

## Task Summary

**AI 服务与设置**（[iTermate](../../iTermate/)）：App 代理固定远程 AI 请求，后台密钥读取禁止交互，设置页说明恢复访问方式与 App 运行要求。

**Pi 集成**（[integrations/pi](../../integrations/pi/)）：改为使用受权限约束的本机 socket，不再调用 security、读取密钥或直接发送携密钥的 HTTPS 请求，保留现有结果解析与生命周期取消。

**使用文档**（[docs](../../docs/)）：描述新的请求归属、权限、不可用行为和密钥恢复方式。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | A | 复用 App 请求、认证和解析；一个本机 socket 仅承接三类已有请求，无新增依赖 | 新增必要的本机通信与连接生命周期处理 |
| 稳定性 | A | Debug 构建、严格类型检查和实际源码通信检查通过；权限拒绝、两端取消、App 不可用均有观察证据 | 未访问真实 Keychain、真实 API 或 GUI；编译有非交互常量弃用警告 |
| 完整性 | S | 两端重复触发路径已移除，凭据继续由 Keychain 保护；入口、错误提示和文档一致 | 源码交付，安装态与现有 Pi 会话未替换；需运行新版 App 并 reload 新集成 |

## Result

- T1: Pi 源码已删除 readAIKey 与 security 调用；App 唯一读取入口强制 kSecUseAuthenticationUIFail，无允许交互开关。Debug 构建及 strict tsc 通过；模拟 socket 实际通信、App 不可用与两端取消通过，见 evidence/broker-smoke.log。
- T2: App 内保留 Keychain 保存与固定 HTTPS 请求，Pi 仅接收结果；本机服务限定账户、权限、大小和连接数，错误不带密钥或提供商响应体。实际模拟通信与权限拒绝通过，App 不可用无 credential fallback；未访问真实凭据、API 或 GUI。
- Review gate: Passed — 独立只读 Reviewer 6165c795-8f2d-40c7-be3c-15fbcb69f20e 无确认问题或阻断风险，round-01 已保存；owner 审查前后 check-evidence 均验证当前九文件快照，未出现漂移。真实 Keychain/API/GUI 未验证，仍为源码交付边界。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 改变密钥读取进程边界，新增本机请求代理和取消生命周期，需要独立检查安全与集成。
- Snapshot: snapshot:tasks/artifacts/fix-repeated-keychain-prompts/evidence/3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f.json#3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f
- Evidence: Result T1/T2；Execution Log 003；当前编译、类型检查和实际源码模拟通信证据。
- Task fingerprint: c8d7d3dc0aafb81bd9c3e11b898fcbc0ac3215e0491bb315f8c398a143367397

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/fix-repeated-keychain-prompts/reviews/round-01.md) | snapshot:tasks/artifacts/fix-repeated-keychain-prompts/evidence/3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f.json#3d712cd175cc86da72b737f564d7cd459ab680fbbce879ab6e043fdef944608f | no blocking findings | d86bfb9bf4d3123347ee28bd53e50f00fd23014c20b396a2344391c900bcf64c |

## Verification

- Passed: 最终 check-evidence 验证当前九文件与审查报告；Debug 构建、strict tsc、源码模拟通信和两端取消证据仍对应当前内容。无真实 Keychain/API/GUI 或安装态验证；Self Assessment 与当前结果一致。
