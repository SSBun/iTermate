# 调查 Codex 会话误显示命令运行图标的原因

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-12 17:21) |
| Kind | Plan |

## Target

- [ ] T1: 基于代码与可获得的运行证据，解释截图中 Codex 会话显示普通命令运行图标而非 Agent 图标的原因，区分已证实结论与未验证假设。

## Scope

- 只读调查代码、已安装集成、进程元数据与真实 Bridge/iTerm2 API；不修改产品或用户安装配置，不重启进程，不运行测试。

## Decisions

- 已确认直接原因是上游分类为 command，而不是 SwiftUI 将 agent 图标画错。两次 Bridge socket 观察中，目标 Session 4BBC8646-7E82-4002-BCC4-5E1E7F36B2DC 均为 running/command；另一个 Codex Session 343DDDEF-3167-4920-9FC1-44C5DAEFDA85 已为 idle/agent。不能把原截图视为所有 Codex 永久无法识别。
- iTerm2 API 对这两个 Session 均返回无最近 Prompt，jobName 为截断的 zsh (kiro-cli-te，commandLine 为带引号的 zsh (kiro-cli-term)，shell 为 zsh。真实 Codex PID 99669 与 80878 分别在内层 ttys011、ttys031，外层 Session TTY 为 ttys010、ttys030；Codex 环境中的 iTerm Session ID 分别精确对应上述 Session。
- Bridge current_foreground_job 将包装器 jobName 与 shell 比较，因名称不相等判为运行中；is_agent_command 仅接受首个可执行文件 basename 为 pi/codex，无法识别这里的 Kiro 包装器。因此在没有 Agent 状态所有权时，foreground fallback 把包装器标成普通 command。
- Agent 图标依赖 setSessionStatus 生命周期上报产生 activityKind=agent。Codex 的四个 iTermate hooks 已存在；已安装 status 脚本与仓库 SHA-256 一致，已安装 Bridge 文件与仓库一致。未发现需要直接重装的证据；磁盘一致不单独证明运行进程加载内容一致。
- iTerm 路径 report_iterm 是单次上报，没有 Ghostty/TTY 分支的持续 heartbeat；exchange 会吞掉连接/超时错误，且不校验返回的 actionResult。因而漏报或状态丢失不具备同等恢复能力。但目前没有目标 turn 的 hook 执行日志，不能断言本次是 hook 未执行、传输失败还是状态后来被清理。
- Swift SessionStatusAnimationTarget 按 activityKind 选择图标，缺失时也回退为 command。排查重点应是上报和状态恢复，而不是替换图标样式。

## Plan

1. 向用户解释已确认的包装器 fallback 与缺失 Agent 状态链路，并标明目标 hook 丢失的具体环节仍未证实。
2. 若后续授权修复，优先补充 Codex 上报确认及可观察错误，检查 iTerm 状态重建/恢复；避免将包装 shell 运行直接解释为 Agent 正在思考。
3. 运行验证需覆盖 Kiro 嵌套 PTY 下 Codex 新轮开始、完成、Bridge 状态重建及普通 shell fallback；启动或重启由用户执行，测试另行授权。

## Investigation Evidence

- 2026-10-12：只读真实 socket 两次，目标 command 状态不变；只读 iTerm2 API 得到两会话 Prompt/前台字段。
- 只输出 Codex TERM_PROGRAM、ITERM_SESSION_ID、TERM_SESSION_ID、CODEX_HOME 等限定环境字段，确认 Session 路由一致；未输出其他环境或凭据。
- 来源：iTermateBridge/iTermateBridge.py 的 is_agent_command、current_foreground_job、monitor_session_foreground_job、set_agent_status；integrations/status/iTermate-status.py 的 report_agent、report_iterm、exchange；iTermate/iTermateApp.swift 的 SessionStatusAnimationTarget 初始化。
- App PID 2875 与 Bridge PID 3000 调查后仍为原进程，启动时间分别为 16:11:29 与 16:11:31。未修改产品、安装配置或执行测试；仅维护当前调查任务记录。
