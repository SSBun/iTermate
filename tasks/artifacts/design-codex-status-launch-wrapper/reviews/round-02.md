# 独立审查记录 02

## 主会话归档信息

- Task：design-codex-status-launch-wrapper
- Round：02
- Mode：independent subagent
- Run：ca582fbc-1808-4b7c-8b95-f5e073d77b02
- Snapshot：sha256:e79a5d8d104b5f318dc0d66a5563767b9cf2983857bd6ca2cba4cd684d651da3
- 以下为 Reviewer 返回的原始用户可见反馈；主会话处置另记。

---

## Review mode
independent subagent；独立只读审查，未编辑、执行 CLI、运行测试或委派。

## Reviewed scope / snapshot
先对照原始要求、有效修订及 T1/T2 检查实现，再阅读作者证据和前次反馈。范围为任务指定的10个产品文件及直接相关调用路径，不将整个工作区差异归入本任务。

快照：`sha256:e79a5d8d104b5f318dc0d66a5563767b9cf2983857bd6ca2cba4cd684d651da3`。

依据任务独立差异和当前源码审查；结束前重新读取 manifest 身份字段，声明未变，但未独立复算文件 hash。

## Findings: none

No issues found.

## Previous findings
**TR-1**：resolved。

- **代码证据**：["/Users/caishilin/Desktop/personal/iTermate/integrations/status/iTermate-codex.py"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/status/iTermate-codex.py) 第242–300行，在覆盖在途状态前重试未确认的 finished，并对关闭时 detached 执行有界 ACK 重试；拒绝后停止该次重试，不重新 claim。重试保留事件身份、递增 sequence。
- **退出预算**：第428行等待报告线程9秒，为两段3秒重试及既有传输等待留出余量。3秒是重试启动期限，最后一次 exchange 可能跨过该期限；未发现因此导致当前退出等待提前截断的证据。
- **回归证据**：["/Users/caishilin/Desktop/personal/iTermate/integrations/status/test_codex_wrapper.py"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/status/test_codex_wrapper.py) 第242–361行覆盖在途完成首次失败、detached 首次失败后恢复、永久故障超时仍释放、拒绝不重抢，以及丢失 ACK 不恢复已读完成标记。作者本轮日志记录这些测试通过。
- 检查了修复对关闭队列、状态覆盖、所有权和接收端去重的影响，未发现新的实质回归。

## Unverified risks
- **快照绑定，影响 T1/T2，条件性阻塞**：只读工具未提供 hash 计算能力。主会话仍须复核全部范围源码及证据 hash；复核前不能将本结论绑定为已验证的最终内容。发现漂移须刷新证据和审查。
- **现场验收，影响 T1，不阻塞本次限定交付**：没有真实模型轮次、原生 TUI 审批或现场图标验收。原生探针不能证明这些行为；当前文档已明确披露，不能宣传为完成。
- 未独立验证构建产物与源码的逐字节一致性；该项仍依赖主会话报告及最终复核。

## Checks performed
- 静态检查 thread 关联、轮次过滤、等待/失败/中断映射、透明转发、关闭并发与 ACK 重试。
- 检查 reporter 的传输期限、事件身份、sequence，以及 Bridge 的所有权、去重和 awaitingInput 续租路径。
- 检查启动参数限制、真实 iTerm2 Session ID 门禁、专属进程清理。
- 检查安装、更新、卸载、资源打包差异及文档能力边界。
- 阅读回归测试实现；未自行执行测试或构建。

## Author evidence examined
阅读本轮状态、Bridge、Swift 测试日志，分别记录 **46、30、10项通过，共86项**；检查构建日志的成功标记和包装器资源复制记录。

阅读原生探针脚本及本轮日志：只证明代理握手、initialize、空 loaded-thread 列表和专属后端退出，不证明真实生命周期或审批验收。

## Coverage limits
安装器和工程配置主要按任务差异及相关源码审查，未逐行审计全部未改内容；未扩展到旧 hooks、Pi 或全项目。未重跑作者检查、复算 hash、启动用户会话或替换现有 App/Bridge。
