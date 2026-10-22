# 实现 Codex 经 Agent Hooks 上报并执行单元测试

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-13 11:50) |
| Artifacts | [Artifacts](../artifacts/implement-codex-agent-hooks/) |
| Kind | Task |
| Parent | migrate-codex-to-agent-hooks |

## Scope

- 归属本 iTermate 队列，源码修改覆盖 iTermate 与 /Users/caishilin/Desktop/personal/skills 的 Agent Hooks 组件；后者既有未提交变更原样保留，不提交。不安装或更新用户全局运行态。

## Plan

1. 补齐仅 Codex 的 Interrupt/SessionEnd 分发、能力与内置 iTermate 规则，保留原有共享宿主入口。
2. iTermate 用显式启用标记和已安装 reporter 接入内置规则；显式启用时清理旧 iTermate 原生 hooks，不新增独立注册。
3. 在隔离 HOME/数据目录和构建目录验证事件、脚本调用、迁移与单元测试，执行独立审查。

## Baseline

- iTermate 基线 5c5f150：Codex reporter 18 与 Bridge 13 个单元测试全部通过。
- Agent Hooks 未修改前运行 tests/agent-hooks.test.js：31 passed、1 failed；失败用例为 inner CSL Agent Kit contract injects on supported session starts，仍断言已被其他本地任务替换的旧 Contract 文案。不得为本次迁移修改该不相关 Contract 或掩盖失败。

## Task Summary

