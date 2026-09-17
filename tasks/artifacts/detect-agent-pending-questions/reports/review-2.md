## 审查模式与范围

**Review mode: independent subagent。** 本轮仅作只读反馈，未修改文件或任务状态。

审查五个产品源码文件、新增 Pi 测试源码及相关未修改调用方，对照：
- ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/product-2.diff"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/product-2.diff)
- ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/review-snapshot-2.txt"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/detect-agent-pending-questions/evidence/review-snapshot-2.txt)

声明基线：`0c79ef67e35e86646cf857e954c41c4e4c368002`。  
差异 SHA256：`0db2113c9398fe24114436833199e2f59bfdf531bdf6f1f1aff98d0b6e8dc40f`。

## Findings

**无。No issues found.**

未发现当前审查范围内有源码证据支持的新问题。具体确认：
- UI 提示覆盖基础生命周期；关闭提示不会直接宣告成功。
- 等待态具有续报和失效路径；聚焦清除仍只处理 `finished`。
- 静态问号与动画分支分离，包含帮助文案和无障碍标签。
- 完成通知与计数仍要求 `running → finished`；等待状态不直接触发成功行为。
- 状态请求不包含问题正文。

## Unverified risks

1. **真实运行验证仍缺失，涉及 T1、T2 的运行效果。**  
   未执行提示取消、续跑、租约超时、故障恢复或双终端 UI 观察。新增测试仅覆盖文字识别样例，没有实际执行。按已接受的源码交付边界，**不阻断本轮源码审查**；但不能据此声称运行验收通过。

2. **快照身份依赖主会话校验。**  
   已对照实际修改段，并在结束前复读快照声明及六个文件的关键内容，未观察到漂移。只读工具不能独立计算哈希或核验 Git HEAD。**主会话须确认前后哈希一致；若不一致，将阻断当前快照的 Target 验证。**

## Previous findings

- **TR-1：resolved（源码层面）。**  
  ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，207–215、242–247 行：使用 `agent_start/agent_end` 维护运行标记，树导航不再依赖事件期间暂时为 false 的 `ctx.isIdle()`。已回读本机 Pi 树导航调用方，原内部 busy 标记问题不再影响该判断。

- **TR-2：resolved（针对已确认的否定等待路径）。**  
  ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，62–67 行：否定过滤已覆盖首轮中英文反例，并先于肯定等待匹配执行。  
  ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.test.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.test.ts)，10–19 行固化相关负例；未执行。不将此判断扩展为自然语言识别零误报保证。

- **TR-3：resolved（源码层面）。**  
  ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，107–131、146–195 行：报告区分实际 ACK 与失败；未确认转换重发完整状态，发送前及续报安排前检查 generation。  
  ["/Users/caishilin/Desktop/personal/iTermate/iTermate/TerminalStatusServer.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/TerminalStatusServer.swift)，426–438 行及 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift)，865–869 行，使 Ghostty ACK 表示 registry 实际接受。  
  ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)，163–169、544–565 行，同样返回实际接受结果。旧心跳保护仍保留；首个转换丢失不再导致永久只发被拒绝的心跳。未进行故障注入。

- **TR-4：resolved（源码层面）。**  
  ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)，1335–1347 行：自检先断言旧运行心跳被拒绝，再建立合法运行转换及心跳租约，消除了此前索引缺失记录的确定性冲突。未执行自检。

本轮没有需要保留为 `substantive progress` 或 `no progress` 的既有发现，也未分配新 TR 编号。

## Checks performed

- 对照原始需求、有效决策、Target 和实际差异。
- 静态追踪 Pi 生命周期、UI 提示合并机制、树导航、ACK 重试及 generation 隔离。
- 检查两端协议校验、等待租约、恢复、聚焦清除与状态映射。
- 检查通知、成功计数、SwiftUI 行身份和静态问号调用方。
- 检查新增测试源码与 Bridge 自检修正。
- 未运行测试、构建、事件回放、应用、安装替换或嵌套 CLI。

## Author evidence examined

- ["/Users/caishilin/Desktop/personal/iTermate/tasks/tasks/detect-agent-pending-questions.md"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/tasks/detect-agent-pending-questions.md)：Implementation Checks、Result、Review Assessment 和既有 ledger。
- ["/tmp/iTermate-pending-questions-build.log"](file:///tmp/iTermate-pending-questions-build.log)：169 行记录 `BUILD SUCCEEDED`；133 行为未链接 AppIntents 的元数据提取警告。
- TS strict/noEmit、Python AST 和差异检查通过来自作者记录，**本审查未重新执行**。

## Coverage limits

结论限于当前源码及所读调用方，不是全仓审计，也不证明用户安装态已升级或实际 UI 行为已通过。本轮没有确认需要整改的发现；运行验证和最终快照身份确认仍由主会话按既定边界处理。