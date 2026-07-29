# Pi 任务面板无法显示工作区任务列表

- **状态**：Open
- **建议优先级**：中
- **影响范围**：Pi 的 `csl-task-overlay` 任务面板
- **相关文件**：[`tasks/todo.md`](file:///Users/caishilin/Desktop/personal/iTermComrade/tasks/todo.md)、[`csl-task-overlay.ts`](file:///Users/caishilin/Desktop/personal/skills/pi/extensions/csl-task-overlay.ts)

## 问题摘要

在 `iTermComrade` 工作区启动 Pi 后，任务面板不显示任务列表。问题发生时 [`tasks/todo.md`](file:///Users/caishilin/Desktop/personal/iTermComrade/tasks/todo.md) 包含 6 条现有任务；本报告创建时新增了 1 条报告自身的任务记录，因此当前文件共 7 条。问题不是任务索引为空，而是索引格式未被面板解析器识别。

## 复现步骤

1. 在 [`/Users/caishilin/Desktop/personal/iTermComrade`](file:///Users/caishilin/Desktop/personal/iTermComrade) 工作区启动 Pi。
2. 让 `csl-task-overlay` 扩展加载并观察编辑器上方的任务面板。
3. 检查 [`tasks/todo.md`](file:///Users/caishilin/Desktop/personal/iTermComrade/tasks/todo.md) 中的任务条目。

## 预期结果

面板应显示标题和当前任务，例如正在进行的任务以及已完成任务；复现时原有索引只有 6 条，正好未超过扩展显示最近 6 条任务的限制。

## 实际结果

任务面板为空或不可见。扩展的 `loadTasks()` 未解析出任何任务，`refresh()` 随后清除 `csl-tasks` widget。

## 根因分析

面板当前使用的 `INDEX_LINE` 正则只接受以下格式：

```md
- [任务标题](todo/task.md) — In Progress (2026-07-29 00:01)
```

但工作区索引使用的是：

```md
- 任务标题 — Status (2026-07-29 00:01): In Progress — [任务记录](todo/task.md)
```

差异有三处：

1. 解析器要求标题本身从 `[标题]` 开始，实际标题是普通文本。
2. 解析器要求任务链接紧跟标题，实际链接位于条目末尾。
3. 解析器要求状态位于末尾，实际状态包含 `Status (时间):` 前缀并位于链接之前。

因此每一行都无法匹配 `INDEX_LINE`，`loadTasks()` 返回空数组；这是面板隐藏的直接原因。

## 建议修复

在 [`csl-task-overlay.ts`](file:///Users/caishilin/Desktop/personal/skills/pi/extensions/csl-task-overlay.ts) 中让解析器支持当前工作区的规范格式，并保留对现有旧格式的兼容。建议同时增加一条使用当前 `tasks/todo.md` 格式的回归测试，确认：

- 原有 6 条任务索引都能被解析；
- `In Progress` 和 `Completed` 状态正确映射；
- 任务文件链接仍可用于读取 Target 进度；
- `/csl-tasks` 与编辑器 widget 都能显示任务。

不建议仅为适配面板而重写当前任务索引；问题位于只读面板解析器与任务索引格式之间的契约漂移。

## 影响与风险

- 任务数据和任务文件未丢失，直接打开 [`tasks/todo.md`](file:///Users/caishilin/Desktop/personal/iTermComrade/tasks/todo.md) 仍可查看全部任务。
- Pi 原生没有内置任务面板；本问题针对已安装的 `csl-task-overlay` 扩展。
- 修复解析器时需保留旧格式兼容，避免影响已有其他工作区的任务面板。