**iTermate Codex 安装器**：["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 将显式启用改为安装 reporter 与强类型 opt-in 标记，显式迁移时只删除旧 iTermate 原生条目，迁移失败恢复原配置；自动资源更新不切换提供方。

**Codex 上报与测试**：["/Users/caishilin/Desktop/personal/iTermate/integrations/status"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/status) 在关闭 Agent Hooks opt-in 后停止 worker 续租，新增从真实框架 dispatcher 经 reporter 到 Bridge 的隔离集成测试。

**安装回归覆盖**：["/Users/caishilin/Desktop/personal/iTermate/iTermateTests"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests) 验证无新原生注册、显式迁移、无关配置保留及失败回滚。

**Agent Hooks 框架**：["/Users/caishilin/Desktop/personal/skills/skills/meta/agent-hooks"](file:///Users/caishilin/Desktop/personal/skills/skills/meta/agent-hooks) 增加 Codex-only 非阻塞中断/退出事件、内置受 opt-in 保护的 iTermate 规则与原生 payload 转发器，更新协议 fixture 与使用契约。

**Codex 插件注册**：["/Users/caishilin/Desktop/personal/skills/hooks"](file:///Users/caishilin/Desktop/personal/skills/hooks) 增加仅 Codex 的终态分发配置，由 Codex manifest 与共享配置组合加载，Claude/Pi 注册保持不变。

**框架回归覆盖**：["/Users/caishilin/Desktop/personal/skills/tests"](file:///Users/caishilin/Desktop/personal/skills/tests) 新增宿主隔离、opt-in、转发、错误和真实分发测试，并将全局脚本退出码测试夹具与新可选观察器隔离，原断言保持不变。

**接入文档**：["/Users/caishilin/Desktop/personal/iTermate/docs"](file:///Users/caishilin/Desktop/personal/iTermate/docs) 新增启用、信任、迁移和真实运行验证说明，中文 README 链接到该说明。

## Verification Scope

- 已执行：Python reporter 19、Bridge 13、跨仓真实分发链路 1、Agent Hooks 新增 7、Swift installer 9，均通过；独立 XCTest runner 链接隔离 build-for-testing 的真实 dylib，不调用 App main。
- 框架原有 agent-hooks.test.js 修改前及修改后均为 31 passed/1 failed；唯一失败是其他本地任务改写 Contract 后遗留的文案断言。没有删除、跳过或放宽该断言，也不声称全框架套件全绿。
- Skill Quality 无失败，保留 context-budget 警告（1621 tokens）；不为预算删除运行契约。两仓 Context 校验及 task-owned diff-check 通过。
- 未安装更新用户 CSL 插件，未改用户启用标记/原生配置，未启动或重启 App/Bridge；源代码中的设置状态与规则 eligible 不是现场投递证据。

## Reverification

- 用户提供新截图：MyWiki Codex 已完成天气回答，但被选中的 Session 仍显示普通命令运行图标。重新打开同一实现任务，复核真实安装/加载/投递链路；此前源码和隔离测试证据不等于现场生效。
- 保持原范围：只处理 Codex 接入；先只读核实，不自动改用户全局配置或重启应用。当前反馈未额外授权执行测试，先用只读运行证据定位。

## Live Findings

- 2026-10-13 用户反馈后的只读检查：真实 opt-in 标记不存在；原生 hooks 配置中仍有 7 个 `_iTermate` 旧入口，说明显式迁移尚未完成。
- 已缓存 CSL 插件的 Codex manifest 包含两份 hooks 配置；adapter、native dispatcher 与 Codex lifecycle 文件均和当前源码逐字节一致。已安装 reporter/Bridge 与当前源码一致，App 磁盘 dylib 也包含新 marker 与新提供方提示。不能把问题归因于插件缓存未更新。
- 缺少 opt-in 时 bundled adapter 按设计直接返回，不会调用 reporter。Bridge 中 MyWiki 的 4BBC8646-7E82-4002-BCC4-5E1E7F36B2DC 仍为 running/command；另一个 MyWiki pane 为 finished/agent。当前焦点已随用户操作改变，不能把采样时焦点直接等同截图焦点。
- Codex 持久化 hook state 中已存在共享事件信任记录，但 CSL 插件的 interrupt/session_end 没有记录；这不等于已核验整个当前会话的信任判定，仍需用户在 /hooks 检查新定义。
- 本轮未改源码或用户安装配置，未启动/重启程序，未运行测试。

## Block

- Reason: 新 Agent Hooks 接入缺少 iTermate 显式 opt-in，旧原生条目尚未迁移；现场投递不能成立。全局启用与 hook 信任属于用户操作，不能在本轮只读诊断中自动代做。
- Unblock when: 用户在新版 iTermate Settings → Agents 启用 Codex，确认无安装错误并在 /hooks 审核相关定义，然后触发新一轮 Codex；重新只读检查 marker、旧条目清理及 Bridge Agent 状态。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/implement-codex-agent-hooks/reviews/round-01.md) | sha256:3a105201edcd834f2e1b0b04148ada18fbcc3c7d64a53f3146f8bb7c922352ad | no blocking findings；保留真实插件加载与故障注入覆盖限制 |

## Target
- [x] T1: Agent Hooks 支持 Codex 所需中断与会话结束事件，并保持既有宿主行为。
- [x] T2: iTermate Codex 集成复用 Agent Hooks 规则与分发入口，不重复安装独立 Codex 状态 hooks，保留正确状态、会话及轮次隔离。
- [x] T3: 相关单元测试和构建通过，独立审查完成；不改变 Kiro/Pi 行为、不替换或重启当前运行应用、不推送远端。
- [x] T4: 对用户反馈的同一 Codex 状态问题复核真实加载与投递链路，查明仍显示普通命令图标的具体原因，并区分源码缺陷与尚未生效的安装状态。

## Result

- T1: Codex-only Interrupt/SessionEnd capability、native 映射、补充 manifest 及 fixture 完整；新增7个框架测试通过，原框架31通过/1基线文案失败不变；Claude/Pi capability 未扩展。
- T2: 显式启用 marker、旧条目清理/失败回滚及无新原生注册的9个Swift测试通过；7个内置规则校验有效；临时HOME中真实dispatcher→reporter→Bridge handler/socket的7阶段生命周期集成测试通过。
- T3: 相关49个单元/集成测试通过，隔离build-for-testing成功且独立XCTest不调用App main；框架套件仍保留1项既有Contract断言失败，不声称全绿；两仓diff/context校验通过，Skill Quality无失败/预算警告，未改用户安装态或推送。独立审查由Review门禁记录。
- T4: 只读实测：marker不存在，7个旧_iTermate原生入口仍在；缓存插件与已安装reporter/Bridge匹配源码；目标MyWiki pane为running/command。已定位新接入被opt-in门禁跳过，待用户显式启用与信任后验证实际投递；未改安装态。
- Review gate: Required — Task reopened; rerun the applicable review after revisions
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 跨仓宿主分发/插件注册/安装迁移/上报适配，含并发旧安装兼容与共享框架边界，需要独立审查。
- Snapshot: sha256:3a105201edcd834f2e1b0b04148ada18fbcc3c7d64a53f3146f8bb7c922352ad
- Evidence: snapshot-01.json、itermate.diff、agent-hooks.diff、Result T1-T3；49个相关测试通过、隔离构建成功，框架1个基线无关断言失败保留。
- Task fingerprint: 23d2f6085290138c5ea0fa3cde9e5287ab0e470a8c1ead32eb4778e5e2af8858
