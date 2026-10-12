## Review mode
independent subagent；独立只读审查，未修改文件、任务状态或委派。

## Scope snapshot
检查 Pi 文本判定、模型肯定合并、等待保持、问号样式及配套测试；排除并发归档功能。

前后读取的 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-05.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/pi-question-mark-priority/evidence/snapshot-05.json) 内容一致。提供的 SHA256 为 `658dcac846aa208161d06307e7191b461796a11aa125634bccf0a9ccc74d7094`。未独立复算清单或八个源文件哈希。

## Findings

### TR-3：完成结果排除误伤明确的未来确认门
- **Severity**：P1 / Concern。
- **Location**：["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts):90–99、106、608–624。
- **Issue**：新增结果词排除不区分已经发生的结果与未来动作的终止条件，导致明确待确认的回复被判为完成。
- **Evidence**：静态逐分支核查 `needsReply("确认后我会继续执行，直到测试通过。")`：确认门匹配，动作是“继续”，捕获后缀为“执行，直到测试通过”；新增正则命中句末“通过”，使 `confirmationGate` 为 `false`。该句没有匹配 `requests`，其他返回分支也不成立，最终返回 `false`。新增排除之前，此确认门返回 `true`。现有未来条件正例只覆盖“成功后再继续”，未覆盖“直到测试通过”。此反例未实际运行。
- **Impact**：模型关闭、不可用或返回否定时，这条明确需要用户确认的回答会上报 `finished`，不显示待回复问号，违反 T1/T2。
- **Suggested next step**：主会话执行该反例；让完成结果排除区分明确未来／条件从句与完成叙述，补充文本及生命周期正例，同时保留本轮成功、失败、结束、通过的负例。

此问题需要修复，不属于要求任意自然语言百分之百准确。

## Previous findings
- **TR-1：resolved**。原反例“确认后我提交成功，测试通过。”现被明确结果词排除；新增文本负例和生命周期负例覆盖，作者日志通过。修复具有实体进展；新发现的未来确认漏报另记 TR-3。
- **TR-2：resolved**。最终句否定检查仍局限于最终句；“请勿回复旧问题。按这个范围实现，可以吗？”保持待回复。文本及生命周期测试覆盖，未发现该修复回归。

## Unverified risks
- **快照身份**：工具不能重算哈希；主会话须完成约定的前后复核。此项是当前内容身份的验证前提；若无法确认或发生漂移，则阻断当前快照结论。
- **真实 Laya 与终端 UI**：未验证真实模型准确率及聚焦／刷新后的视觉表现。按接受的验证边界，不单独阻断 Target；mock 不能替代真实验收。
- **Target 状态**：TR-3 是已由源码分支证明的具体行为缺陷，需主会话验证并处理。

## Checks performed
- 读取固定审查合同，先检查实际源码与限定差异，再读取作者证据及旧报告。
- 检查最终句分类、模型肯定合并、等待续租、下一轮清理及导航清理。
- 阅读两个 Pi 测试文件；确认生命周期夹具 mock 归档文件系统与 socket，不调用真实监听器。
- 检查等待样式仅允许问号及 Swift 测试差异。
- 未执行命令或测试；反例来自静态分支核查。

## Author evidence examined
- 文本测试日志：11/11 通过。
- 生命周期测试日志：17/17 通过。
- Xcode 日志：两项定向测试通过；Swift 文件哈希未变仅为作者声明，未独立复算。
- 已读取 Target、Result、Assessment、ledger 和第四轮报告。
- Bridge 自检退出 0、diff 检查通过仅读取作者记录，未复跑。

## Coverage limits
未审计并发归档、Codex、完整应用或已提交范围；未安装用户集成、创建真实 socket、调用真实 Laya 或重启用户应用。