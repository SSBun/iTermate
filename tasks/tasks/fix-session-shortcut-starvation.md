# 修复会话快捷键困在高优先级状态中循环

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 16:03) |
| Artifacts | [Artifacts](../artifacts/fix-session-shortcut-starvation/) |
| Kind | Task |

## Target
- [x] T1: 等待回复与 idle 的 Agent 会话处于同一优先级，连续切换时 idle 不会被等待回复会话持续挡住。
- [x] T2: 运行中的 Agent 会话和普通 Shell 不参与快捷键切换。
- [x] T3: 连续切换完整遍历所有符合条件的会话后才开始下一轮，优先级只影响轮内先后，不会导致其他候选永久无法被访问，也不会在末尾仅在两个会话间反复跳转。
- [x] T4: 未查看的已完成 Agent 会话在本轮尚未访问的候选中优先于等待回复及 idle；等待回复与 idle 同级次之，保持 T3 的完整轮次循环。

## Scope

只修改快捷键的候选优先级、相关设置说明及既有导航回归用例；保留 Codex 状态覆盖、真实焦点、当前会话排除及完成状态确认语义。不运行单元测试，不重启或覆盖用户安装的 App 与 Bridge，保留工作区已有改动。

## Plan

1. 核对现有完成确认路径与候选组，确保只调整未查看已完成会话的轮内优先级。
2. 将未查看已完成会话提至轮内首组，等待回复与 idle 同级随后，保留完整轮次记录并同步说明和回归用例。
3. 静态核对多终端优先级、已查看转 idle、完整循环及实时资格变化，完成语法与范围检查，不运行测试或用户 App。
4. 对当前修订执行新一轮独立只读审查，并完成最终验证。

## Decisions

用户最新修订并确认：未查看的已完成 Agent 会话在本轮未访问候选中优先于等待回复及 idle，后两者同级。连续切换仍须遍历完整的合格列表后才重新循环，运行中、普通 Shell、未知与当前项不参与；保留真实焦点、Codex 状态覆盖及现有查看确认语义，不扩展完成确认机制。分组提交另有 Pending 任务，本轮不执行 Git 提交。

## Task Summary

**Bridge**：[iTermateBridge](../../iTermateBridge/) 按真实 Session ID 保存单轮访问记录，优先选择本轮未访问的已完成结果，再选择同级的等待回复与 idle，只在全部可选项已访问后开启下一轮；每次按实时状态过滤并剔除已关闭会话，保留 Codex 覆盖和完成确认路径。回归用例覆盖未查看结果跨窗口优先、Pi/Codex 相互优先级、已查看转 idle、三轮完整遍历及会话增删和状态变化。

**快捷键设置**：[iTermate](../../iTermate/) 更新说明文字，明确每轮完整遍历、未查看已完成优先，以及跳过运行中与普通 Shell。

## Evidence Scope

[当前累计变更补丁](../artifacts/fix-session-shortcut-starvation/evidence/round-three.patch) 以本任务首次修改前工作区为基线，隔离已有改动；包含两个交付文件及对应 Context Pack 更新。[前一版补丁](../artifacts/fix-session-shortcut-starvation/evidence/round-two.patch) 与更早补丁仅保留历史证据，不代表当前优先级。

当前源码身份：Bridge SHA-256 `210eebc6efc33a1eac8dfc0aa37a395a1b5263c424c6bf9671d625b4116852ba`；快捷键设置 SHA-256 `ee8bbb35037c9a523c0dae1bf29051fe57a2c1003419db9fc65d537fcfc1d8fc`；当前补丁 SHA-256 `3dc321668ae060ea8ed1335d4b86ccc2297714d31f58c4dc00ce10f77bb4e33e`。

源码静态核对（非执行测试）：AST 提取候选常量为 ((finished,), (awaitingInput,idle))；访问记录筛选、无未访问项才重置、实时资格过滤及确认完成条件均未改变。以运行中的 pane 为当前项，合格列表为 A 等待、B 等待、C idle、F 未查看完成，可按源码得到 F→A→B→C 的连续循环；F 确认后转 idle，但已访问记录不被清除，不会提前抢占剩余项。当前用例还覆盖跨窗口未查看完成优先、未查看 Codex 优于 idle Pi、未查看 Pi 优于等待 Codex、已访问的 finished 不抢占本轮剩余候选，以及关闭/新建会话、实时状态变化、无候选与未知状态路径。用例未执行。

