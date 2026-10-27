# 错误横幅显示数秒后自动关闭

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-23 16:48) |
| Artifacts | [Artifacts](../artifacts/auto-dismiss-error-banner/) |
| Kind | Task |

## Scope

仅处理截图所示的 Pi 标题刷新与归档共用错误提示生命周期，不改错误判定、终端操作或已有其他任务的未提交修改。不启动、重启或替换用户运行中的 App 与 Bridge；不运行测试。

## Target
- [x] T1: 截图所示面板错误横幅显示数秒后自动消失，不再持续占用面板空间。

## Plan

1. 补齐错误提示的自动关闭；默认显示 5 秒，新错误（包括同文案重复错误）重置计时，清空提示取消旧计时。
2. 使用隔离构建目录编译并检查差异及取消路径；真实 App 的视觉计时由用户重新运行后确认。

## Task Summary

**Pi 错误提示**：位于 ["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate)，增加 5 秒自动清除及可取消计时，新错误重新计时，主动清空时取消等待；现有报错判定与错误展示入口不变。

## Result

- T1: 已核对 PiSessionArchives.error 的所有报错写入及 PanelContent 的 archives.error 条件展示：非空错误启动 5 秒可取消 Task，结束在 MainActor 清空提示；每次赋值先取消旧任务，同文案重复错误也重置等待，nil 不再调度，旧任务取消后返回且最终检查取消状态，weak self 不延长对象寿命。macOS 13 目标 Debug xcodebuild build 成功、swiftc -parse 和 git diff --check 通过。未运行测试，未启动 App，实际窗口计时及收起效果待用户自行重新运行后确认。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅修改 Pi 共用错误提示的超时清理，不改标题、归档或终端操作；属于简单低风险 UI 状态生命周期修复。
- Snapshot: snapshot:tasks/artifacts/auto-dismiss-error-banner/evidence/a02f73cedd54fd776a5d4617afb521638b2764f47aedcd4985dd63c56e2529e9.json#a02f73cedd54fd776a5d4617afb521638b2764f47aedcd4985dd63c56e2529e9
- Evidence: T1 的源码路径检查及隔离 Debug 构建结果；已按 Context 完整索引检查 UI、Pi 归档两个相关 Pack，没有需持久化的新增架构事实，不改既有历史警告或 Lessons。
- Result clarity: 截图文案唯一对应 PiSessionArchives.error，5 秒是数秒自动关闭的有界默认值。
- Bounded impact: 影响同一 error 的主面板及 Archives 设置页提示，不修改错误判定或底层操作；任务自身仅新增属性观察器和私有取消句柄，保留原有未提交变更。
- Low risk: 只清除临时提示，无文件删除、状态推断、协议或远端影响；新错误重置计时，显式 nil 取消等待。
- Sufficient verification: 已检查非空、重复、替换、nil 和取消路径；实际 App 目标构建成功且语法/差异检查通过，未获授权运行测试，遵守不自动启动 App 的既有约束。
- Task fingerprint: 77da4d4015685dee7254d76e93fb5f06b57f95e746f7b35fd7e21c145cd79b1a

## Verification

- Passed: 最终重跑 swiftc -parse 与 git diff --check 通过；check-evidence 验证两个源文件与冻结快照一致。运行中的 App PID 26273、Bridge PID 26386 与构建前一致，未启动或替换安装态；真实 UI 计时未观察。
