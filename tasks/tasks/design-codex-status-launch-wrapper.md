# 设计可精确监控 Codex 状态的启动包装器

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-16 16:27) |
| Artifacts | [Artifacts](../artifacts/design-codex-status-launch-wrapper/) |
| Kind | Plan |

## Target
- [x] T1: 实现可靠的 Codex 状态监控方案并接入 iTermate。
- [x] T2: 运行相关单元测试，验证状态监控与集成行为符合预期。

## Scope

包含 Codex 状态信号核实、必要的启动适配、iTermate 接入及相关单元测试；保留无关的现有未提交改动。不发布、不修改用户全局启动配置。

## Plan

1. 核实 Codex 的状态接口与 iTermate 现有采集链路，确定可靠信号和能力边界。
2. 实现最小监控适配并接入现有状态管道，补齐确定性单元测试。
3. 运行相关单元测试和必要检查，自检后完成独立审查及最终验证。

## Decisions

- 使用原生 app-server 生命周期和 runtime flags，不解析终端文字或用进程存活推测工作状态；保留原生 TUI 和审批，不驱动模型任务。
- 包装器只支持具有真实 Session ID 的 iTerm2；Ghostty 和其他直接 Codex 启动保留原有 hooks 通路，不声称具有同等精度。Session ID 是大小写敏感的路由标识，UUID 解析仅用于校验，不得改写原字符串。
- 不改用户全局 shell/Codex 配置，不替换或重启当前 iTermate/Bridge。用户需要自行运行新构建并从包装器启动会话；端到端真实模型轮次未现场验收。

## Task Summary

**Codex 状态适配**： ["/Users/caishilin/Desktop/personal/iTermate/integrations/status"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/status) 新增专属 app-server 启动包装器、透明 Unix WebSocket 观察与隔离回归覆盖；复用既有 ACK/owner/sequence 上报，在包装器子进程中抑制重复 hook 上报，区分原生等待、成功、失败、中断与退出；退出前为未确认完成与释放执行有界 ACK 重试，保留事件身份并报告超时。Session ID 校验保留原始大小写，启动链路回归使用含大写字母 UUID 和真实 Bridge handler 的严格 Session 匹配。

**Bridge 接收**： ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge) 为 Codex awaitingInput 正常续租，保持开始时间与结束去重，补充等待过期及失败退出状态测试。

