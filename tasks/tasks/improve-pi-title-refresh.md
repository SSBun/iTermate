# 优化 Pi 当前任务标题更新可靠性

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-14 18:05) |
| Kind | Task |

## Target
- [x] T1: 有历史对话的 Pi 会话启动或重载后，可在安全空闲时补生成当前任务标题，无需额外发送消息。
- [x] T2: 标题生成失败可诊断且可恢复，不因一次失败永久跳过当前内容，也不产生无限模型重试。
- [x] T3: 连续交互或会话切换时不发布过时标题，保留已有有效标题且不干扰正常对话与状态上报。

## Scope

- 只优化 Pi 标题链路与相应文档，不扩展 Codex，不覆盖用户安装、不重启现有进程，不运行测试。

## Decisions

- 用户已确认本任务完整 Target。启动/重载、分支切换和成功回复结束后异步安排生成，初始延迟1.5秒；忙碌或存在待处理消息、交互提示时只等待，不调用模型。
- 成功内容去重与尝试预算分离，同一连续未变摘要输入最多尝试两次，失败后10秒重试一次；手动刷新不受自动预算限制。取消也占已开始的尝试预算，不因取消而无限补发。
- 自动失败通过 Pi 非阻塞通知显示脱敏类别；手动失败仍交给面板反馈。已有标题保留，跨Session/分支不复用旧标题。

## Plan

1. 补齐空闲调度、有限重试及失败诊断，保留请求、Session与leaf校验。
2. 同步使用说明与对应Context Pack。
3. 运行TypeScript类型检查与差异检查，复核生命周期与预算路径，不运行测试或真实模型请求。
4. 完成独立只读审查后再作最终验证；审查工具不可用时保留改动并阻塞，不以自查替代。

## Task Summary

**Pi 集成**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 增加启动与分支恢复的空闲标题生成、成功去重、有限重试及脱敏失败提示；取消同时清理定时器，发布前继续核验请求及会话身份。

**使用文档**：在 ["/Users/caishilin/Desktop/personal/iTermate/docs/pi-session-archives.md"](file:///Users/caishilin/Desktop/personal/iTermate/docs/pi-session-archives.md) 说明补生成、模型额度、失败重试与取消行为。

## Self-check

- `tsc -p tasks/artifacts/add-vela-decision-provider/evidence/tsconfig.json` 退出码0；仅类型检查，没有执行测试。复用现有配置，其files包含集成及原有类型检查输入。
- `git diff --check -- integrations/pi/iTermate-integration.ts docs/pi-session-archives.md` 通过。
- 静态逐路径复核：启动/分支事件安排延迟任务；空输入不请求模型；自动在途请求不重复启动；仅成功写入completedExcerpt；同一输入达到两次停止；手动刷新取消待执行自动请求；新轮次、导航、退出清理timer与controller；返回时复核request、active、空闲、pending、Session与leaf。
- 未执行自动化测试、真实模型调用、重载或UI运行验证；定时与并发行为只有源码自查和类型检查，仍需独立审查。
- 用户安装的集成SHA-256保持 `5735e30786f685f524f32637b1741512a4508121d23af6ec2c88295f4a3cf445`，未覆盖用户安装态。未主动启动或重启App、Bridge或Pi。

## Block

- Reason: 当前会话没有可用的subagent委派工具，无法启动本次异步生命周期改动所需的独立只读Reviewer；未启动审查，不存在审查通过证据。
- Unblock when: 在提供fresh/read-only subagent工具的会话中恢复任务，复核当前内容与自查证据，完成独立task-review和必要整改后再最终验证。

## Result

- T1: 源码已接入session_start/session_tree空闲调度，空输入不调用模型；tsc通过。未运行实际重载、模型请求或UI验证，行为仍待独立审查。
- T2: 源码分离成功去重与两次尝试预算，10秒退避并显示脱敏错误；tsc通过。未执行定时器或失败场景测试，不能据此宣称运行行为已验证。
- T3: 源码复核取消清理timer/controller，发布前检查请求身份、Session、leaf、空闲及排队消息；diff检查与类型检查通过。未执行并发场景运行验证，仍待独立审查。
- Review gate: Required — R2异步生命周期修改需要fresh/read-only task-review；当前工具集中没有subagent，尚未启动审查。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 异步定时、重试预算与生命周期取消互相影响；类型检查不足以证明所有并发路径，必须独立审查。
- Snapshot: integrations/pi/iTermate-integration.ts SHA256=161f4856a09e9c9ad1202baf1338127a079d63bcffde39ce5d08f5604ec58eaf; docs/pi-session-archives.md SHA256=af7d672256b5de966762ba6e02818a3848f4e369c1f85733e72f5d6fb6b0ac8a; scoped unstaged changes; no task-owned staged files
- Evidence: 本任务Self-check及T1-T3 Result；tsc与git diff --check通过，未运行测试/真实模型/安装态验证。
- Task fingerprint: 8d13b10377d30b10b23adf675aa210e48b46aa9e3f424820b0b32e8ff81ad0bc
