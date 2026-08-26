# 编写 iTermate 宣讲分享文档

Status: Completed (2026-08-25 14:39)
Kind: Task

## Target
- [x] T1: 生成一篇用于 ProjectHunter、小众软件等平台发帖的 iTermate 宣讲 Markdown 文档，包含软件能力讲解、价格、仓库地址与截屏配图
- [x] T2: 在文档「为什么会有这个项目」部分末尾新增一段：说明为何不使用 tmux / Zellij 或各类 Agent 终端工具，并阐明成熟终端（Ghostty、iTerm2）才是最稳定合适的选择

## Result

- T1: docs/promo-itermate.md 已生成：含核心能力讲解、免费开源价格说明、GitHub 仓库链接、两张真实配图（raw URL 均返回 HTTP 200）+ 截图占位建议；两平台通用 Markdown 格式
- T2: docs/promo-itermate.md 新增「那为什么不基于 tmux / Zellij…」段：含 AI 时代终端工具沦为新手项目论点、成熟终端更稳定合适的立场，及「不重造终端，只做状态屏」定位总结
- Review gate: Skipped — 用户未要求独立审查

## Verification

- Passed: read 复查文档：新段落位于「为什么会有这个项目」末尾、核心能力之前，上下文衔接自然，其余内容未改动
