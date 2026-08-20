# 添加可配置强调色

Status: In Progress (2026-08-20 15:47)
Kind: Task

## Scope

- 在现有 Appearance 设置中使用原生颜色选择器配置全局强调色。
- 系统默认色与自定义 RGB 色写入现有 TOML 配置；不改变项目文件夹独立颜色。
- 面板显式强调色与原生控件 tint 使用同一设置。

## Target

- [ ] T1: 用户可在设置中选择 iTermate 强调色，并可恢复系统默认强调色
- [x] T2: 强调色选择持久化到配置文件并在重新加载后保持
- [x] T3: 面板中的强调色视觉（包括当前章节背景）统一使用所选颜色

## Plan

1. 在现有配置模型与 `AppSettings` 中增加可空 RGB 强调色，并复用现有颜色转换逻辑。
2. 在 Appearance 设置中加入原生 `ColorPicker` 和恢复系统默认操作。
3. 将面板显式强调色与 Settings/Panel tint 绑定到该设置。
4. 执行不启动 App 的 Debug 构建、配置源码检查和差异检查，再请用户运行确认视觉效果。

## Result

- T2: 源码检查确认 accent_color 的解析、TOML 序列化、AppSettings 发布状态与 setter 使用同一 RGB 字段，并沿用写前重读配置流程
- T3: 源码检索确认面板不再直接使用 Color.accentColor，焦点图标、会话背景、章节背景及控件 tint 均读取 settings.accentColor
- Review gate: Skipped — 用户未要求独立 Reviewer 审批

## Verification

- Passed: Debug macOS xcodebuild 成功且 git diff --check 通过；未启动 App
