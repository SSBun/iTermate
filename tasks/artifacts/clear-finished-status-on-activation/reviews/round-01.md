# Review round 01

- Schema: task-review-report/v1
- Task: clear-finished-status-on-activation
- Round: 01
- Snapshot: snapshot:tasks/artifacts/clear-finished-status-on-activation/evidence/f645f9df75c64c7d16063ef3d35c4517d61b105a5bc62a2d54e943bd5fd6e741.json#f645f9df75c64c7d16063ef3d35c4517d61b105a5bc62a2d54e943bd5fd6e741
- Task fingerprint: 7c52a9f01b1b080bd84fe00500df2fce4c36b7a8a1f881ba6518f2b5a6906f40
- Outcome: findings
- Mode: independent subagent
- Run: 2c752572-f13a-4a70-b207-e441612832a2

## Reviewer feedback

## Review

Review mode: independent subagent

Reviewed scope / snapshot：本任务焦点确认逻辑、新增测试及上下文说明；manifest 标识为 `f645f9df…6e741`，未将其他任务的 dirty diff 归入本次审查。

### Findings

**TR-1 · P1 · Concern：应用激活不等于终端会话获得焦点，可能误确认未查看的完成结果。**

- **Location**：["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)，621–627 行。
- **Issue / Evidence**：`application_active=True` 时，仅凭 `app_active` 和 `current_window` 就返回当前 Session。SDK 明确允许 Preferences 等非终端窗口持有键盘焦点，同时保留当前终端窗口：["/Users/caishilin/Library/Application Support/iTerm2/iterm2env/versions/3.14.0/lib/python3.14/site-packages/iterm2/focus.py"](<file:///Users/caishilin/Library/Application Support/iTerm2/iterm2env/versions/3.14.0/lib/python3.14/site-packages/iterm2/focus.py>)，29–31 行；["/Users/caishilin/Library/Application Support/iTerm2/iterm2env/versions/3.14.0/lib/python3.14/site-packages/iterm2/app.py"](<file:///Users/caishilin/Library/Application Support/iTerm2/iterm2env/versions/3.14.0/lib/python3.14/site-packages/iterm2/app.py>)，365–377 行。刷新焦点并不能让 `current_window` 成为“终端当前为 key window”的证明。
- **Impact**：用户重新激活 iTerm2 的设置窗口时，后台终端的 finished 也可能转为 idle，并持久化为已读；用户尚未查看结果。
- **Suggested next step**：确认终端确实获得键盘焦点后再自动确认；不要将应用激活单独视为会话激活。补充“应用活跃、当前终端存在，但 Preferences 持有焦点”的回归用例。需修复。

### Unverified risks

- **快照身份**：已读取 manifest，范围包含实现、测试、上下文和构建日志；没有哈希执行工具，无法独立完成前后内容身份校验。主 Agent 必须执行前后 `check-evidence`；完成前属于当前快照验证阻塞项。
- **运行验证**：未运行测试或真实焦点验收，原生通知顺序及实际界面效果仍未验证。这符合本次明确限制，不单独要求突破限制，但不能宣称运行验收通过。

### Checks performed

- 对照实际 diff、SDK 事件类型及焦点缓存刷新实现。
- 检查 `clear_finished_status`、`set_agent_status` 和显式激活调用方。
- 确认刷新前状态比较可防止刷新期间被替换的新完成状态遭清除；running/awaitingInput 不进入清除分支，完成历史由既有逻辑保留。
- 阅读新增测试：覆盖基本激活、失焦、后台目标、状态保护及刷新顺序；未覆盖 TR-1。

### Author evidence examined

- 阅读任务记录的 T1/T2 自检与 R2 assessment。
- 构建日志第 546 行存在 `BUILD SUCCEEDED`；仅核阅日志，未重新构建。
- AST 与 diff 检查仅见作者记录，未独立执行。

### Coverage limits

只读源码审查；未运行测试、启动或重启 App/Bridge、修改安装态或任务状态。未审查其他任务改动，也未独立验证完整 Swift 统计与手动确认链路。