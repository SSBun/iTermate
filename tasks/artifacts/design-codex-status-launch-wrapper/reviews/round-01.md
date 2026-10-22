# 独立审查记录 01

## 主会话归档信息

- Task：design-codex-status-launch-wrapper
- Round：01
- Mode：independent subagent
- Run：e8d42de0-bf83-4261-928c-91c29ab91c0a
- Snapshot：sha256:5d3682e8cb778f0bce05205ecfe3ff6fa5e6c602a77b9597f8285c6f2b94e138
- 以下为 Reviewer 返回的原始用户可见反馈；主会话处置另记。

---

## 审查模式与范围

独立只读子代理；未修改文件、运行测试、启动 App/Bridge 或委派。

依据原始请求、有效修订及 T1/T2，审查任务独立 diff、包装器完整实现、相关 reporter/Bridge 接收路径、安装资源变更及测试。快照声明身份：`sha256:5d3682e8cb778f0bce05205ecfe3ff6fa5e6c602a77b9597f8285c6f2b94e138`。未将工作区其他改动归入本任务。

## Findings

### TR-1 — P1：退出时最终上报没有可靠重试

- **Location**：["/Users/caishilin/Desktop/personal/iTermate/integrations/status/iTermate-codex.py"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/status/iTermate-codex.py)，`close()` 第139–156行、`report_status()` 第239–274行。
- **Issue**：关闭后，最终状态只尝试发送一次，未确认送达便退出；尚未确认的完成状态也可能被关闭操作丢弃。
- **Evidence**：`report_status()` 先从队列弹出快照，再调用 reporter；发送失败只设置 `acknowledged=False`。如果此时发生关闭，`close()` 只能保留仍在队列中的 finished，无法保留已经弹出但发送失败的 finished；之后消费 detached 时，`if closed: return` 无条件退出，不执行前面的15秒重试机制。
- **Impact**：断连或退出时发生一次短暂 Bridge 传输失败，就可能丢失成功/失败信息或所有权释放。此前处于 idle/finished 的状态没有运行租约兜底，可能继续残留，与 T1 的可靠监控目标不符。
- **Suggested next step**：显式保留尚未确认的最终状态，并在有限退出期限内重试；最终 detached 也应确认成功或达到明确超时后再结束。补充“finished 已出队但首次发送失败时关闭”和“detached 首次失败、随后恢复”的确定性回归。

此项需要主会话核实并修复；没有既有 TR 条目需要结转。

## Unverified risks

- **快照一致性**：已读取 manifest，并在结束前再次读取身份字段，但工具不能计算源文件及证据 SHA256，不能独立证明读取内容始终匹配声明快照。影响 T1/T2；主会话完成全量 hash 复核前，当前内容绑定验证仍有缺口。
- **真实生命周期验收**：没有真实模型轮次、真实 TUI 审批及现场 UI 证据，无法确认原生事件时序和最终用户呈现。影响 T1；这是明确披露的验收边界，不单独作为本次限定交付的阻塞项，也不能据此声称现场验收完成。

## Checks performed

- 静态检查选中 thread 关联、轮次过滤、等待与结束映射、帧透传、并发关闭、报告 ACK/所有权、参数限制及进程清理。
- 核对 Bridge awaitingInput 续租、失败退出状态及 detached 清理路径。
- 检查安装、更新、卸载和工程资源变更；阅读相关测试，确认现有关闭测试未覆盖 TR-1 的恢复情形。
- 未自行执行测试或构建。

## Author evidence examined

读取作者的状态测试、Bridge 测试及 Swift 测试日志，分别记载 **41、30、10项通过**；读取独立 XCTest runner、原生探针日志及部分协议形状，检查构建日志成功标记。

原生探针仅证明握手、initialize、空 thread 列表及专属后端退出；不是模型生命周期或真实审批验收。

## Coverage limits

未独立复算 hash、重跑81项测试或构建；未执行真实 Codex 对话、现场安装或 UI 检查。工程及安装器主要按任务差异和相关调用路径审查，未扩展为旧 hooks、Pi 或整个项目审计。
