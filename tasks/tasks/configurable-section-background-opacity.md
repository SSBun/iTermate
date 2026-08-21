# 配置分组背景透明度

Status: Blocked (2026-08-21 16:42)
Kind: Task

## Scope

- 包含持久化设置、General Settings 中的原生调节控件、聚焦 Project Path 分组背景渲染，以及该配置的最小回归检查。
- 不改变其他分组、强调色、面板背景或状态动画的颜色与透明度。

## Target

- [ ] T1: Settings 页面提供控件，用于调整当前聚焦 Project Path 分组的强调色背景透明度，调整后面板显示随之更新。
- [ ] T2: 用户选择的透明度会持久化，并在 App 后续启动时恢复。
- [ ] T3: 默认透明度保持当前视觉效果，且其他颜色与透明度行为不变。

## Plan

1. 为聚焦分组背景透明度增加有界、可持久化的用户设置。
2. 在 General Settings 中提供原生调节控件，并让面板渲染直接使用该设置。
3. 添加最小配置回归检查并执行不启动 App 的编译与静态验证。

## Block

- Reason: 项目规则禁止 Agent 自行启动或重启 iTermate；编译通过不能证明 Settings 控件与真实面板视觉交互正确。
- Unblock when: 用户自行重新构建并运行 App，确认 Settings 中显示透明度控件、调整后聚焦 Project Path 分组背景立即变化，且重新打开 App 后设置仍保留。
