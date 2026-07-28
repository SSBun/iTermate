---
created: 2026-07-28
task: iterm-bridge-tab-list
review_cycles: 3
---

# iTerm Bridge 与 Tab 列表审查

Topic: 默认构建与测试是否可独立复现

> **E1:** 初始实现通过关闭代码签名运行了 9 个测试，但测试 target 没有生成 Info.plist。
>
> **R1:** 默认 `xcodebuild test` 会在测试 bundle 签名阶段失败，要求从规范工程配置生成测试 Info.plist。
>
> **E2:** 在 `project.yml` 的测试 target 启用 `GENERATE_INFOPLIST_FILE` 并重新生成 Xcode 工程；默认测试命令通过。
>
> **R2:** 确认 Debug、Release 配置及默认 9 个测试均通过。

**Conclusion:** 默认 Xcode 构建和测试已可独立复现。

Topic: 连接生命周期与最小实现

> **E1:** Swift 客户端通过 Unix Socket 自动重连，Bridge 用文件锁保证单实例；重连通过两次 mock 连接进行真实验证，但没有为网络层引入测试替身。
>
> **R1:** 指出未自动化的重连回归风险、未使用的停止状态和发送失败可能静默丢失操作。
>
> **E2:** 明确认领重连自动测试的残余风险，不为此增加 socket factory；删除未使用的停止状态，并让发送失败进入共享重连路径。
>
> **R2:** 确认死代码已删除、发送失败可触发重连，人工重连证据足以覆盖当前阶段且残余风险已明确。
>
> **R3:** 全量复查未发现新的连接、并发或 IPC 权限问题。

**Conclusion:** 生命周期实现保持最小，发送错误可恢复；网络层重连尚无自动化回归测试，但已有真实 mock 验证。

Topic: Python Bridge 自检真实性

> **E2:** 初始自检仅在带 `iterm2` 包的 iTerm Python 运行时执行。
>
> **R2:** 指出顶层导入会使系统 Python 在进入 `--self-test` 前失败，导致自检证据表述不完整。
>
> **E3:** 将 `iterm2` 导入延迟到 runtime 分支，使系统 Python 自检可运行，同时保持 Bridge 启动路径不变。
>
> **R3:** 确认系统 Python 自检、Python 编译和默认 Xcode 测试全部通过。

**Conclusion:** 自检现在可在普通系统 Python 中独立执行。

---

**Final decision:** `APPROVED`

**Outcome:** Bridge 安装、受保护的 Unix Socket、全量层级同步、焦点与布局更新、Tab 展示与激活、错误反馈和自动重连均获独立审查批准。

**Remaining:** none
