# Task Review Round 03

- Task: `add-native-codex-session-titles`
- Review mode: independent subagent
- Run identity: `/root/manual_title_menu_review`
- Reviewed snapshot: `sha256-manifest:ca3283a3,18c8b404,c07868cb,8fd511cd,560c1920,26c2958f,a5b14edf,dd92e7bc,32317950,e3878875,4a2f2614`

## Reviewer Feedback

Review mode: independent subagent

Reviewed scope / snapshot: 已核对任务记录、菜单路由、Codex 标题请求的启动/替换/完成/清理路径、Pi 能力拆分、模型生成器、相关测试与文档。审查前后 11 个 SHA-256 均匹配给定清单，无漂移。

Findings: TR-2 — Severity: Concern；Location: `iTermate/iTermateApp.swift:1077-1091`、`iTermate/ItermBridge.swift:585-627,1543-1621`、`iTermateTests/ItermBridgeTests.swift`；Issue: 新增的 T3 Codex 手动刷新及请求替换分支没有直接回归测试；Evidence: 测试仅覆盖标题显示 overlay，未调用 `refreshCodexTitle`，也未验证运行态可刷新、旧请求晚完成、失败清理或不同 Session 不交叉写入；Impact: T3 的核心异步所有权约束只能靠静态检查，后续修改可能破坏始终可用或 selected Session 隔离而不被测试发现；Suggested next step: 增加一个注入可控异步生成器的 focused store test，至少覆盖运行态手动刷新、第二次请求替换第一次，以及旧结果不能覆盖新请求/另一 Session。该 Concern 需要 remediation。

Unverified risks: 未执行单元测试、未启动 App、未连接真实 Ollama；真实菜单交互与本地模型端到端表现仍未验证。影响 T1/T3 的运行时置信度，但不阻塞当前静态 Target 核对。

Previous findings: TR-1 — resolved；任务槽保存 `requestID`，完成路径仅在槽位仍归属该请求时清理，旧请求不能清除替代请求句柄；当前修订仍保持该修复。

Checks performed: 只读追踪菜单的 Codex/Pi/Shell 分流、Pi `supportsTitleRefresh` 与 `canRefreshTitle` 拆分、Codex running/finished/其他状态入口、请求取消与替换、process/TTY/terminal Session/excerpt/requestID 写回守卫、reconcile/stop 清理、标题 overlay 和文档陈述；检索全部相关调用与测试引用；复验快照无漂移。

Author evidence examined: 已阅读作者记录的 `git diff --check` 通过及 `build-for-testing` 返回 `TEST BUILD SUCCEEDED`；未把这些当作本 Reviewer 重跑结果。

Coverage limits: 按约束未运行测试或构建、未启动/重启应用、未调用真实 Ollama，也未审查脏工作树中的无关历史改动。
