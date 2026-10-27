# 独立审查记录：第01轮

## 主会话元数据

- 任务：remove-ghostty-support
- 轮次：01
- 模式：fresh独立只读子代理（reviewer）
- Run：72163d35-1091-4a2b-89c8-f0f3e9df4ea3
- 审查快照：sha256:f57a4a4403fa394776b800c9bf5f72225c39ad89be807cb197d88e8883ccedcf
- 接收核验：主会话重算91个清单文件（含删除项）、证据哈希、清单身份及当前差异，均与审查快照一致。

## 以下为Reviewer原始反馈

## Review

**审查模式**：独立只读子代理。

**范围与快照**：remove-ghostty-support，T1–T3；以31个变更文件为范围，重点检查终端路由、Pi身份与归档、Codex身份保护及原生Bridge调用链。入口与结束读取的快照均为 `sha256:f57a4a4403fa394776b800c9bf5f72225c39ad89be807cb197d88e8883ccedcf`，清单内容未见变化；未独立重算文件哈希。

### Findings

No issues found.

已核对的关键保留行为：
- iTerm2激活、关闭和刷新仍调用原生客户端：["/Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift)，748–820行。
- Pi仍要求iTerm2环境身份；非iTerm2不发布发现信息、状态或标题：["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)，31–35行及对应差异。
- 归档仍校验身份、等待Pi退出；关闭端仍验证原Shell所有权，未引入删除历史归档的迁移逻辑：["/Users/caishilin/Desktop/personal/iTermate/iTermate/PiSessionArchives.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/PiSessionArchives.swift)，294–324行；["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)，301–326行。
- Codex替代TTY校验与被删除辅助方法的条件一致；普通命令观察仍由未修改的Bridge提供。

### 未验证风险

- **T1/T2，非阻断**：未运行测试或真实终端/UI流程，异步恢复、聚焦及归档运行表现没有实测证据。这符合本轮明确限制，不能把编译成功当作行为验证。
- **快照绑定**：本轮只能确认清单重读一致，不能证明全部文件字节未漂移。主会话仍须按约定重新计算哈希；若不匹配，应刷新审查证据。

### 已执行检查

读取范围差异、关键当前源码与相关未修改调用链；检索产品源码、集成和测试中的已移除名称；检查文档残留是否属于保留的历史appcast；查看工作区差异统计。未编辑、运行命令、构建、执行测试或启动应用。

### 作者证据

已查看任务Result/Review Assessment、构建日志及非测试检查摘要。构建日志记录 `build-for-testing` 和 `TEST BUILD SUCCEEDED`，仅支持编译/链接成功；类型、语法及Context检查为作者记录，未由本审查重跑。

### 历史发现与覆盖限制

无历史TR-ID，无新增整改项。未逐字审计全部91个清单文件、图片资源或无关任务记录；未独立验证安装态与远程状态。本报告不授予完成或发布授权。
