# 自定义项目文件夹

Status: Completed (2026-08-07 11:08)

## Scope

- 包含：仅为 Project Path 分组下的精确项目文件夹路径提供 Pin、Favorite 与自定义颜色。
- 包含：将项目文件夹定制持久化到现有 `~/.iTermate/config.toml`。
- 不包含：Session 级定制、项目别名、启动器或跨不同路径合并项目。

## Target

- [x] T1：Pin 可切换并持久化，已 Pin 的项目文件夹稳定排在未 Pin 项目之前。
- [x] T2：Favorite 可切换并持久化，项目文件夹标题显示明确且可访问的收藏标记，但不改变 Pin 语义。
- [x] T3：用户可用系统颜色选择器设置或清除项目文件夹颜色，颜色持久化并显示在对应文件夹标题上。
- [x] T4：现有 Window/Project Path 分组、折叠、Session 激活与关闭行为保持不变，相关测试与 macOS 构建通过。

## Plan

1. 在现有 AppSettings 配置模型中加入按精确路径保存的项目文件夹定制。
2. 在 Project Path 标题与上下文菜单中接入排序、标记、颜色选择及清除操作。
3. 添加最小持久化和排序回归测试，并运行相关测试与构建。

## Result

- T1：Project Path 分组接受持久化的精确 Pin 路径集合，并在原有路径排序前优先排列 Pin 项目；`testGroupsSessionsByWindowOrExactPath` 验证 Pin 排序通过。
- T2：项目文件夹标题上下文菜单可切换 Favorite，标题显示星标且可访问性标签包含 favorite；持久化回归测试确认重建 `AppSettings` 后仍保留。
- T3：项目文件夹标题上下文菜单使用标准 SwiftUI `ColorPicker` 设置系统颜色并提供 Clear Color；颜色同时应用于文件夹图标和标题，复杂路径的设置、恢复与清除测试通过。未启动真实 App，以免改变当前 Bridge 安装态；颜色面板与最终视觉仍需人工窗口确认。
- T4：仅 Project Path 的有效文件夹提供定制，Unknown Path 与 Window 分组保持原行为；Swift 解析、`git diff --check`、39/39 全量测试及 Debug build 均通过。
- Review gate: Skipped — no explicit user request.
