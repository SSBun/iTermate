# 修复 Control-Tab 切换跳过 Codex 会话

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 14:45) |
| Artifacts | [Artifacts](../artifacts/fix-control-tab-skips-codex/) |
| Kind | Task |

## Scope

仅修复全局快捷键遗漏 App 本地监控 Codex 状态的问题，保留 Bridge 的真实层级循环、当前项排除和 awaitingInput → finished → running → idle 优先级。不重启 App/Bridge，不覆盖用户安装态，不执行测试套件。

## Plan

1. 对照面板状态合并与快捷键候选来源，确认遗漏边界。
2. 将身份已校验的本地 Codex 状态纳入单次导航，补充回归用例。
3. 执行非测试构建及语法检查，完成独立审查并披露真实 UI 验证限制。

## Target
- [x] T1: Control-Tab 会话切换不再跳过本应参与切换的 Codex 会话。

## Task Summary

**App 状态与导航客户端**：[iTermate](../../iTermate/) 将与面板同源的 Codex 状态随全局快捷键请求传递，保留未知状态，不改变其他导航入口。

**iTerm2 Bridge**：[iTermateBridge](../../iTermateBridge/) 在单次候选筛选中采用 Codex 状态覆盖，保留原有层级、优先级和当前项排除；不改变生命周期存储或底层命令状态，并补充相应回归用例。

## Decisions

- 根因由源码链路确认：Codex 状态只在 Swift Store 合并，而旧快捷键仅由 Python 的 `session_statuses` 筛选，原生 Codex 外层状态为普通命令，因而被排除。
- 仅传递 Session ID 和可空生命周期状态，不传递终端内容或 Agent 回复；未知状态不得回退为旧状态参与切换。
- 不执行单元测试、Bridge self-test 或真实快捷键操作；用户需自行重新构建运行，检查真实 UI。构建使用独立临时 DerivedData，未更改运行中 App/Bridge。

## Result

- T1: 见 ../artifacts/fix-control-tab-skips-codex/evidence/checks.md：源链路确认原生 Codex overlay 现随导航请求参与真实候选筛选；保留状态优先级、当前项与普通命令排除、null 未知保护。Debug 构建、Swift/Python 语法与 diff 检查通过；测试及真实 UI 未运行，当前 App 未重启。
- Review gate: Passed — 独立 fresh/read-only reviewer bf19c608-8620-40ba-ad67-81c82696b32b 无 Findings；报告 ../artifacts/fix-control-tab-skips-codex/reviews/round-01.md 已保存，主会话重算源码与快照哈希、比较当前Git diff均无漂移。
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/fix-control-tab-skips-codex/reviews/round-01.md) | snapshot-sha256:e18093b98d360e8c15e4de65035eed210baf695c7b61bec4aeda5ee3508a40d2 | no blocking findings；主会话已复核实际哈希无漂移 |

## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 涉及 Swift→Python 导航协议与本地生命周期覆盖，未运行行为测试，按跨边界变更独立审查。
- Snapshot: snapshot-sha256:e18093b98d360e8c15e4de65035eed210baf695c7b61bec4aeda5ee3508a40d2; ../artifacts/fix-control-tab-skips-codex/evidence/snapshot.json
- Evidence: ../artifacts/fix-control-tab-skips-codex/evidence/checks.md; Debug BUILD SUCCEEDED，Swift/Python语法通过，源链路与本任务增量已自查。
- Task fingerprint: 9c28a9a58e335b358a10ea76dc698893f4680e3cf926de424182ae8a70b6aba0

## Verification

- Passed: 最终重新核对两处源码SHA与审查快照一致；Swift parse、Python ast.parse、git diff --check及Context validate通过；独立审查无问题且报告链接可访问。已成功的Debug构建对应同一源码。未运行测试或真实UI，App/Bridge PID未变，需用户自行重新构建运行验证快捷键。
