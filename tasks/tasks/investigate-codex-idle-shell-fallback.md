# 调查 Codex 空闲时回退 Shell 图标的原因

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-16 17:11) |
| Artifacts | [Artifacts](../artifacts/investigate-codex-idle-shell-fallback/) |
| Kind | Task |

## Target
- [x] T1: 内部临时线程创建、完成或关闭不替换 Codex 主对话绑定，不导致主对话回退为 Shell。
- [x] T2: 正常新建、恢复、分叉会话及真正退出时仍正确切换状态。
- [x] T3: 不改动 kiro-cli-term，不覆盖已安装集成，不主动重启 App、Bridge 或 Codex；仅静态验证，不运行测试。

## Scope

用户已确认从只读排查转为修复 Codex 包装器的主对话绑定；不修改 kiro-cli-term，不运行测试，不重启 App、Bridge 或 Codex，不改用户安装态。前述现场观察为修复前证据，不代表修复后端到端验证。

## Decisions

- 已确认的代码缺陷：`integrations/status/iTermate-codex.py:85-104` 把所有 TUI 发起的 thread/start、resume、fork 响应无条件替换为唯一 `thread_id`，没有区分用户主对话与内部临时线程；第 110 行随后过滤掉非绑定线程事件，第 137-138 行把绑定线程关闭视为 detached。
- 真实运行证据：包装器 PID 78832 的 ITERM_SESSION_ID 精确指向 `39D02C5F-C984-4422-903B-66E950088BBE`，子 TUI PID 78879 与后端 PID 78837 仍存活。Bridge 实时快照该 Session 为 `running / command`，不是 UI 自行把 agent idle 画成 Shell。已安装 Bridge 文件与仓库文件逐字节一致。
- 只读查询本机 Codex 日志数据库 `/Users/caishilin/.codex/logs_2.sqlite`，限定 `process_uuid=pid:78837:3f094963-30df-48e8-85ba-2e9b1cc8efc8`：16:28:28 收到 startup-thread-start；16:28:38 收到 temporary-structured 的 thread/start 和 turn/start；16:28:43 收到 temporary-structured-unsubscribe；16:29:43 发出 thread/closed；16:34:50 与 16:34:55 仍有 turn/started、turn/completed。临时线程创建日志中的 thread.id 为 `01a143d3-d324-7720-a257-44ab80e2e6ab`。这些观察与临时线程抢占绑定、主对话后续事件被忽略的代码路径高度吻合。
- Shell 回退来源已确认：目标 Session 没有 last prompt；iTerm 变量为 jobName=`zsh (kiro-cli-te`、commandLine=`'zsh (kiro-cli-term)'`、shell=`zsh`。Bridge 的前台任务 fallback 因 jobName 与 shell 不等而判断普通命令仍运行；Agent 所有权释放后即可显示 command running。外层 TTY 为 ttys002，内层包装器与 TUI 为 ttys003，父子关系已核对，未按标题或相邻 TTY 推断身份。
- 排除初始泛化猜测：Bridge 的心跳过期仅删除 running/awaitingInput，不删除 idle/finished；clear_finished_status 对受管 Agent 转为 agent idle。正常空闲并不会按设计直接变成 Shell。
- 证据边界：日志记录了方法与请求身份，但未保存当时完整 WebSocket 响应或 Bridge ACK；没有读取包装器进程内存。因此“临时线程抢占绑定”为代码与现场时间线支持的高可信原因，具体 detached 报告及接收时序未端到端复现，不能声称已捕获所有状态转换。
- 修复方案已按 Codex rust-v0.162.1 权威源码核定：`tui/src/temporary_structured_request.rs` 传入 thread_source，`tui/src/app/thread_title.rs` 将其设为 Feature("thread_title")，`protocol/src/protocol.rs` 将 Feature 序列化为原始字符串，User 为 "user"。按 thread/start 的 threadSource 筛选，而不按请求 ID 前缀或 ephemeral 猜测；省略、null、user 保留原行为，显式非用户来源不登记请求。resume/fork 和退出分支不变。
- 权威来源：https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/tui/src/temporary_structured_request.rs 、https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/tui/src/app/thread_title.rs 、https://github.com/openai/codex/blob/rust-v0.162.1/codex-rs/protocol/src/protocol.rs 。
- 当前自查：逐分支核对请求过滤后，非用户 start 不进入 requests，响应由既有 pop/None 分支忽略，随后异 threadId 事件由既有过滤拒绝；主对话 idle/running/finished/awaitingInput 不被这些事件重写。用户 start（含 ephemeral）与 resume/fork 仍进入既有响应绑定逻辑；主 thread/closed、close 与 relay 未改动。这里是静态路径核对，未执行状态机或测试。
- 新增四组回归用例，覆盖内部来源交错、临时响应先返回、用户新建/恢复/分叉与关闭、非法 params；只做 ast.parse/compile 语法编译，不导入模块、不执行测试。生产代码改动仅六行，原字节转发、Socket、所有权、序列、租约、退出清理均未改动。
- 静态检查：两份 Python 文件语法编译通过，Context validate 通过，git diff --check 无错误；no-index --check 的退出码 1 仅表示两个文件有差异，无空白错误输出。任务变更基线与差异保存在本任务 evidence；snapshot.json 固定当前内容 SHA-256，排除仓库其他未提交修改。
- 限制：未运行任何测试、未重启或替换现场包装器/集成、未进行修复后真实 TUI 验收；源码修复需用户自行重新启动采用新文件的包装器后生效。

