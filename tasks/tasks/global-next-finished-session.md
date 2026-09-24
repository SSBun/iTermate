# 增加全局快捷键切换到下一个已结束 Session

| Field | Value |
| --- | --- |
| Status | In Progress (2026-09-23 17:22) |
| Artifacts | [Artifacts](../artifacts/global-next-finished-session/) |
| Kind | Task |

## Target
- [x] T1: 提供iTermate全局快捷键，在任意应用前台时仅在明确标记为Agent的Session间跳转，按等待回复、已结束、运行中、空闲的优先级选择下一个其他Agent，激活其iTerm2窗口、Tab及对应Session。
- [x] T2: 设置页可录入、更改、清除快捷键，配置重启后保留。
- [x] T3: 从当前Session按Window、Tab、Session顺序向后循环查找，仅匹配真实activityKind=agent；依次优先awaitingInput、finished（含成功和失败）、running、idle。排除普通命令、当前Session、未知与独立模型推测，无符合条件的其他Agent时不切换，不擅自重启App。

## Plan

1. 使用系统全局热键注册和App内录入控件；默认不绑定，处理取消和冲突。
2. 在Bridge实时查找并激活目标，固定路由到iTerm2，配置沿用现有持久化。
3. 构建、语法和静态检查，新增回归用例但不运行未经授权的测试；不启动用户App。
4. 完成独立只读审查，并披露真实快捷键和界面尚未人工验收的边界。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [需求调整后停止](../artifacts/global-next-finished-session/reviews/round-01.md) | evidence/snapshot-01.json | incomplete：增加running兜底，旧范围审查停止 |
| 02 | [独立审查反馈](../artifacts/global-next-finished-session/reviews/round-02.md) | evidence/snapshot-02.json | 未发现代码缺陷；存在两个阻断行为验收的证据缺口 |

## Review
- Schema: task-review-ledger/v1
- Pass: 1
- Next finding: 3
- `TR-1` | no-progress=0 | T1/T2 | 补齐真实跨应用热键、设置录入/冲突/取消以及重启恢复的交互证据。
- `TR-2` | no-progress=0 | T1/T3 | 补齐真实多窗口/Tab/分屏切换、finished优先与running兜底、无目标不切换的端到端观察。

## Result

- T2: General新增录入、更改、Clear、错误提示；Escape/失焦/页面消失取消并恢复原配置。默认无绑定，配置用现有AppConfig序列化并在写入前重读、原子写入，写入失败不发布新值。新增持久化/清除/保留其他配置的XCTest源；build-for-testing编译通过但未执行测试。真实设置交互与快捷键冲突仍待用户验收。
- T1: 按用户确认增加idle兜底，Agent选择优先级awaitingInput→finished→running→idle；UI说明与文档一致。当前snapshot-05；应用与测试目标编译通过，未运行测试。尚未触发真实快捷键验收或完成最终复核。
- T3: 仅activityKind=agent参与四级循环，跳过当前及普通命令、未知/模型估计。idle与waiting/running同样不修改状态和起始时间，仅finished执行原完成清理。已补充idle低优先级、同类循环、保留idle状态/时间、普通Shell及未知kind排除的回归源，未执行。Python AST、git diff --check和Context验证通过；没有重启App、修改用户安装态或执行Git提交。
- Review gate: Required — 上一轮因需求变更停止，无结论；以snapshot-02重新派发fresh只读审查。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 全局热键录入、持久化及跨进程导航；用户新增running兜底后重新独立审查。
- Snapshot: evidence/snapshot-02.json sha256:2df51fd0111362d66f391badbcbb31e555d98fad0e27d77ac58ca3b32d0635d4; 8个交付文件及scope-02.diff。
- Evidence: T1–T3；最新build-for-testing通过，仅编译未执行；Bridge AST、git diff --check通过；真实UI/热键未验收。
- Task fingerprint: dbafd94ce525303b1afe69d2f690cd5d3ca94fd2de9b5a93bce970d0a06b6410
