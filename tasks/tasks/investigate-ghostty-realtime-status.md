# 实现 Ghostty 实时 Session 状态

Status: Completed (2026-08-26 11:20)
Kind: Plan
Parent: commit-and-release-v0-3-0

## Scope

- 包含：Ghostty Terminal 的 TTY 能力探测与身份映射；Pi/Codex Agent 生命周期；显式启用的 zsh、Bash、fish 普通命令 hooks；状态初始同步、优先级、心跳与恢复；现有状态 UI 和通知复用。
- 排除：fork 或修改 Ghostty；用标题、工作目录、屏幕文本或进程名称猜测状态；透明穿透 tmux 或交互式 SSH 的内部生命周期。

## Target
- [x] T1: 具备 AppleScript TTY 能力的 Ghostty Terminal 能在现有 UI 中准确显示 Pi/Codex Agent 的 idle、running、finished 与退出结果，且 Agent 状态优先于普通命令状态。
- [x] T2: 用户可显式启用 zsh、Bash、fish hooks，使普通顶层 Shell 命令实时显示 running、finished 与真实 exit status；未启用时不伪造状态。
- [x] T3: 状态通过 TTY 唯一关联到 Ghostty Terminal，并在启动、重连、系统唤醒、心跳过期和 Terminal 重建后清除或恢复为可证实状态。
- [x] T4: Ghostty 1.3.1 的现有基础功能和 iTerm2 状态行为保持可用；缺少 TTY、权限被拒或映射歧义时安全降级，tmux/SSH 内部状态保持未知。

## Decisions

- Ghostty 1.3.1 的公开 terminal 属性只有稳定 UUID、标题和工作目录；它不能可靠向独立 App 提供命令 running、finished、exit status，也不能把 hook 的 TTY 精确映射到 AppleScript terminal。该版本继续支持基础层级与操作，但状态必须保持未知。
- Ghostty 内部从 OSC 133 `C/D` 实时获得命令开始、结束和退出码，并通过 `command_timer` 与 `command_finished` action 使用这些数据；AppleScript、App Intents 和跨进程 IPC 未暴露该链路。裸 `OSC 133;D` 当前还会被折算为退出码 0，不能把它当作可靠“成功”。
- 上游 commit `9a9002202b8767e6e99c2bb48fad09fc0ae02870` 已为 AppleScript 与 App Intents 加入 `pid`/`tty`，PR #11922 当前归入 1.4.0 milestone，但尚未进入 1.3.1。实现必须探测字段能力，不能只比较版本号。
- `tty` 是 surface 与本地 telemetry 的可靠关联键；AppleScript `id` 继续作为 UI 主键。名为 `pid` 的字段底层来自 `tcgetpgrp`，实际是会变化的前台 PGID，只能作被动提示，不能作身份或 Agent busy 真值。
- `GHOSTTY_SURFACE_ID` 是上游 `main` 注入的 core `u64`，与 AppleScript UUID 不同且没有公开 macOS 转换接口；`libghostty-internal` 与 `libghostty-vt` 也不能附着到另一进程中已运行的 Ghostty surface。
- 最小可靠产品方案采用能力分级：有 `tty` 时，以一个终端无关的本机 telemetry endpoint 接收状态；Pi/Codex 使用原生生命周期，普通命令仅由显式启用的 shell preexec/precmd 或 postexec hook 报告 `$?`。Agent 生命周期优先于普通 shell 状态。
- 严格被动模式最多提供 `surfaceAlive` 与明确标为启发式或未知的 `foregroundBusy`；不得承诺可靠 finished、exit status 或 Agent settled。tmux 与 SSH 必须显示为观测边界，内部状态需要对应 pane 或远端 hook。
- 若向 Ghostty 上游贡献，最小完整接口应是带单调 sequence、初始 snapshot、started/finished 事件和可空 exit status 的 per-terminal 状态流；仅增加可轮询属性会漏掉两次轮询之间的短命令。
- Ghostty 从 iTerm2 启动时可能继承陈旧的 `ITERM_SESSION_ID` 与 `TERM_SESSION_ID`，同时正确设置 `TERM_PROGRAM=ghostty`；Integration 只有在 `TERM_PROGRAM=iTerm.app` 时才能信任 iTerm Session ID，否则必须按控制 TTY 路由。
- 用户截图中的圆圈是 Session 焦点标记，不是活动状态图标；红色错误只能来自 Ghostty action 前的存活判断，而同一时刻系统进程与 bundle ID 均证明 Ghostty 正在运行，因此该判断存在假阴性。
- Ghostty 存活判断改为复用面板前台识别所依赖的 `NSWorkspace`，并以其 running applications 作为非前台补充；不改变 Ghostty 未运行时不得被 iTermate 自动启动的边界。

## Plan

1. 保留 iTerm2 现有数据与状态链路，并让 Ghostty 快照按运行时能力携带可用的 TTY identity；没有该能力时继续只提供基础层级与操作。
2. 建立 App 自有的本机 telemetry 接收与状态合并，覆盖来源优先级、短事件顺序、心跳过期、唤醒、Terminal 重建、TTY 重用和歧义拒绝。
3. 让 Pi 与 Codex 在 iTerm2 中保持原协议，在可映射的 Ghostty TTY 中报告完整 Agent 生命周期并恢复运行心跳。
4. 提供显式安装和可逆卸载的 zsh、Bash、fish hooks；只在启用后报告顶层普通命令的开始、完成和真实退出码，并保留用户现有 shell 配置。
5. 以静态检查、构建、协议自检和不启动 App/Bridge 的手工边界检查验证兼容性；需要运行中 Ghostty 的 UI 结果由用户重建后确认。

## Result

- T1: 用户确认真实 Ghostty 中 Session 操作不再误报，Pi 在 /reload 后呈现 idle → running → finished；Codex 与 Pi 的 TTY 路由已通过受控 smoke。
- T2: 用户确认 Ghostty zsh 的 sleep 5 呈现 command running → success；zsh/Bash 静态语法及三类 shell 的托管安装保留行为已验证。
- T3: TTY 唯一映射、事件顺序、Agent 优先级、心跳过期、唤醒与 Terminal identity 重建由 TerminalStatusRegistry 检查覆盖，修复后 Debug 构建通过。
- T4: Ghostty 1.3.1 无 tty 时保持未知；iTerm2 路由与 Ghostty 陈旧 iTerm 环境变量场景均通过受控 smoke，存活判断改用 NSWorkspace 并保留未运行时不自动启动边界。
- Review gate: Skipped — 用户未要求独立 Reviewer、对抗审查或双 Agent 审批。

## Verification

- Passed: 用户完成真实 Ghostty Shell/Pi UI 验收；53/53 XCTest 在最终存活判断改动前通过，改动后 Debug build 与原生 Ghostty 存活探测通过。