## Plan

1. 根据 Codex rust-v0.162.1 的 threadSource 协议区分用户对话与内部功能线程，最小修改绑定入口。
2. 补充交错临时线程与用户会话切换的回归用例但不执行；以源码分支核对、语法编译与 diff 检查验证当前修改。
3. 评估当前结果的评审等级，完成必要评审并披露真实运行验证限制；用户自行重启包装器后观察实际效果。

## Task Summary

**Codex 状态集成**：[`integrations/status/`](../../integrations/status/) 的包装器在登记 thread/start 请求前排除显式非用户 threadSource，保留用户 ephemeral 与合法切换；同目录补充四组回归用例。

**Codex 监控文档**：[`docs/`](../../docs/) 补充主会话绑定过滤语义和固定版本的协议来源。

## Result

- T1: 对照 Codex 0.162.1 权威源码并逐分支静态核对：显式非 user 的 thread/start 在登记 requests 前返回，响应和后续异线程事件被既有过滤忽略，不重写主绑定；源码 hash 37459d5a202e23506b8d1d846bc1181b08e68d5fd3a412d63a09e59e4d1cdb79。未执行测试或现场复现。
- T2: 任务 diff 对比确认 source 缺省/null/user 的 start 以及 resume/fork 仍走原绑定路径；ephemeral 不参与过滤；退出/close/relay 原样保留。四组回归用例已补，ast.parse 和 compile 均通过，未执行用例。
- T3: 命令与任务差异核对：仅修改仓库包装器、回归用例、说明与生命周期记录；未改 kiro-cli-term、用户安装副本，未主动重启进程、未运行测试。
- Review gate: Skipped — R1 四项依据已记录；来源字段的单一前置过滤经权威协议和直接分支对比核对，无独立评审义务。此项不代表运行测试或独立评审。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 单一来源字段过滤，六行生产差异；按固定版本协议与既有响应/事件过滤逐分支比较，非架构或所有权协议变更。
- Snapshot: evidence/snapshot.json sha256:5d78eddd6edb1a7169f4b02f563741b8a3578471033821f47906128e1df8f2db
- Evidence: 任务 Decisions 自查及 artifacts/investigate-codex-idle-shell-fallback/evidence/task-owned.diff、snapshot.json；语法编译、差异空白与 Context 校验通过。
- Result clarity: 用户已确认隔离内部临时线程，保留用户切换和退出；固定版本权威源码确认 threadSource=thread_title 与 user 语义。
- Bounded impact: 仅在登记主绑定候选请求前早返回；响应、事件、状态上报和字节转发未改变，直接消费者的请求匹配与 threadId 过滤已逐分支核对。
- Low risk: 只影响可恢复的状态图标绑定，不发起对话、不修改协议字节或审批、权限、文件数据；不部署到正在运行的会话。
- Sufficient verification: 已用源码直接比较证明非用户请求无法进入绑定且用户分支保留；两文件语法编译、差异检查和快照哈希复核通过。回归用例未运行，真实 TUI 验证未进行，限制已披露。
- Task fingerprint: 3fc279bf2396bb95f1494af4a1b78d4984ca16b348f6c162284bb9f293f409b2

## Verification

- Passed: 最终复核 snapshot.json 全部 SHA-256 一致，两份 Python ast.parse/compile 通过且未执行；请求与响应分支直接比较满足源码 Target，测试与真实运行验收未进行，用户需自行重启采用新源码的包装器。
