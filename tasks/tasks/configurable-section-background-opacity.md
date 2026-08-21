# 配置分组背景透明度

Status: Completed (2026-08-21 17:05)
Kind: Task

## Scope

- 包含持久化设置、General Settings 中的原生调节控件、聚焦 Project Path 分组背景渲染，以及该配置的最小回归检查。
- 不改变其他分组、强调色、面板背景或状态动画的颜色与透明度。

## Target
- [x] T1: Settings 页面提供控件，用于调整当前聚焦 Project Path 分组的强调色背景透明度，调整后面板显示随之更新。
- [x] T2: 用户选择的透明度会持久化，并在 App 后续启动时恢复。
- [x] T3: 默认透明度保持当前视觉效果，且其他颜色与透明度行为不变。

## Plan

1. 为聚焦分组背景透明度增加有界、可持久化的用户设置。
2. 在 General Settings 中提供原生调节控件，并让面板渲染直接使用该设置。
3. 添加最小配置回归检查并执行不启动 App 的编译与静态验证。

## Result

- T1: 用户确认真实 App 验收通过；General Settings 的 Focused Section Opacity 控件通过 @Published AppSettings 直接驱动聚焦 Project Path 分组背景。
- T2: 用户确认重启恢复验收通过；testFocusedSectionBackgroundOpacityDefaultsClampsAndPersists 覆盖 TOML 持久化并随 50 项 XCTest 通过。
- T3: 默认值保持 0.05，配置与 setter 均限制在 0...1，唯一渲染调用只替换原硬编码 0.05。
- Review gate: Skipped — 用户未要求独立 Reviewer、对抗审查或双 Agent 审批。

## Verification

- Passed: 用户真实 App 验收通过；Debug build、Swift parse、50/50 XCTest、Bridge self-test、git diff --check 均通过。
