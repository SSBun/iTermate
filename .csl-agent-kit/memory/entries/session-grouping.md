---
title: 列表分组与焦点
summary: 跨 Window/Tab 全局焦点唯一性、分组信息层级和对应回归检查。
---

- [2026-11-05] Bridge 快照供面板跨 Window/Tab 合并列表时，MUST 从 iTerm 当前 Window 的当前 Tab 读取唯一当前 Session ID，再生成全局焦点标记；MUST NOT 把各 Tab 的局部 current_session 各自发布为全局聚焦。快照 MUST 最多一个聚焦 Session。验收 MUST 用两个 Tab 的 self-test 断言仅当前 Tab 的当前 Session 标为 active，并在目标有焦点的真实 Socket 连续快照及运行面板截图中确认只有一个聚焦 Session。
- [2026-11-05] Window、Workspace 或路径分组中，分组元数据 MUST 放 section header，Session 行 MUST 只显示用户要求的主标识；除用户明确要求外，MUST NOT 用重复 Tab、路径等上下文挤占 Session 标题。计数 MUST 标明 sessions 等单位，MUST NOT 将 Session 数量表现为 Window 数量或显示会被误解为分组数量的无标签计数。验收 MUST 确认 Window header 的计数语义正确、Workspace header 显示文件夹路径、其下仅列 Session 标题，且每个 Session 仅出现一次并保留原有操作。