**集成安装器**： ["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 随已启用的 Codex 安装、更新或移除包装器资源，保留既有 hooks 迁移机制；更新设置提示。["/Users/caishilin/Desktop/personal/iTermate/iTermateTests"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests) 覆盖安装权限、显式启用、更新、卸载及既有 Pi/Shell 回归。

**资源与说明**： ["/Users/caishilin/Desktop/personal/iTermate/project.yml"](file:///Users/caishilin/Desktop/personal/iTermate/project.yml) 增加包装器资源，并重新生成工程；["/Users/caishilin/Desktop/personal/iTermate/docs"](file:///Users/caishilin/Desktop/personal/iTermate/docs) 说明使用入口、原生状态映射、支持边界与未执行的现场验收。

## Verification Notes

- 用户原始请求设计 Codex 启动包装器；随后明确要求找到状态监控解决方案并运行单元测试，最终确认直接实现并接入 iTermate，而非仅设计或原型。
- 本机 Codex 0.162.1 的 help 与导出 JSON Schema 确认 --remote、Unix WebSocket 和 thread/status/changed、turn/started、turn/completed 及 waitingOnApproval/waitingOnUserInput。
- 相关 Python 状态测试 46 项、Bridge 回归 30 项、Swift 安装器 10 项通过，共 86 项。Swift 独立 XCTest runner 链接本次隔离构建的真实 dylib，不调用 App main；最初的 XCTest 路径/链接配置错误已修正，首次安装失败和 macOS 半关闭清理失败均有修复后的回归证据。
- build-for-testing、Python 语法、Context 与 git diff --check 通过；原生协议探针使用临时 HOME/CODEX_HOME，仅执行 initialize 与 thread/loaded/list，确认 0 个 thread、代理仍有效且专属后端退出。
- 未创建真实 Codex 对话或模型轮次；未验证现场 App 图标、真实审批交互和实际用户安装生效。iTermate/Bridge 的运行 PID 与启动时间未因本任务改变。
- Workspace 已有多项未提交变更；任务独立 diff 以开始时保存的逐文件基线生成，不把此前 Agent Hooks/Pi/venom 等改动归入本任务。
- 首轮审查 TR-1 已核实：两项新增回归在修复前分别因 finished/detached 仅尝试一次失败；修复后覆盖在途完成失败、释放失败后恢复、持续故障超时仍尝试释放、接收端拒绝不重抢所有权及丢失 ACK 不恢复已读标记。首轮返回后逐项复核原快照全部源文件与证据 hash，无漂移。

## Result

- T1: round-03/session-id-fix.diff只修复UUID格式校验改写ID及其回归；严格原始大写ID、实际Bridge handler的启动链路测试修复前复现Session no longer exists、修复后所有ACK成功并收到四种Agent状态且最终释放。当前用户旧进程未重启，实际新会话需用户自行重开验证。
- T2: evidence/round-03：状态46、Bridge30、Swift安装10，共86项全部通过；build成功且bundle脚本cmp一致，原生只读传输探针通过且0thread；语法、Context与diff-check通过。运行中的用户App/Bridge/Codex PID和启动时间保持不变。
- Review gate: Passed — fresh只读reviewer b5ac4314-b9b7-4603-abdb-2586a466083d，reviews/round-03.md无实质问题；主会话复核10个源文件和9份证据hash零漂移，bundle与源码cmp一致、已安装Bridge仍匹配，条件性证据缺口已消除。
## Live Findings

- 用户通过 codexm 启动后仍显示 command，重新打开本任务复核同一监控结果。前次只读调查没有修改产品或运行测试；用户随后明确要求修复并重新测试。本次保留既有运行实例，不覆盖全局安装态。
- 真实进程确认包装器、专属 app-server 和 remote TUI 均已启动；运行中的 Bridge 和已安装 reporter 与当前源码 SHA256 一致，不能归因为别名没生效或旧脚本未更新。
- 目标 iTerm Session 的原始 ID 为 `39D02C5F-C984-4422-903B-66E950088BBE`，Bridge 实时快照仍为 running/command。专属后端只读查询确认原生 thread 存在，调查时 runtime status 为 idle，没有创建或恢复任何 thread。
- 调查时确认包装器第375行的旧代码 `str(uuid.UUID(session_id))` 将原始 iTerm Session ID 变为小写，reporter 原样发送转换后的 ID。已安装 iterm2 库以字符串相等精确查找，Bridge 第231–233行在找不到 Session 时拒绝为 Session no longer exists。因此该环境下无法成功接收 Codex 状态，普通命令 fallback 持续可见。
- 上述拒绝路径由真实环境值、当前执行源码与已安装查找库确定；没有抓取正在运行包装器的 ACK，也没有注入 setSessionStatus 报告，不把推导描述为抓包观察。
- 修复前的端到端启动夹具使用全数字 UUID，Bridge 查找替身接受任意 ID；此前86项测试没有覆盖真实大写字母 ID 的路由一致性。只读调查没有重新运行测试，旧通过结果不能证明现场可用。
- 已按用户后续要求修复：解析 UUID 仅用于校验，保留原始字符串；启动链路回归改用含大写字母 UUID，并通过实际 Bridge handler 严格查找原 ID。没有重启用户的 App、Bridge 或 Codex。
- 只读调查证据：[Live diagnosis](../artifacts/design-codex-status-launch-wrapper/evidence/live-diagnosis-2026-10-16.json)。
- 同一严格匹配测试在修复前明确失败，所有 ACK 均为 Session no longer exists；修复后通过，检查原始大写 ID 无变化、所有 ACK 成功，以及接收端的 idle/running/awaitingInput/finished 均为 Agent，最后正确释放所有权。证据位于 evidence/round-03 的 case-regression-before.log 和 case-regression-after.log。
- 修复后重跑 Python 状态46项、Bridge30项、Swift安装10项，共86项全部通过；隔离 build-for-testing、当前源码与 bundle 资源 cmp、原生无thread传输探针、语法、Context 和 diff-check 通过。
- codexm 仍指向仓库脚本，修复在下次启动包装器时加载。当前仍运行旧包装器的会话没有被自动修复；用户需自行退出后用 codexm 或 codexm resume --last 重开，不必为这处 Python 修复重启已经匹配源码的 App/Bridge。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/design-codex-status-launch-wrapper/reviews/round-01.md) | sha256:5d3682e8cb778f0bce05205ecfe3ff6fa5e6c602a77b9597f8285c6f2b94e138 | findings: TR-1 |
| 02 | [Round 02](../artifacts/design-codex-status-launch-wrapper/reviews/round-02.md) | sha256:e79a5d8d104b5f318dc0d66a5563767b9cf2983857bd6ca2cba4cd684d651da3 | no blocking findings；TR-1 resolved |
| 03 | [Round 03](../artifacts/design-codex-status-launch-wrapper/reviews/round-03.md) | sha256:3bd71b6919c65e5b7d3b4f4c31c0906d671d6c4c3796dba2b6d22f57ec819363 | no blocking findings；Session ID修复未引入实质回归 |

## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 保留既有R2独立复审义务；本次修复真实大写Session ID路由被规范化的缺陷，需确认严格接收链路回归及未改变信任边界。
- Snapshot: sha256:3bd71b6919c65e5b7d3b4f4c31c0906d671d6c4c3796dba2b6d22f57ec819363
- Evidence: evidence/round-03/snapshot-03.json、session-id-fix.diff、case-regression-before.log/after.log与Result T1/T2；86项测试及隔离构建通过，旧用户会话未重启。
- Task fingerprint: 7384a25daae72cc77f16612f48a6bd228968e08a4eb5172adceeff17fec00b35

## Verification

- Passed: 复审后最终状态46、Bridge30、Swift安装10项再次全部通过，共86项；严格大写ID回归包含在状态测试中；10个源码和9份证据hash保持审查版本。当前bundle包装器与源码一致，已安装Bridge匹配；不宣称旧运行会话已更新，用户须自行重开codexm加载修复。
