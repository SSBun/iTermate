# 更新日志

本项目的重要用户可见变更记录于此。

## [Unreleased]

## [0.3.1] - 2026-08-27

### Added

- Settings 新增 Statistics 标签页，以 Total、This Month、This Week、Today 汇总展示成功 Agent 完成次数，数据按本地自然日聚合并持久化。
- 状态菜单新增 Favorite Projects 快捷入口，点击后定位已打开的项目 Session，或以该项目目录新建 Tab/窗口。

### Changed

- 状态菜单重设计：Today 完成次数作为大号主指标，正在运行的 Agent 数量改为次要信息，并显示实时连接状态。

### Notes

- 当前 arm64 构建使用 ad hoc 签名，未经过 Apple notarization。

## [0.3.0] - 2026-08-26

### Added

- 支持跟随前台 Ghostty 窗口，通过官方 AppleScript 展示 Window、Tab 与 Terminal，并可聚焦或关闭 Terminal。
- Pi 与 Codex 可按 TTY 向 Ghostty Terminal 上报实时工作、完成和空闲状态。
- Agents 设置新增可选的 zsh、Bash 与 fish 集成，为 Ghostty 上报普通 Shell 命令状态。

### Fixed

- Ghostty 从 iTerm2 启动时不再误用继承的旧 iTerm Session ID，并确保 Pi 新一轮工作立即显示运行状态。

### Notes

- Ghostty 实时状态图标需要其 AppleScript Terminal 暴露 `tty`；Ghostty 1.3.1 尚不具备该属性，但仍可使用 Session 浏览与操作功能。
- 当前构建使用 ad hoc 签名且未经过 Apple notarization。

## [0.2.1] - 2026-08-21

### Added

- General Settings 的 Appearance 区域新增 Focused Section Opacity 控件，可按 0%–100% 调整当前聚焦 Project Path 分组的强调色背景透明度，并持久化用户选择。

### Notes

- 当前构建使用 ad hoc 签名且未经过 Apple notarization。

## [0.2.0] - 2026-08-21

### Added

- Appearance 设置新增全局强调色选择，并支持恢复系统默认颜色。
- Status Animation 设置可为 Agent 与普通 Shell 的各状态分别选择 Alien、Robot 或 Classic 动画及独立颜色，并显示实时预览。
- Agent 等待用户输入时显示低干扰的静态空闲状态图标。

### Changed

- Project Path 模式为每个 Tab 显示缩进的子分组标题，包括仅含一个 Session 的 Tab。
- 当前 Session 所属项目改为使用轻量整组背景，不再单独高亮项目标题。

### Notes

- 当前构建使用 ad hoc 签名且未经过 Apple notarization。

## [0.1.5] - 2026-08-19

### Added

- General Settings 新增 Launch at Login 开关，通过系统登录项控制开机自启。
- Project Path 分组模式下，同一 Tab 内两个及以上的 split-pane Session 会以 "Tab N" 子分组标题聚合并缩进显示；当前聚焦 Session 所属的项目组标题会以强调色高亮。

### Changed

- Window/Tab/Project Path 分组标题改为粗体显示。

### Notes

- 当前构建使用 ad hoc 签名且未经过 Apple notarization。

## [0.1.4] - 2026-08-13

### Added

- General Settings 新增面板默认吸附方向，可选择优先停靠在 iTerm2 左侧或右侧。

### Fixed

- 修复调整 iTerm2 窗口大小或从睡眠唤醒后，空闲 Session 被批量误报为运行中并随后误报完成的问题。
- 修复非激活面板左右边缘保持箭头光标的问题，并确保两侧均可可靠拖动调整宽度。

### Notes

- 当前构建使用 ad hoc 签名且未经过 Apple notarization。

## [0.1.3] - 2026-08-09

### Added

- Session 状态改用点阵动画区分 Agent 与普通命令的运行、成功、失败和未知结果。
- Project Path 分组支持 Pin、Favorite 与自定义颜色。
- 面板新增 System/Dark/Light 与 Blur/Opaque 六种背景样式。

### Fixed

- 未启用 Shell Integration 时也能通过 iTerm2 前台任务变量观察普通命令状态，并避免 Agent 外层进程退出被误报为普通命令完成。

### Notes

- 当前构建使用 ad hoc 签名且未经过 Apple notarization。

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
