# 生成 Pi 任务面板不显示任务列表的问题报告

Status (2026-07-29 00:09): Completed

## Scope

- 包含：记录 Pi 任务面板无法显示当前工作区任务列表的复现条件、实际表现、根因证据和最小修复方向。
- 不包含：修改 Pi 扩展解析器、修改 `tasks/todo.md` 格式或实现修复。

## Target

- [x] T1：交付一份可独立提交给维护者的问题报告，明确指出 `tasks/todo.md` 与面板解析格式的差异。
- [x] T2：报告包含可复核的文件位置、复现步骤、预期/实际结果、根因和修复建议。

## Plan

1. 复核当前任务索引、Pi 面板扩展和已知解析规则。
2. 编写中文问题报告并记录实际证据。
3. 检查报告链接、格式和结论与源码一致。

## Result

- T1：已创建 [`reports/issues/pi-task-overlay-todo-format.md`](../../reports/issues/pi-task-overlay-todo-format.md)，记录原有 6 条业务任务索引与 `csl-task-overlay` 解析格式不一致的问题。
- T2：报告包含复现步骤、预期与实际结果、正则匹配证据、根因、影响范围和兼容性修复建议。
- `node` 确认当前任务索引共 7 条（包含本报告任务），面板解析正则匹配 0 条；`git diff --check` 通过。
- Review gate: Skipped — no explicit user request。
