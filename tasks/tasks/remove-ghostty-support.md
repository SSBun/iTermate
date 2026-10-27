# 移除 Ghostty 支持，仅保留 iTerm2

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-22 17:57) |
| Artifacts | [Artifacts](../artifacts/remove-ghostty-support/) |
| Kind | Task |

## Scope

清理产品源码、专用资源、设置、集成、测试与现行支持说明中的Ghostty支持；保留历史CHANGELOG、已发布appcast条目、Git历史及历史任务证据。不直接修改用户安装态，不启动或重启App/Bridge，不运行测试，不执行推送或发布。

## Target
- [x] T1: iTermate只识别、跟随并操作iTerm2，不再包含Ghostty专用后端、窗口识别、状态恢复或操作分支。
- [x] T2: Ghostty专用产品文件、设置入口、集成和测试逻辑及现行文档支持说明已清理，保留iTerm2现有会话、标题、归档与状态功能。
- [x] T3: 构建及允许的非测试检查通过；不改写Git历史或历史任务证据，不修改用户安装态、不重启应用，本轮不执行远程推送或发布。

## Decisions

- Ghostty专用AppleScript客户端、TTY状态listener/registry和可选zsh/Bash/fish命令上报资源一并移除；iTerm2普通命令状态继续来自原生Bridge，不另建替代状态通道。
- 保留iTerm2 Pi显式Session ID匹配、认证端点、状态恢复/完成查看确认，以及原生Codex的TTY身份监控；不把继承的Session ID当作其他终端的可信身份。
- 现有归档数据不删除；仅接受iTerm2归档与活跃发现条目，不再恢复到其他终端。历史发布记录保留，当前文档明确仅支持iTerm2。

## Plan

1. 删除Ghostty后端及其专用状态、命令集成和资源，收敛Store路由与前台窗口识别到iTerm2。
2. 清理设置、Pi发现/归档匹配、测试和现行文档，同步Context事实。
3. 进行源码残留检查、Debug构建、类型/语法及测试源码编译检查（不执行测试），自检后独立只读审查。

## Task Summary

**原生应用**：[iTermate](../../iTermate/)移除其他终端客户端、窗口分支、面板设置与专用TTY状态服务；会话操作、完成统计和Pi恢复只走iTerm2，保留原生Codex监控的TTY校验与身份保护。

**Pi集成**：[integrations](../../integrations/)仅在可信iTerm2交互会话中报告状态、发布发现端点和生成标题，删除独立Shell hooks与状态报告资源。

**回归源码**：[iTermateTests](../../iTermateTests/)移除已删除后端的用例，补充仅识别iTerm2、忽略其他终端及不修改Shell配置的边界；Pi集成回归源码同步为iTerm2专用。

**工程配置**：[project.yml](../../project.yml)及派生Xcode工程移除已删除资源，自动化权限说明仅保留iTerm2。

**现行说明**：[docs](../../docs/)、[README](../../README.md)、[中文README](../../README.zh-CN.md)与[CHANGELOG](../../CHANGELOG.md)说明仅支持iTerm2，保留历史发布记录；相关Context条目同步当前数据源与身份边界。

## Result

- T1: 当前snapshot.json绑定91个文件（含已删除项）；源码核对TerminalApp仅接受iTerm2 bundle，前台窗口、激活/关闭、刷新、Pi恢复及菜单统计仅走iTerm2；Ghostty客户端与TTY listener/registry已删除，残留扫描零匹配。证据：../artifacts/remove-ghostty-support/evidence/scope.patch、snapshot.json和final-checks.log。
- T2: 逐项核对移除专用Shell/status资源、工程引用、面板开关及测试分支；Pi仅可信iTerm2 TUI启用，保留显式Session ID唯一匹配、认证端点、归档原始数据及关闭保护；Codex TTY路径校验与旧实现等价，iTerm2 Bridge未改动。现行说明与Context已同步；历史appcast未改，CHANGELOG只追加Unreleased。未运行真实终端/UI/模型，未执行回归测试。证据：scope.patch、final-checks.log与snapshot.json。
- T3: final-build.log记录TEST BUILD SUCCEEDED（App和XCTest目标仅编译链接，不执行测试）；final-checks.log记录TS类型、mjs语法、git diff --check及Context校验通过。build-source-before.json与snapshot.json的91个文件无漂移。未启动/重启App或Bridge、未改用户安装态/Shell配置、未commit/push/release；构建工具自身注册产物不等于启动App。测试运行、真实UI/模型质量未验证。
- Review gate: Passed — fresh只读reviewer run 72163d35-1091-4a2b-89c8-f0f3e9df4ea3无发现或阻断风险；反馈已存../artifacts/remove-ghostty-support/reviews/round-01.md并索引。主会话重算91个清单文件、全部绑定证据与scope.patch均匹配sha256:f57a4a4403fa394776b800c9bf5f72225c39ad89be807cb197d88e8883ccedcf；运行时未验证边界明确披露。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨原生数据源、Pi身份/归档、设置、资源与集成生命周期的删除；涉及身份及关闭边界，不能按低风险豁免。
- Snapshot: sha256:f57a4a4403fa394776b800c9bf5f72225c39ad89be807cb197d88e8883ccedcf
- Evidence: ../artifacts/remove-ghostty-support/evidence/snapshot.json；各Target Result及final-build.log、final-checks.log；主会话静态核对iTerm2保留路径，未执行测试或运行App。
- Task fingerprint: 14bc39c87fd5c6cf7ce14b47da62c1e4bb51e1927691a5d5deb66a2fcf09112b

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/remove-ghostty-support/reviews/round-01.md) | sha256:f57a4a4403fa394776b800c9bf5f72225c39ad89be807cb197d88e8883ccedcf | no blocking findings |

## Verification

- Passed: 独立审查后再次核对91个文件、证据、清单身份及当前diff均无漂移；复跑TS类型、mjs语法和git diff --check通过；构建日志仍绑定TEST BUILD SUCCEEDED。Round 01报告与索引身份一致。未执行测试、未启动/重启App/Bridge，未修改安装态或远程发布。
