# 管理 Coding Agent Hooks

Status (2026-07-29 14:56): Completed

## Scope

- 包含：在 Settings 中列出 Claude Code、Codex、OpenCode、Cursor CLI、Kimi Code、Pi 与 omp。
- 包含：安装、卸载并显示 iTermate 自有 Pi/Codex integration 状态。
- 不包含：为 Pi/Codex 之外的 Agent 实现 hooks；这些行仅显示尚未支持且不可操作。
- 不修改或删除 Otty 等其他工具已有的 extensions/hooks。

## Target

- [x] T1：Settings 提供独立 Agents 标签页并展示约定的七个 Agent，只有 Pi 与 Codex 的开关可操作。
- [x] T2：Pi/Codex 开关可安装和卸载 iTermate 自有 integration，状态及错误反馈及时更新，其他 hooks 保持不变。
- [x] T3：integration 脚本随 App bundle 分发，安装流程不依赖源码仓库路径。
- [x] T4：安装/卸载逻辑、Swift 解析、工程构建、测试及运行时界面验证通过。
- [x] T5：Agents 标签页在 Agent 列表上方显示清晰的用途描述，且不改变现有 Agent 行和开关行为。
- [x] T6：Agents 设置页隐藏右侧滚动指示器，同时保留内容滚动能力。
- [x] T7：实际运行的 Agents 设置页不显示右侧滚动指示器，同时保留超出窗口高度时的内容滚动能力。

## Plan

1. 提供可测试的 Pi/Codex integration 状态检测、安装与卸载行为。
2. 在 Settings 中加入最小 Agents 管理列表及错误提示。
3. 打包 integration 资源并验证保留现有 hooks、构建测试与实际界面。
4. 在 Agents 列表顶部加入用途描述并运行界面相关构建测试。
5. 修正 Agents 页滚动指示器配置，并通过实际构建产物验证可见行为。

## Result

- T1：运行构建产物后，Agents 标签展示 Claude Code、Codex、OpenCode、Cursor CLI、Kimi Code、Pi 与 omp；Pi/Codex 显示可操作 switch，其他行显示 `Not supported yet` 且 switch 禁用。运行时截图已确认布局和状态文本。
- T2：[`AgentIntegrationManagerTests.swift`](../../iTermateTests/AgentIntegrationManagerTests.swift) 验证 Pi 安装/卸载、Codex 合并/移除 `_iTermate` entries、保留其他 hooks、拒绝覆盖无效 JSON，以及 0600/0700 文件权限；实际点击 Pi switch 完成 off → on，安装内容与 bundle source 一致。
- T3：[`project.yml`](../../project.yml) 将 Pi/Codex integration 作为资源构建；检查 Debug App bundle 确认 `iTermate-integration.ts` 与 `iTermate-hook.py` 均存在。
- T4：`swiftc -parse`、`git diff --check` 与完整 `xcodebuild build test` 通过，24/24 测试成功；运行时 Agents 界面确认 Codex、Pi 显示 Installed。
- T5：`AgentSettingsView` 在 Agent 列表上方新增 secondary callout 描述，说明支持的 Agent 可向 iTermate 回传工作与完成状态；现有 Agent 行、状态和开关逻辑未改变。`xcodebuild build`、`swiftc -parse`、完整测试（临时隔离既有未跟踪测试编译错误）和 `git diff --check` 通过。
- T6：在 Agents 页面的 `ScrollView` 上添加 `.scrollIndicators(.hidden)`；内容仍保留滚动能力。`xcodebuild build`、`swiftc -parse` 与 `git diff --check` 通过。
- T7：将 `ScrollView` 改为 `ScrollView(.vertical, showsIndicators: false)`，重新构建并启动 Debug App；运行时 Agents 窗口的 Accessibility 树不再包含 `AXScrollBar`，截图中右侧滚动指示器消失，Agent 列表仍使用可滚动容器。`xcodebuild build`、`swiftc -parse` 与 `git diff --check` 通过。
- Review gate: Skipped — 用户未要求独立审查；本次仅修正页面滚动指示器配置，不改变数据或操作行为。
