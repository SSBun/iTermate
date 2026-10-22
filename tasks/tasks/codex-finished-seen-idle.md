# Codex 非问题回复完成后在激活查看时转为空闲

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 16:04) |
| Artifacts | [Artifacts](../artifacts/codex-finished-seen-idle/) |
| Kind | Task |

## Scope

只调整 Codex 完成状态的查看确认；不改变 Pi 或问题回复的等待状态，不启动、重启或覆盖用户当前安装的 App 与 Bridge，不执行单元测试。

## Plan

1. 核对原生 Codex 状态叠加与真实终端焦点路径。
2. 补全按完成事件与进程、终端身份绑定的查看确认，保留后续新一轮完成提示。
3. 编译检查、核对轮询及身份失效边界，并执行必要的独立只读审查。

## Target
- [x] T1: Codex 非问题回复结束后显示完成状态。
- [x] T2: 激活对应会话查看完成回复后，完成状态转为 idle。

## Task Summary

**终端状态与操作**（[组件](../../iTermate/)）：为 Codex 完成事件增加带身份校验的查看确认，接入前台焦点变化及激活成功回调，避免重复轮询恢复已查看标记。

**回归覆盖**（[组件](../../iTermateTests/)）：补充完成确认、下一轮、进程与会话更换、非完成状态和全局焦点筛选的编译覆盖。

**Codex 监控说明**（[组件](../../docs/)）：说明完成转为空闲的条件及事件身份边界。

## Decisions

- Codex 原始 rollout 与标题生成仍使用原观察值；已查看仅覆盖展示状态，不改写上游事件或完成统计规则。
- 原生焦点使用终端快照中的全局 Window/Tab/Session 与系统前台应用，应用失焦时清理焦点基线；不以状态轮询本身作为查看。
- 使用独立 DerivedData 构建，未执行测试、未启动 App 或替换用户安装态。真实窗口点击仍需用户运行新构建后人工确认。

## Result

- T1: 源码核对 task_complete 仍保留 finished；mergingCodexObservation 仅在完成时间、Session ID 与进程身份全部匹配已查看记录时覆盖为 idle。App 与新增回归用例 build-for-testing 编译成功；证据见 ../artifacts/codex-finished-seen-idle/evidence/task.patch 与 build.log；未执行测试，未声称真实 UI 已验证。
- T2: 源码逐路核对 iTerm2/Ghostty 快照前台全局焦点变化与激活成功回调均进入完成确认；重复轮询保留确认，下一轮时间或身份变化失效，awaitingInput/running/interrupted/nil 不可确认。swiftc -parse 与两目标编译通过，未启动 App，真实焦点交互需用户运行新构建确认。
- Review gate: Passed — 独立 fresh/read-only Reviewer run 17ae6eee-99d1-48aa-bc2c-0bea21878cae 无 confirmed finding，无源码 Target 阻断风险；反馈已保存 ../artifacts/codex-finished-seen-idle/reviews/round-01.md 并建立索引，范围与补丁哈希复核未变。真实窗口交互未运行。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 变更涉及异步激活回调、原生焦点和轮询事件身份，需独立检查遗漏与失效路径。
- Snapshot: sha256:7a77418277046ffa1ef06e555fbb2c90d6f3e086c157223c19b4feed5193f158; evidence/snapshot.json
- Evidence: 已核对本任务相对修改前基线的 task.patch、三个范围文件 snapshot.json、build.log；App/测试目标仅编译成功、swiftc -parse、diff --check 与 Context validate 通过；未运行测试或 App，窗口交互为人工验证限制。
- Task fingerprint: 450631947bac88f76dd2a11a1948065483c6c07737075353d8c0df1c5ad71a39

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/codex-finished-seen-idle/reviews/round-01.md) | sha256:7a77418277046ffa1ef06e555fbb2c90d6f3e086c157223c19b4feed5193f158 | no blocking findings；真实焦点交互未运行 |

## Verification

- Passed: 独立审查后再次核对三文件与任务补丁 SHA256 均与审查快照一致；swiftc -parse、任务范围 diff --check、Context validate 通过；此前 App 与测试目标 build-for-testing 编译成功。未执行测试，未启动或重启 App/Bridge，真实窗口交互保留人工确认限制。
