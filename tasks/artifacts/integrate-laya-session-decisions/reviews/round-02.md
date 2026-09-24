# 第 02 轮审查

主 Agent 元数据：任务 integrate-laya-session-decisions；运行 9af6bcbf-70e7-4d20-ac01-3a5e13c7f3d7；fresh 只读 reviewer；快照 evidence/snapshot-01.json。以下为原始反馈，未修改其结论。

## Review

- **审查模式**：independent subagent；只读反馈，未修改文件或任务状态。
- **范围**：指定的 10 个交付文件、相关调用点及冻结 diff；排除既有正则和测试改动。
- **快照**：snapshot-01，提供的 SHA256 为 `0e06ab7620a33182d0ef62321d11d74a0bff7d2d534c416ccd95685ce0cf025e`。前后工作区变更清单一致；工具不能重新计算文件哈希，因此内容身份仍依赖主代理核验。

### 已确认的正确实现

- 公共服务限定 loopback，具有 Bearer、Host、Origin 校验、请求限制及推理互斥。
- iTerm2 模型标签与权威状态分离；Pi 推理结果受生命周期代次检查保护。
- 设置入口、独立下载、错误提示及服务管理已经接入；没有将模型权重加入 App 资源。

### TR-1 — P1：异常退出遗留标记可能使关闭分析失效

- **位置**：["/Users/caishilin/Desktop/personal/iTermate/iTermate/LocalModelService.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/LocalModelService.swift):22、167–178；["/Users/caishilin/Desktop/personal/iTermate/integrations/laya/iTermate-laya.py"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/laya/iTermate-laya.py):230–271。
- **问题**：分析许可使用持久文件，但删除依赖当前 App 实例的 `ownsAnalysisMarker`。新实例不会接管或清理旧实例遗留的标记。
- **证据**：断电等未执行 cleanup 的退出会留下 `analysis-enabled`。重新启动、模型仍在加载时关闭分析：新实例的 ownership 为 false，因此不删除标记；随后 ready 回调也不会删除。helper 启动取得锁后同样没有清理旧标记。
- **影响**：设置显示分析关闭，Pi 与 Bridge 仍因标记存在而提交本机推理请求，违反 T2/T4 的关闭与回退语义。Bridge 的读取门控见 ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py):646、709。
- **建议修复**：helper 成功取得单实例锁后、发布服务就绪前清除遗留分析标记，再由当前 App 根据实际偏好创建；保留对其他存活实例的保护。补充遗留标记下“加载期间关闭分析”的验证。
- **结论**：需要修复；这是静态控制流证明，未执行故障注入。

### Unverified Risks

- **T1/T2，阻断完整 Target 验证**：尚无真实设置交互、取消/重试及 Session 显示端到端证据。构建和隔离 helper 调用不能证明这些用户入口有效。应在用户允许的时机补齐，不得为验收擅自重启 App。
- **T3/T4，非阻断风险**：未压测并发、未观察异常终止恢复；当前只有代码检查与作者提供的正常服务证据。
- **T1，非阻断风险**：多语言判断准确率未建立；中文样例未达阈值已有明确披露，不能据此声称普遍可靠。

### 检查与证据边界

- **本人执行**：读取需求、源码、diff、调用点、任务 Result/Assessment 和服务观测；前后检查工作区变更清单；检查构建日志包含 `BUILD SUCCEEDED`。
- **仅阅读作者证据**：HTTP 200/401/403/400/413、真实模型输出、权限及正常 SIGTERM 清理；未重新执行这些检查。
- **未执行**：测试、构建、安装、App/Bridge 启停、HTTP 请求或文件写入。UI SOP 的关联参考文件读取失败，未宣称完成完整视觉验收。
- **历史发现**：无；上一轮是启动基础设施失败。
- **Merge verdict**：BLOCK。仅反馈修复及证据缺口，不授予完成批准。