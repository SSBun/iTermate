# 通过 Session 右键菜单手动刷新任务标题

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-12 20:05) |
| Artifacts | [Artifacts](../artifacts/refresh-pi-session-title-menu/) |
| Kind | Task |

## Scope

- 为现有 Pi 实时标题增加手动刷新入口，保留自动生成及回退；复用当前模型并消耗其用量。不安装集成、不重启 App/Bridge。本次请求未再次明确要求执行测试，新增回归用例仅编译/检查，不执行测试套件。
- 基于上一任务尚未独立审查的实时摘要实现继续增量开发；不修改其他任务的 Codex 状态改动，也不冒充上一任务审查完成。

## Plan

1. 私有 Pi RPC 增加认证的标题刷新动作，复用摘要生成与过期结果取消机制，禁止同一会话并发刷新。
2. 原生 Session 右键菜单增加刷新入口，按能力及会话状态控制可用性，失败保留标题并反馈。
3. 补充回归用例与使用说明，执行类型检查、测试目标编译和diff检查；独立审查能力不足时保留阻塞。

## Task Summary

**Pi 集成**（["/Users/caishilin/Desktop/personal/iTermate/integrations/pi"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi)）增加认证refreshTitle请求、能力声明和单会话并发保护；手动请求绕过自动去重，复用模型生成、取消和身份校验，不锁输入或改变状态；补充5项RPC回归用例。

**原生面板与Pi发现**（["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate)）在Session右键菜单添加Refresh Session Title及刷新中状态，按能力和空闲身份置灰；跟踪端点在途请求、验证响应与当前发现记录，并显示失败提示，通用RPC错误不再误称归档。

**原生回归用例**（["/Users/caishilin/Desktop/personal/iTermate/iTermateTests"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests)）补充2项手动刷新能力及唯一TTY判断用例，随正式测试目标编译，但未执行。

**使用文档**（["/Users/caishilin/Desktop/personal/iTermate/docs"](file:///Users/caishilin/Desktop/personal/iTermate/docs)）说明菜单入口、额度、空闲限制、重复点击及失败行为。

## Block

- Reason: 当前宿主无fresh只读Reviewer启动工具，不能完成R2独立审查；本轮仅完成类型、语法、正式工程与测试目标编译检查，新增7项回归用例未运行，真实点击、模型质量及面板反馈未实测。上一实时摘要任务的旧测试证据不能覆盖本次改动。
- Unblock when: 在具备独立子代理工具的宿主恢复任务，核对当前快照及授权范围；若用户明确要求测试，再运行更新后的相关测试。调用csl_review_config并使用其精确launch.model完成fresh/read-only task-review及反馈处理。真实端到端验收需用户自行运行新版App并更新/reload Pi集成，本次不自动安装或重启。

## Target
- [x] T1: 用户可通过 Pi Session 右键菜单的 Refresh Session Title 操作，依据当前会话内容重新生成并更新任务标题，无需等待下一轮回复。
- [x] T2: 保留现有自动摘要和标题回退行为；刷新失败时不清空原有标题。

## Result

- T1: 源码已接通Session右键Refresh Session Title→认证RPC→force生成→发现元数据→标题展示；tsc类型检查、node --check、swiftc -parse与Xcode build-for-testing通过，打包Pi资源与源码cmp一致。未实际点击或调用真实模型；新增回归用例仅编译，未执行。
- T2: 自查共享生成函数仅在合法模型结果且请求/会话/leaf仍有效时更新taskSummary；force仅绕过自动去重，自动settled调用继续异步catch，失败路径不清空旧标题。菜单能力对旧版集成默认为不可用；编译检查通过，行为回归测试尚未执行。
- Review gate: Required — R2须fresh只读task-review；当前宿主工具不可用，没有启动Reviewer，不以自查或上一任务测试代替。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 新增带模型调用的认证RPC与跨进程异步交互，涉及取消、并发保护和身份复核，不能按简单菜单文字修改豁免；当前只完成静态和编译检查。
- Snapshot: tasks/artifacts/refresh-pi-session-title-menu/evidence/snapshot.json sha256:c80e3e024d6760a5f697accd3af167e3251dd0914e8b6dde1d4e068b1f16ae02
- Evidence: Result T1/T2及evidence/build.log、typecheck.log；新增7项回归用例未执行，UI/真实模型未实测，当前工具集中无Reviewer启动器。
- Task fingerprint: c3cb9ddb3039c3ff79fe01485d3eb03bedaa5f7b19f1a9a540019d754a0120fe
