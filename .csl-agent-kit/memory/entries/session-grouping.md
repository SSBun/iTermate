---
title: 列表分组与焦点
summary: 跨 Window/Tab 全局焦点唯一性、分组信息层级、项目标题栏操作及回归检查。
---

- [2026-11-05] Bridge 快照供面板跨 Window/Tab 合并列表时，MUST 从 iTerm 当前 Window 的当前 Tab 读取唯一当前 Session ID，再生成全局焦点标记；MUST NOT 把各 Tab 的局部 current_session 各自发布为全局聚焦。快照 MUST 最多一个聚焦 Session。验收 MUST 用两个 Tab 的 self-test 断言仅当前 Tab 的当前 Session 标为 active，并在目标有焦点的真实 Socket 连续快照及运行面板截图中确认只有一个聚焦 Session。
- [2026-11-05] Window、Workspace 或路径分组中，分组元数据 MUST 放 section header，Session 行 MUST 只显示用户要求的主标识；除用户明确要求外，MUST NOT 用重复 Tab、路径等上下文挤占 Session 标题。计数 MUST 标明 sessions 等单位，MUST NOT 将 Session 数量表现为 Window 数量或显示会被误解为分组数量的无标签计数。验收 MUST 确认 Window header 的计数语义正确、Workspace header 显示文件夹路径、其下仅列 Session 标题，且每个 Session 仅出现一次并保留原有操作。
- [2026-11-19] 用户要求 iTerm2 的 Project Path 项目分组标题 MUST 在会话计数前提供自动隐藏的工具栏；点击 `+` MUST 在该项目目录新开标签页，即使同路径已有会话。`groupHeader` 以整行 `ActiveHoverRegion` 控制显示，预留按钮槽让计数位置稳定，右键 `Open New iTerm2 Tab` 调用同一动作；仅实际项目目录分组提供入口，Window、Commands 与无路径分组无此入口。`openProjectInNewTab` 直接调用 Bridge `create_project_tab`，校验目录，以自定义初始目录在当前 iTerm2 窗口新建并激活标签页，无当前窗口时创建窗口。收藏的 `openProject` 仍先按精确路径激活已有会话，找不到才调用同一建页逻辑。已静态核对 Swift 和 Bridge；交付报告称 Debug 构建、Python 语法检查和 `git diff --check` 通过，桌面悬停与点击未实测。
