# 按等待回复、完成、空闲、运行中调整会话切换优先级

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 17:56) |
| Kind | Task |

## Scope

仅调整 Agent 会话快捷键的状态优先级、设置说明和受影响的回归用例；沿用现有五秒窗口、完整轮询及当前会话与普通命令排除规则。不运行测试、不安装或重启 App／Bridge。

## Plan

1. 将等待回复、完成、空闲、运行中按四档优先级纳入现有轮询。
2. 更新设置说明和受影响的 Pi／Codex 导航、完整轮询与超时用例。
3. 对照实际调用与候选过滤逻辑，完成语法及差异检查，记录未运行测试和真实交互的限制。

## Task Summary

**Bridge 会话导航**：[iTermateBridge](../../iTermateBridge/) 将候选按等待回复、已完成、空闲、运行中四档排序，运行中的 Agent 纳入现有完整轮询；同步调整跨窗口、Pi／Codex 状态、无饥饿遍历及五秒超时回归用例。

**快捷键设置**：[iTermate](../../iTermate/) 更新设置说明，明确新的四档优先级及运行中会话参与切换，保留五秒操作窗口说明。

## Target
- [x] T1: 每轮会话切换按等待用户回复 > 已完成 > 空闲 > 运行中排序，运行中 Agent 会话也参与遍历。
- [x] T2: 保留相邻操作不超过五秒继续本轮、超过五秒重新按当前优先级开始的策略，以及完整遍历后重复、排除当前会话与普通命令的边界。

## Result

- T1: 源码逐分支核对：候选外层顺序明确为 awaitingInput、finished、idle、running，内层统一限定 activityKind=agent，Pi与App传入的Codex状态使用同一规则。按既有焦点更新和visited语义人工推演 waiting-a→waiting-b→finished→idle→running，保持等待/空闲/运行状态不被激活清理。设置说明与受影响用例已同步；用例未执行。
- T2: 对照先前实现，五秒单调时钟超时分支、已访问集合过滤、完整轮询耗尽重置、当前会话排除及普通命令限制未改；静态推演100→105→110保持本轮，115.001超时重新选择等待回复而非剩余空闲。Python compile、swiftc -parse、限定文件git diff --check通过；未运行测试、完整构建或真实快捷键，未启动/安装/重启App或Bridge。
- Review gate: Skipped — 当前R1评估具备明确结果、局部影响、可恢复低风险和源码对照验证四项依据；没有显式或既有独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 生产逻辑仅将既有两档候选排序改为明确四档，复用现有选择、锁、循环、激活及状态清理路径；其余变更为匹配的新文案和回归用例。
- Snapshot: sha256:Bridge=d93ff89ec2c22d86898d74af45e7fd1a20b7f80d8042bd26ca199517a72da7f0;Shortcut=c51a58b3931e454f201181432429c349cd9a4467453c1701e8644859303f2c8f
- Evidence: T1/T2结果：四档候选与轮询边界静态核对、状态转换及五秒边界人工推演、Python compile、Swift parse和差异检查。
- Result clarity: 用户已确认等待回复>完成>空闲>运行中，仍完整遍历且保留五秒窗口；没有未决产品解释。
- Bounded impact: 只改变现有Bridge导航候选状态排列与running资格，Swift仅改说明；Pi/Codex共享同一路径，调用接口、输入验证及状态清理分支未变。
- Low risk: 失败仅影响可重复按键纠正的导航目标，不引入关闭、写入、授权、隐私或不可逆操作。
- Sufficient verification: 直接核对四状态排序及agent限定、原循环与超时未变；人工推演全部受影响断言与Pi/Codex优先级，语法和差异检查通过；测试和运行时交互未执行且明确披露。
- Task fingerprint: 70bee51604433a18293067d00c2208cfa0df285c16baa7dcbcd5b1124e1c9477

## Verification

- Passed: 最终两文件SHA256与R1评估一致；再次Python compile、swiftc -parse、限定差异git diff --check通过。源码对照确认四档优先级、Pi/Codex同路由、完整遍历和五秒窗口保留。未运行测试、完整构建或真实交互，需用户自行重新构建运行；运行中App/Bridge及用户安装目录未主动更改。
