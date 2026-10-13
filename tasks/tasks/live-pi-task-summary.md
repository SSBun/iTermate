# 为实时 Pi Session 显示当前任务摘要并测试

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-12 18:31) |
| Artifacts | [Artifacts](../artifacts/live-pi-task-summary/) |
| Kind | Task |

## Scope

- 仅 Pi 实时任务摘要；复用当前模型，允许额外模型用量。允许相关自动化测试与构建，不覆盖安装态、不重启 App 或 Bridge，不改其他任务的 Codex 状态修复。

## Decisions

- 使用现有私有 Pi discovery 元数据传递可选摘要，面板订阅既有 ObservableObject；不改变 Bridge 或 Agent 生命周期协议。
- 摘要来自当前分支最近四条用户消息与四条助手可见文本，每条有界截取；助手连续进度消息不能挤掉最近用户目标。无工具调用、无新 CLI、无新对话条目；模型失败保留旧标题。
- 回复结束后台生成；每轮取消过期请求，切换 Session/分支清除旧摘要。既有两秒 discovery 轮询更新 UI，按明确 Session ID 或唯一 Pi TTY 匹配。
- Xcode 测试配置会启动 App 宿主；为遵守不启动 App 的边界，Swift 行为测试采用隔离的无宿主 XCTest 运行方式，另做正式工程构建。

## Plan

1. 实现有界摘要调用与 Pi 生命周期缓存、取消及元数据发布。
2. 面板优先显示身份匹配的摘要，保留标题回退和悬停原始标题。
3. 执行隔离自动化测试与正式工程构建，自查异步过期、身份误匹配与失败回退。
4. 恢复可用的 fresh、只读 Reviewer 子代理能力后，按当前快照执行独立审查，不以自查代替。

## Task Summary

**Pi 集成**（["/Users/caishilin/Desktop/personal/iTermate/integrations/pi"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi)）新增实时任务标题生成、每轮去重与取消、分支身份校验和发现元数据发布；复用有界模型调用，扩充内容筛选及生命周期回归测试。

**原生面板与会话发现**（["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate)）按唯一活跃Pi身份选用摘要，校验长度、有效期与控制字符，保留原始标题回退和悬停提示；摘要加入行重建身份。

**原生测试**（["/Users/caishilin/Desktop/personal/iTermate/iTermateTests"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests)）新增iTerm2/Ghostty身份匹配、重复描述拒绝、异常摘要回退和无状态变化时的标题更新验证。

**使用文档**（["/Users/caishilin/Desktop/personal/iTermate/docs"](file:///Users/caishilin/Desktop/personal/iTermate/docs)）说明更新集成、模型用量、隐私与缓存边界。

## Block

- Reason: 本会话可用工具集中没有 subagent 或等价 fresh 只读 Reviewer 启动能力；本次跨 Pi 异步生命周期、模型调用及 Swift 展示的改动属于 R2，尚未独立审查，不能标记完成。未启动任何 Reviewer，未用自查替代。
- Unblock when: 在提供实际 fresh/read-only 子代理工具的宿主会话中恢复本任务，重新核对快照与测试证据，调用 csl_review_config 后使用其精确 launch.model 启动一次 task-review，并处理其反馈。真实面板视觉和真实模型摘要质量另需用户运行新版 App、安装/reload Pi 集成后验收；本次没有自动安装或重启。

## Target
- [x] T1: 根据 Pi 当前分支最近的用户请求与助手回复生成简短任务摘要，不使用隐藏思考或原始工具输出。
- [x] T2: 回复结束后更新摘要，生成期间保留旧摘要；实时 Session 行优先显示摘要，无摘要时回退现有终端标题，悬停可查看原始标题。
- [x] T3: 执行相关自动化测试与构建检查，记录结果及未覆盖的运行时验证。

## Result

- T1: 当前实现仅抽取活动分支可见用户/助手文本，复用当前模型无工具调用；typescript-tests.log 的25项全部通过，覆盖内容排除、有界摘录、用户目标保留、输出校验与60秒超时。真实服务端模型摘要质量未实测，测试使用隔离provider mock。
- T2: lifecycle-tests.log 45项通过，覆盖settled后台发布、失败保留、迟到结果、导航清理及Ghostty身份；swift-tests.log 18项通过（含5项新增标题测试），验证身份、回退与摘要更新。正式工程编译包含UI摘要优先、原始标题help和行id刷新；未安装/重启或实际观察新版面板。
- T3: tasks/artifacts/live-pi-task-summary/evidence/verify.sh 最终运行成功：25项TS、45项生命周期、18项Swift共88项自动化测试通过，TypeScript类型检查与Xcode build-for-testing通过，git diff --check通过；Swift使用实际debug dylib的无App宿主XCTest runner。构建内Pi资源与源码cmp一致。
- Review gate: Required — R2必须执行fresh只读task-review；当前工具集中无subagent或等价启动器，尚未启动任何Reviewer，不可用自查替代。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 涉及额外模型调用与对话隐私筛选、异步取消和会话身份、跨Pi/Swift展示；需独立检查交互边界，不能作为简单展示改动豁免。
- Snapshot: tasks/artifacts/live-pi-task-summary/evidence/snapshot.json sha256:dd3615aa85dfdcc61cf4879902820a5a0a01befc9b6b42d4ae50732d83014d21
- Evidence: Result T1-T3；证据目录verify.sh及四类日志，自查内容哈希固定于snapshot.json。88项测试与正式构建通过，真实模型质量/面板视觉未验证；当前宿主无Reviewer启动工具。
- Task fingerprint: 45850ffc879389ee84539818a7d05b3054f032b0472bc80a7f5786e81d62b33a