检查：Python AST/compile 整文件语法编译、Swift parse、范围内 git diff --check 和 Context validate 通过；查看确认逻辑、当前项排除、同级终端顺序、Codex null/状态覆盖及非 Codex finished 清理条件与修订前一致。

限制：未运行单元测试、完整 App 构建或真实快捷键验证，不将回归用例描述为已通过。未重启或安装 App/Bridge，未改动用户运行副本；用户需自行重新构建并运行 App 使仓库变更生效。

## Result

- T1: 当前源码与 round-three.patch 核对：awaitingInput 与 idle 保持同一候选组；本轮 visited 筛选防止重复抢占，轮内未查看 finished 优先。Python AST/compile 与 Swift parse 通过；测试未运行。
- T2: 源码核对保留 activityKind=agent 与 finished/awaitingInput/idle 限定；running、普通 Shell、未知及当前项继续排除；Codex 覆盖和原有完成确认分支未改动。
- T3: 轮次访问记录、清除时机和实时会话过滤相对上一版未变，只有无未访问候选时重启一轮。静态核对当前 pane 为 running 时 F完成→A等待→B等待→Cidle 的连续循环及完成转idle后不提前重选；三轮、增删会话和状态变化用例已同步但未执行。
- T4: AST 从实际方法提取候选常量为 ((finished,),(awaitingInput,idle))；未访问筛选发生在按该顺序构造的候选列表上；已查看按既有确认逻辑处理，未修改生命周期。设置说明与 Pi/Codex 及跨窗口回归用例同步，未执行用例。
- Review gate: Passed — fresh 独立只读 reviewer 4ca4beda-8016-4d74-b584-a9439f09fdbe 无确认问题或阻塞性风险；第02次反馈已原样保存并索引，主会话复核两个交付文件及累计补丁哈希与 R2 快照完全一致。运行验证未执行，Codex 确认语义保持既有范围。
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/fix-session-shortcut-starvation/reviews/round-01.md) | Bridge:4c66f692f13bf3d4b13df354052b642bfea1880c19fed2780461ce3b0a7409cf;Shortcut:c9189fcbbd1c7939d2d7355a8c607187e699251bd2397593ab9dff804e336cdf;round-two.patch:0d550570b05c191157afbe02b611af4f793d9e5fc862c7369c6e9dbcf2dc2560 | no blocking findings；测试与实机未执行 |
| 02 | [Round 02](../artifacts/fix-session-shortcut-starvation/reviews/round-02.md) | Bridge:210eebc6efc33a1eac8dfc0aa37a395a1b5263c424c6bf9671d625b4116852ba;Shortcut:ee8bbb35037c9a523c0dae1bf29051fe57a2c1003419db9fc65d537fcfc1d8fc;round-three.patch:3dc321668ae060ea8ed1335d4b86ccc2297714d31f58c4dc00ce10f77bb4e33e | no blocking findings；测试与实机未执行 |

## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 既有 R2 独立审查义务保留；本轮改变完整轮次中的优先级和受影响断言，需按当前确认规则重新独立核对，不沿用旧优先级的审查结论。
- Snapshot: Bridge:210eebc6efc33a1eac8dfc0aa37a395a1b5263c424c6bf9671d625b4116852ba;Shortcut:ee8bbb35037c9a523c0dae1bf29051fe57a2c1003419db9fc65d537fcfc1d8fc;round-three.patch:3dc321668ae060ea8ed1335d4b86ccc2297714d31f58c4dc00ce10f77bb4e33e
- Evidence: Result T1–T4 与当前 Evidence Scope；AST/compile、Swift parse、范围内差异检查和 Context validate 通过。测试与实机未运行，当前源码已逐分支静态核对。
- Task fingerprint: a307cf1e1b65ab172bbf19bf54ae7dc2d3955ec93764564f8d0a8c27bec45a7e

## Verification

- Passed: 独立审查后重检：当前 SHA-256、报告运行身份及索引一致，Python AST/compile、Swift parse、范围内 diff --check 和 Context validate 通过。T1–T4 按源码及独立只读审查核对无阻塞发现；未运行单元测试、完整构建或真实快捷键操作，未启动/重启/安装 App/Bridge，未提交代码。
