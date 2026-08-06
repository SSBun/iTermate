# 更新日志

本项目的重要用户可见变更记录于此。

## [Unreleased]

## [0.1.2] - 2026-08-06

### Added

- 面板标题栏新增状态刷新按钮；它只重启 Bridge 来清除错误状态，不会重启 iTerm 或任何 Session，真实工作的 Pi 会由 heartbeat 自动恢复。

### Changed

- Pi heartbeat 过期计算改用睡眠期间持续推进的时钟，并在 macOS 唤醒后主动重连 Bridge 以重新验证状态。

### Notes

- 长时间睡眠后状态自动恢复的唯一根因仍在调查；状态刷新按钮是当前的手动兜底。
- 当前构建使用 ad hoc 签名且未经过 Apple notarization。

## [0.1.1] - 2026-08-03

### Fixed

- 修复 Pi 工作状态心跳短连接会短暂清空 `running` 状态、导致工作图标每两秒闪烁的问题。

### Notes

- 这是首个公开 GitHub Release；当前构建使用 ad hoc 签名且未经过 Apple notarization。

## [0.1.0] - 2026-07-29

### Added

- 跟随前台 iTerm2 窗口的原生浮动 Session 面板。
- Session 状态旁显示自动更新的运行时长与完成时间，并可在 Settings 中隐藏或选择 Compact/Detailed 格式。
- 按 Window 或当前路径分组，并支持 Session 激活、关闭、折叠和可调宽度。
- 通过官方 iTerm2 Python API Bridge 同步 Window、Tab、Session、路径和命令状态。
- Pi 与 Codex 状态集成及 Settings 中的安装管理。
- 可选的 Session 完成通知，点击通知可返回对应 Session。
- 原生 Settings、菜单栏入口和应用图标。
- Sparkle 2 自动更新框架、HTTPS appcast 与手动检查更新入口。

### Fixed

- Session 标题变化后无需重启即可刷新。
- iTerm2 不在前台时隐藏浮动面板。
- 每份快照只标记一个全局当前 Session。
- 忽略 iTerm2 模态窗口并保持面板边缘调整光标可靠。
