# Review round 01

- Schema: task-review-report/v1
- Task: implement-attention-status-menu
- Round: 01
- Snapshot: snapshot:tasks/artifacts/implement-attention-status-menu/evidence/d5a2b58c3849774a27a8facf772ce1e8ea4301070969b118bd40571c59007ad8.json#d5a2b58c3849774a27a8facf772ce1e8ea4301070969b118bd40571c59007ad8
- Task fingerprint: fdd98526e1399fa7b053844fbc1c5a97464076897cf26f380a2e190ab1c13538
- Outcome: findings
- Mode: independent subagent
- Run: 31e93af8-b9df-40d5-b1a2-4a5769f0ae4d

## Reviewer feedback

## Review

**Review mode**: independent subagent  
**审查范围**：本任务六项交付及直接消费者；快照标识为 `d5a2b58c3849774a27a8facf772ce1e8ea4301070969b118bd40571c59007ad8`。未将并发任务改动归入本任务。

### Correct

- 四分类、248pt 固定滚动、紧凑统计、收藏及设置退出入口均有源码实现。
- 批量已读仅记录 Store 内的完成身份，不直接写 Bridge 生命周期；等待及失败不进入批量已读。
- Canvas 动画支持减少动态效果；沿用原生 `MenuBarExtra(.window)`。

### Findings

**TR-1 · P1 · Critical Finding：菜单的跨轮次确认保护没有覆盖 Bridge 的实际已读操作。阻断 T2。**

- **位置**：
  - ["/Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift)：868–890、2289–2291。
  - ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)：404–415、1029–1046。
- **问题**：菜单仅在本地验证所选观察身份，发送给 Bridge 的请求却只有 Session ID。成功回调中的身份复核不能阻止 Bridge 已经确认另一轮结果。
- **源码证据／可推导时序**：
  1. 菜单持有完成 A，本地身份校验通过。
  2. Bridge 已收到完成 B，但对应快照尚未抵达 Swift。
  3. Bridge 处理激活请求时捕获的是 B，随后 `clear_finished_status(expected_status: B)` 将 B 记入 `viewed_completions` 并改为 idle。
  4. Swift 回调即使拒绝记录 A，也无法撤销 B 的 Bridge 已读状态。
- **影响**：点击旧条目可以消费新轮次的未读结果；与“成功回调只确认捕获事件”的承诺不符。本次新菜单复用了具有该副作用的旧激活路径，使新增身份保护不完整。
- **最小下一步**：让菜单激活的确认身份到达实际执行确认的边界，或提供不自动确认完成的菜单激活路径；同时核对焦点监听中的确认路径。补充“Bridge 已进入 B、Swift 仍持有 A”的回归用例。当前不要运行测试，待用户授权。

### Unverified risks

- **快照身份**：前后读取 manifest 内容一致，末尾复查 Store diff 统计；但工具不能计算 SHA-256，也未逐字节复核全部十个文件。因此快照身份仍是作者提供的声明，不能声称完成当前快照的独立哈希验证。**不构成第二个源码缺陷；终态证据绑定仍需主 Agent 校验。**
- **原生布局及真实跳转**：未观察实际窗口、键盘导航、菜单关闭与终端前台切换。按本任务明确接受的验证边界，**不单独阻断 Target**，但不能宣称视觉或实时交互通过。

### 实际检查

读取了 Reviewer 契约、HTML 原型、相关源码及限定 diff；检查了状态筛选、已读身份、Pi 完成清除、通知消费、工程引用及 macOS 13 部署配置。没有编辑、运行测试、启动 App 或改变任务状态。

### 仅继承的作者证据

[ "/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/implement-attention-status-menu/evidence/build.md" ](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/implement-attention-status-menu/evidence/build.md) 记载 Debug build、build-for-testing 和 diff 检查成功；本轮仅阅读该记录，未重跑，也未将测试编译等同于断言通过。

### 限制与结论

未审查无关并发改动；macOS UI SOP 所引用的 scene-architecture 文档在指定相对位置不存在。无历史发现需要核销。

**Merge verdict：BLOCK**——TR-1 需要主 Agent 核实并修复；本反馈不授予完成批准。