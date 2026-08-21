# 为选中项目区域添加轻量背景

Status: In Progress (2026-08-20 15:11)
Kind: Task

## Scope

- 仅为 Project Path 列表中包含当前焦点会话的整个项目分组增加非常轻微的强调色背景。
- 移除项目路径章节标题自身的焦点选中效果；保留焦点 Session 行反馈，不改变未选中项目、折叠交互或项目文件夹自定义颜色设置。

## Target

- [ ] T1: 包含当前焦点会话的整个项目分组区域显示非常轻微的强调色背景
- [x] T2: 未选中章节及已有项目自定义颜色行为保持不变
- [x] T3: 选中项目的章节标题不再应用独立的焦点颜色或背景效果

## Plan

1. 由用户重新运行 App，确认实际明暗主题下的视觉效果。

## Result

- T2: 项目分组整体背景仍仅在 Project Path 焦点分组渲染；未选中分组无背景，自定义项目颜色读写未改动
- T3: groupHeader 已移除 containsFocusedSession 条件及独立背景，图标与标题统一使用 projectColor ?? .secondary
- Review gate: Skipped — 用户未要求独立 Reviewer 审批

## Verification

- Passed: xcodebuild Debug build（CODE_SIGNING_ALLOWED=NO）成功且 git diff --check 通过，未启动 App；整体背景视觉效果待用户实际运行确认
