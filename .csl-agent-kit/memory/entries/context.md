---
title: 项目基础信息
summary: 项目基础信息的适用条件、实现边界及复查要点。
---

- [2026-11-05] iTermate 是原生 macOS 辅助应用：跟随当前前台 iTerm2 主窗口显示浮动面板，汇总并操作 Window、Tab、Session，以及展示命令或 Agent 的活动状态。
- [2026-11-05] Window、Tab、Session 对应 iTerm2 的原生层级；Project Path 是按 Session 当前目录进行的跨层级分组。Bridge 指随 App 分发并由其管理的 Python helper；Integration 指 Pi 等 Agent 主动报告生命周期的适配资源；Codex 状态由 App 被动观察原生进程与 Session 数据。
- [2026-11-05] `iTermate/` 包含 SwiftUI/AppKit 应用壳、浮动面板、设置、通知和 Bridge 客户端；`iTermateBridge/iTermateBridge.py` 通过 iTerm2 API采集快照，并经 Unix Socket 与 App 通信。`integrations/` 包含 Agent 生命周期适配；`project.yml` 是 XcodeGen 工程配置的规范来源，`iTermateTests/` 覆盖主要纯逻辑与集成边界。
- [2026-11-05] Session 状态MUST 来自 Bridge 或 Integration 的真实观察路径，MUST NOT 根据 Session 名称猜测。Window、Tab、Session 的语义与操作由 Bridge 提供；面板几何在 Swift 侧跟随前台 iTerm2 可见主窗口。Target、资源或构建设置的持久变更以 `project.yml` 为准，并由它重新生成 Xcode 工程。
