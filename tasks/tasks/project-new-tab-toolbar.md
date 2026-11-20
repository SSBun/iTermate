# 项目会话栏添加新标签页按钮

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-19 16:56) |
| Artifacts | [Artifacts](../artifacts/project-new-tab-toolbar/) |
| Kind | Task |

## Target
- [x] T1: 会话计数左侧显示可自动隐藏的加号工具栏
- [x] T2: 点击加号在 iTerm2 新标签页进入对应项目目录

## Execution Log

- 对照截图定位项目分组标题，复用浮动面板的鼠标跟踪与既有 iTerm2 工作目录配置。Debug 构建、Python 语法检查和 `git diff --check` 通过。

## Task Summary

- 项目分组标题在会话计数左侧预留加号位置，悬停显示，并在右键菜单提供同一动作。
- Bridge 的新建动作直接创建标签页，使用分组对应的完整路径，不经过已有会话查找。

## Self Assessment

| 维度 | 评级 | 依据与证据 | 限制 |
| --- | --- | --- | --- |
| 简洁性 | A | 复用现有悬停跟踪、错误显示、项目目录配置和标签页创建逻辑。 | 行内显示需要保留与计数同宽的对齐视图。 |
| 稳定性 | A | 构建和语法检查通过，检查了路径验证、错误回传和已有收藏入口。 | 未实测活动窗口切换。 |
| 完整性 | A | 源码链路覆盖悬停、隐藏、点击、新建和目录传递。 | 未运行桌面端交互和项目测试。 |

## Result

- T1: 标题行悬停时通过独立覆盖层显示加号，移出隐藏，计数保持原位。
- T2: 加号用完整分组路径调用新增 Bridge 动作，复用 iTerm2 自定义初始目录和标签页创建。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 局部界面入口及复用既有终端动作
- Snapshot: snapshot:tasks/artifacts/project-new-tab-toolbar/evidence/2a8d07dd1609ea0c14a908cab461bd5b518c3306d1904f90aedc6a0a8c04d6df.json#2a8d07dd1609ea0c14a908cab461bd5b518c3306d1904f90aedc6a0a8c04d6df
- Evidence: Debug 构建、Python 语法和差异检查通过，静态追踪路径和点击分流。
- Result clarity: 两个行为可直接从界面和动作分支识别。
- Bounded impact: 仅项目分组与明确请求的 Bridge 动作。
- Low risk: 只按用户点击创建终端标签页，使用原生目录配置，无命令拼接或文件写入。
- Sufficient verification: 构建、语法及静态核查覆盖改动，未实测 GUI。
- Task fingerprint: 31d88f518ed6fea3203dd7f46b1e10066c0c007b8a2ee56eb7975c8029736741

## Verification

- Passed: 重新核对源码快照和 git diff --check，Debug 构建及 Python 语法通过。
