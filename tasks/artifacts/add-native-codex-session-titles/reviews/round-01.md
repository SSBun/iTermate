# Task Review Round 01

- Task: `add-native-codex-session-titles`
- Review mode: independent subagent
- Run identity: `/root/native_codex_title_review`
- Reviewed snapshot: `sha256-manifest:ca3283a3,a30d4b1d,c07868cb,e2858022,26c2958f,299f9338,7fdbff10,e3878875,4a2f2614`

## Reviewer Feedback

Review mode: independent subagent  
Reviewed scope / snapshot: 已核对任务要求、指定实现与相关调用链；九个目标文件首尾 SHA-256 均与给定清单一致（`ca3283a3,a30d4b1d,c07868cb,e2858022,26c2958f,299f9338,7fdbff10,e3878875,4a2f2614`）。  
Findings: TR-1 — Severity: Concern；Location: `iTermate/ItermBridge.swift:1365`、`:1381`、`:1415`；Issue: 同一 TTY 的旧标题任务被新任务替换后，旧任务完成时会无条件清空 `codexTitleTasks[tty]`；Evidence: 新 excerpt 会取消旧任务并将新 `Task` 写入相同字典槽，但旧任务随后进入 `finishCodexTitleRequest` 时，无论身份/requestID guard 是否通过，`defer { codexTitleTasks[tty] = nil }` 都会删除该槽中的新任务句柄；Impact: 新任务失去取消所有权，后续 Session/进程切换或 `stop()` 无法取消它，快速连续完成多轮时还可能并行积累本应被替代的本地 Ollama 请求。现有 process/TTY/Session/requestID guard 可阻止旧结果写入错误行，因此未发现跨 Session 标题写入；Suggested next step: 仅在字典槽仍归属于当前 `requestID` 时清除任务，或让任务槽同时保存 requestID 并按所有权移除，并补一个“旧请求晚于替代请求结束”的覆盖。  
Unverified risks: 未运行新增测试，也未启动 App 或连接真实 Ollama 验证标题在面板中的端到端呈现；影响 T1/T2 的运行时确认，但鉴于这是明确限制，标记为不阻塞静态目标核对。  
Checks performed: 先比对任务 Target、修订与约束；逐段检查 rollout 解析与 1 MiB/每消息边界、进程/TTY/终端 Session 绑定、标题调度/重试/清理、Local Ollama 固定回环请求、AppDelegate 注入、Pi 标题调用路径、面板显示覆盖、文档与 focused tests；只读抽查本机 rollout 的结构类型，确认根 Session `source` 为字符串、生命周期含 `task_started/task_complete/turn_aborted`，可见消息使用 user/input_text 与 assistant/output_text；未读取或输出会话正文；首尾复验 SHA-256 无漂移。  
Author evidence examined: 任务记录中的 `git diff --check` 通过、Debug build `BUILD SUCCEEDED`、build-for-testing `TEST BUILD SUCCEEDED`；这些为继承证据，未由本 Reviewer 重跑；已确认作者明确说明 focused tests 未执行。  
Coverage limits: 按授权未运行任何测试、未启动/重启 App、未做真实 Ollama 与面板交互；脏工作树中的非指定历史改动未纳入本轮审查。
