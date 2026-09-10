# 添加终端独立面板开关

Status: Completed (2026-09-10 10:48)
Kind: Task

## Scope

- 包含：为 iTerm2 与 Ghostty 分别保存面板启用偏好，并让浮动面板实时服从当前前台终端的对应偏好。
- 不包含：更改菜单栏状态、终端数据采集、Session 内容或操作行为。

## Target
- [x] T1: 设置界面提供分别控制 iTerm2 与 Ghostty 是否启用 iTermate 整体面板的独立开关。
- [x] T2: 关闭任一终端的开关后，iTermate 面板不再为该终端显示或跟随，另一终端的行为不受影响。

## Plan

1. 增加默认启用且相互独立的终端面板持久偏好。
2. 在常规设置中提供两个终端的独立开关。
3. 让面板可见性服从前台终端偏好，同时保留终端数据源切换。
4. 完成构建、静态检查与强制审查闭环。

## Result

- T1: SettingsViews.swift 现已提供两个独立 Toggle，并将默认启用的 iterm2_panel_enabled 与 ghostty_panel_enabled 分别持久化；Debug app build 成功。
- T2: PanelFollower 在保留前台终端数据源切换后，按该终端偏好决定隐藏或显示面板；两个偏好字段及写入路径相互独立。
- Review gate: Passed — 独立 reviewer 完成首轮只读审查：Findings none；未做真实 UI smoke check 的风险不阻止源码级 Target 验证。

## Verification

- Passed: 审查后重新执行 Debug app build，结果 BUILD SUCCEEDED；git diff --check 与 Context validation 均通过。按规则未运行测试或启动 App，真实 UI smoke check 留给用户。
