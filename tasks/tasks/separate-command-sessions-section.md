# 将普通命令会话归入独立分区

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-22 16:13) |
| Kind | Task |

## Target
- [x] T1: 启用新设置后，普通命令或 Shell Session 集中显示在独立分区，不再混入各项目的 Agent Session 列表。
- [x] T2: Agent Session 继续按现有项目分组、状态与操作展示，普通命令分区中的 Session 仍可正常选择和操作。
- [x] T3: 关闭该设置时恢复当前按项目混合展示的行为，并持久保存用户选择。
- [x] T4: 独立 Commands 分区中的普通命令 Session 以当前工作目录末级名称作为行标题，并在悬停时显示完整工作目录。
- [x] T5: Commands 分区按目录末级名称进行不区分大小写的字母排序；相同完整工作目录的 Session 连续显示，同名不同路径按完整路径稳定排序。

## Scope

- Add one opt-in panel preference, disabled by default, that separates sessions without a confirmed Agent identity.
- Show separated command sessions in one collapsible Commands section after Agent groups and before Archive.
- Preserve the current Window/Project Path grouping, tab subgroups, status rendering, selection, and close actions.
- Do not change Bridge data, Agent detection, or lifecycle status rules.

## Plan

1. Persist the new preference through the existing AppSettings TOML path and expose it in General Settings.
2. Partition existing session-list items by confirmed Agent identity while retaining the current grouping behavior when disabled.
3. Render the Commands section through the existing group and row components, then add focused non-runtime coverage and compile/static verification.
4. Use the current working directory name and full-path hover text only for rows rendered inside Commands.
5. Sort Commands by directory name and full path, keeping each directory's tab blocks contiguous.

## Task Summary

**Session list and settings** ([iTermate](../../iTermate/)) adds an opt-in persisted preference that moves sessions without confirmed Agent identity into a collapsible Commands section after Agent groups and before Archive, displays their working-directory name with the full path on hover, sorts directory groups alphabetically, and reuses the existing tab, status, selection, and close behavior.

**Focused coverage** ([iTermateTests](../../iTermateTests/)) adds grouping and configuration persistence cases for the new preference; the cases were compiled by build-for-testing but not executed.

## Result

- T1: SessionGrouping now filters sessions without confirmed Agent identity from Window/Project Path groups and appends them as a Commands group; Swift parse, git diff --check, and Debug build-for-testing succeeded.
- T2: The Commands group reuses existing SessionListItem tab clustering, row rendering, activation, status, connectors, and close actions; Agent identity remains based on environmentAgentKind and Bridge/status code is unchanged.
- T3: AppSettings persists separate_command_sessions through the existing read-modify-write TOML path, defaults it to false, and General Settings exposes the toggle; focused persistence cases compile under build-for-testing.
- T4: Commands rows now pass an explicit presentation flag into the shared row renderer; TerminalSessionSnapshot.workingDirectoryName returns the final current-directory component with root fallback, the entire activation row exposes the full current path as its hover help, and accessibility labels use the displayed directory title. Swift parse, git diff --check, Context validation, and Debug build-for-testing passed; unit assertions and live UI were not run.
- T5: SessionGrouping now sorts command sessions by case-insensitive working-directory name, then case-insensitive full path, preserves source order within an identical path, and places missing paths last. PanelContent renders Commands through path-plus-tab blocks so the same full directory remains contiguous across tabs while existing tab headers, collapse behavior, status, selection, and close actions are retained. A focused compiled assertion covers same-name different paths, cross-tab identical paths, and alphabetical ordering. Swift parse, git diff --check, Context validation, and Debug build-for-testing passed; tests and live UI were not run.
- Review gate: Skipped — R1 bounded Commands-only presentation change with current deterministic self-check evidence and no explicit independent-review requirement.
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: The change is a bounded Commands-only ordering and presentation-block adjustment on top of the existing opt-in grouping, with no bridge, persistence, lifecycle, or external protocol change.
- Snapshot: sha256-manifest:8e28c3e4,7d71ce5e,f7fdaaa3,3f0401bf,56143b15,171b8a64
- Evidence: The owner inspected the current scoped diff and confirmed that Agent groups still use tab-only blocks while Commands uses path-plus-tab blocks fed by deterministic directory sorting. Swift parse, git diff --check, Context validation, and Debug build-for-testing passed. Tests and live UI were not run.
- Result clarity: The confirmed behavior defines case-insensitive directory-name ordering, full-path tie breaking, identical-full-path adjacency across tabs, and no extra directory headings.
- Bounded impact: Task-owned changes are limited to SessionListGroup display blocks, Commands sorting, the Commands rendering call sites, focused compiled assertions, and Context/task records; existing unrelated workspace changes remain untouched.
- Low risk: Failure is limited to recoverable Commands row order or tab-block presentation; Agent grouping and disabled-setting behavior use their existing paths, and no user data is mutated.
- Sufficient verification: Exact scoped hashes were recorded after the successful Debug build-for-testing. Swift parsing, diff whitespace validation, and Context validation passed; compiled assertions cover ordering and grouping but were not executed due the standing no-tests constraint.
- Task fingerprint: 113b8f931165e58328c2ab3fe8ab42a6fb47df0acc5b537db468a3ce631800f9

## Verification

- Passed: T5 is represented in the current source by deterministic case-insensitive directory-name sorting, full-path tie breaking, stable identical-path ordering, and Commands-only path-plus-tab blocks. Earlier Targets remain intact. Swift parse, git diff --check, Context validation, and Debug build-for-testing passed; tests and live UI were not run.
