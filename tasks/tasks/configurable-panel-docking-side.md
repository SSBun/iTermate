# 可配置面板默认吸附方向

Status: Completed (2026-08-11 11:01)
Kind: Task

## Scope

- 包含：左右首选吸附方向、现有 TOML 配置持久化、General 设置入口及布局回退行为。
- 不包含：改变面板间距、宽度、屏幕内覆盖策略或自动启动真实 App。

## Target
- [x] T1: General 设置可选择左侧或右侧作为面板首选吸附方向，默认值保持右侧且选择会持久化。
- [x] T2: 面板优先吸附到用户选择的一侧；首选侧空间不足时自动回退到另一侧。
- [x] T3: 相关配置与布局回归测试通过，且项目可成功构建。

## Plan

1. 用现有配置与布局测试固定默认右侧、左侧首选和双向空间回退结果。
2. 将首选方向接入共享设置状态、General 设置和面板跟随布局。
3. 运行最小相关测试、完整测试与 Debug 构建，并记录未自动执行的真实界面检查。

## Result

- T1: General Settings 新增 Preferred Docking Side Picker；AppSettings 以 panel_docking_side 持久化，缺失键默认 right，配置测试通过。
- T2: PanelFollower 将首选方向传给 PanelLayout；左右首选与反向空间回退测试均通过。
- T3: xcodebuild 全量执行 43 个测试且 0 失败，Debug build 成功，swiftc -parse 与 git diff --check 通过。
- Review gate: Skipped — 用户未要求独立或对抗审查，按项目规则跳过该门禁。

## Verification

- Passed: xcodebuild test（43/43）和 Debug build、swiftc -parse、git diff --check 均通过；未启动真实 App。
