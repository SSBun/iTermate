## 审查模式与范围

Review mode: independent subagent。仅提供反馈，未修改文件或任务状态。

审查五个产品源码文件及相关调用方，对照：
- ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/product.diff"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/product.diff)
- ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/review-snapshot.txt"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/review-snapshot.txt)

声明基线为 `0c79ef67e35e86646cf857e954c41c4e4c368002`，差异 SHA256 为 `b7df322f96f9e8304141ab5ec503e8a756d6c7bd0c4d0471b594588c475a4723`。已逐段核对实际修改内容；受工具权限限制，未独立计算哈希，最终内容身份仍需主会话复核。

## 已确认正确的部分

- 静态问号独立于动画分支，具有帮助文案与无障碍标签。
- 两端聚焦清除仍仅处理 `finished`；等待状态不携带退出码。
- 完成通知与计数依赖 `running → finished`，正常的 `running → awaitingInput` 不触发成功行为。
- 问题正文仅参与本地判断，不进入状态协议；`custom` UI 被排除。

## Findings

### TR-1 · P1：切换会话树后会持续误报运行中

- **位置：** ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，227–230 行。
- **问题：** `session_tree` 内使用 `ctx.isIdle()` 推导后续状态，但该事件触发时 Pi 尚未清理分支导航的内部忙碌标记。
- **证据：** ["/Users/caishilin/.local/share/mise/installs/node/latest/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/agent-session.js"](file:///Users/caishilin/.local/share/mise/installs/node/latest/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/agent-session.js)：2505 行无条件设置 `_branchSummaryAbortController`；2618–2624 行等待 `session_tree` handlers；2629 行才清除 controller。620–621、675–678 行表明其存在时 `isIdle` 必为 false。导航结束只解析 idle waiter，不发送 `agent_settled`。
- **影响：** 普通分支切换，包括不生成摘要的导航，都会发布 `running` 并持续续报；Pi 已空闲，iTermate 却一直显示运行状态。
- **建议：** 不以该事件期间的全局 `isIdle()` 判断真实 Agent 运行状态；使用实际 Agent 生命周期标记，在分支导航完成后恢复空闲，同时保留提示覆盖规则。此项需整改。

### TR-2 · P1：明确否定等待的文字仍命中待回复识别

- **位置：** ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，62–67 行。
- **问题：** 否定过滤未覆盖 `不会等待`、`not waiting`，随后正则直接匹配其内部的肯定子串。
- **证据：** 静态对照即可确定，`Please confirm the configuration. I am not waiting for your reply.` 不命中排除规则，却分别命中 `please confirm` 与 `waiting for your reply`，最终返回 true。中文“请确认配置是否正确。我不会等待你的回复，会直接继续执行。”同样命中。
- **影响：** 明确表示不等待的最终回复会显示问号并抑制完成行为；违背 Plan 中“否定等待表达不命中”的明确边界，而非一般性的允许漏报。
- **建议：** 在肯定等待判断前保守排除明确否定等待表达；将上述中英文输入加入后续获准执行的负例验证。此项需整改。

### TR-3 · P1：首个状态转换报告丢失后，持续心跳无法恢复等待状态

- **位置：**
  - ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，107–130、167–185 行。
  - ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)，548–550 行。
  - ["/Users/caishilin/Desktop/personal/iTermate/iTermate/TerminalStatusServer.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/TerminalStatusServer.swift)，84–89 行。
- **问题：** 报告超时、连接错误和成功响应均解析为相同的 `Promise<void>`；首次转换失败后仍只发送心跳，两端又拒绝与保留状态不同的心跳。
- **证据：** 接收端已有 `idle` 或 `finished` 时打开明确输入提示；若首次非心跳 `awaitingInput` 未送达，后续等待心跳因状态不一致持续被拒绝。旧 `idle/finished` 不参与租约失效，因而不会自行清除以允许恢复。iTerm2 的拒绝条件是本次新增。
- **影响：** 一次短暂传输失败即可使仍打开的明确问题一直没有问号，直到下一次生命周期转换；新增 iTerm2 guard 也使原来可由心跳恢复的运行状态受到相同影响。
- **建议：** 区分报告是否成功接收，在当前 generation 内对未确认的状态转换进行有界重试；保留旧心跳防覆盖机制，不宜直接取消接收端保护。此项是源码可推导的失败路径，未进行故障注入。

### TR-4 · P1：新增心跳 guard 与现有 Bridge 自检冲突

- **位置：** ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)，548–556、1325–1332 行。
- **问题：** 生产逻辑已禁止不同状态心跳覆盖，但同文件 `self_test()` 仍依赖原行为。
- **证据：** 自检先设置 `finished`，此时心跳记录已被删除；1331 行再发送 `running` 心跳，新 guard 会直接返回；1332 行立即索引不存在的 `agent_heartbeat_times["session-1"]`，将产生 `KeyError`。
- **影响：** 既有 Bridge 自检无法按当前源码通过。这是静态确定的冲突，不是声称已运行测试。
- **建议：** 更新自检以明确断言旧状态心跳被拒绝；需要验证新运行租约时，先发送合法的非心跳转换。执行自检仍须用户授权。

## Unverified risks

- **真实 UI、事件时序与双通道运行验收：未完成。** 没有事件回放或真实 iTerm2/Ghostty 观察，无法证明问号实际呈现、提示取消、长时间等待及重连效果。按已接受的“本轮源码交付、不启动安装态”边界，不另立阻断项；但不能将当前证据描述为 T1 运行验收通过。上述已确认问题仍需整改。
- **快照身份：独立哈希校验未执行。** 已复读快照声明及关键修改段，未观察到内容变化；本项依赖主会话完成前后哈希复核。若不一致，则阻断当前快照的 Target 验证，需重新审查。

## Checks performed

- 对照原始需求、有效决策及 Target，检查五文件差异和实际源码。
- 阅读 Pi 当前安装包的 UI 提示合并机制、事件串行分发、settled、会话替换及树导航实现。
- 检查两端协议校验、心跳租约、聚焦清除、状态映射、通知与计数调用方。
- 静态检查现有 Bridge 自检与新增 guard 的兼容性。
- 未执行测试、事件回放、构建、应用启动、安装替换或嵌套 CLI。

## Author evidence examined

- ["/Users/caishilin/Desktop/personal/iTermate/tasks/tasks/detect-agent-pending-questions.md"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/tasks/detect-agent-pending-questions.md) 中的 Implementation Checks、Result 与 Review Assessment。
- ["/tmp/iTermate-pending-questions-build.log"](file:///tmp/iTermate-pending-questions-build.log)：563 行为 `BUILD SUCCEEDED`；524 行为未链接 AppIntents 的元数据提取警告。
- Python AST、TypeScript strict/noEmit、`git diff --check` 通过来自作者记录，本审查未重新执行。

## Coverage limits

这是初次只读审查，无历史 TR 项。未扩展为全仓审计；所列运行结果预测均以源码路径为依据，不冒充实测证据。

- **Merge verdict: BLOCK**——上述确认项需主会话验证并整改；此结论仅为审查意见，不改变任务状态。