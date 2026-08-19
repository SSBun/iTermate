# 添加登录时启动设置

Status: Completed (2026-08-14 10:14)
Kind: Task

## Target
- [x] T1: General 设置中提供 Launch at Login 开关，开启或关闭后 macOS 登录项状态与界面一致。
- [x] T2: 登录项注册或注销失败时，界面恢复系统实际状态并向用户显示错误。

## Plan

1. 使用 macOS 原生登录项 API 作为唯一状态来源。
2. 在 General 设置页加入登录时启动开关与失败提示。
3. 运行 Swift 解析、测试构建与 diff 检查，确认未启动或重启 App。

## Result

- T1: SettingsViews.swift 的原生 Toggle 直接调用 SMAppService.mainApp.register/unregister，并在出现页面及操作后读取系统 status；Debug test build 成功。
- T2: 注册/注销调用由 do/catch 包裹；失败时显示错误 alert，随后按 SMAppService.mainApp.status 恢复开关；Debug test build 成功。
- Review gate: Skipped — 用户未要求独立或对抗式审查。

## Verification

- Passed: swiftc -parse、git diff --check 与 xcodebuild build-for-testing 均通过；未运行会启动 iTermate test host 的测试。
