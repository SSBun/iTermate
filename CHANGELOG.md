# 更新日志

本项目的重要用户可见变更记录于此。

## [Unreleased]

## [0.1.0] - 2026-07-29

### Added

- 跟随前台 iTerm2 窗口的原生浮动 Session 面板。
- 按 Window 或当前路径分组，并支持 Session 激活、关闭、折叠和可调宽度。
- 通过官方 iTerm2 Python API Bridge 同步 Window、Tab、Session、路径和命令状态。
- Pi 与 Codex 状态集成及 Settings 中的安装管理。
- 可选的 Session 完成通知，点击通知可返回对应 Session。
- 原生 Settings、菜单栏入口和应用图标。

### Fixed

- Session 标题变化后无需重启即可刷新。
- iTerm2 不在前台时隐藏浮动面板。
- 每份快照只标记一个全局当前 Session。
- 忽略 iTerm2 模态窗口并保持面板边缘调整光标可靠。
