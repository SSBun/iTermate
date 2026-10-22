# 提交当前改动并将 Codex 状态接入 Agent Hooks

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-13 11:50) |
| Kind | Queue |

## Target
- [x] T1: 在开始新实现前，将当前 iTermate 仓库全部本地改动提交为可恢复的 Git 基线，不推送远端。
- [x] T2: Codex 状态通过现有 Agent Hooks 框架接入 iTermate，覆盖所需生命周期，避免重复的独立 hook 入口；不改 Kiro 或 Pi 行为。
- [x] T3: 执行相关单元测试并修复本次改动造成的失败，完成构建与独立审查，明确安装态与真实运行验证边界。

- [ ] T4: 对用户随后反馈的同一 Codex 图标问题复核现场接入链路，区分源码交付与实际启用状态。

## Block

- Reason: 实现子任务现场复核确认 opt-in 标记缺失、7 个旧原生入口仍在；等待用户显式启用新接入并检查 hook 信任。
- Unblock when: implement-codex-agent-hooks 的现场启用条件满足，真实 Agent 状态复核通过，再完成父任务集成门禁。

## Scope

- 先提交当前 iTermate 仓库全部本地改动作为基线，再修改 iTermate 与 Agent Hooks 框架中与 Codex 接入相关的源码；其他仓库既有改动不顺带提交。不推送，不替换或重启用户当前运行应用。

## Plan

1. commit-agent-hooks-baseline：保存当前工作区基线，完成后进入实现。
2. implement-codex-agent-hooks：实现跨组件接入、相关单元测试与独立审查。

## Task Summary

本 Queue 只协调基线提交与跨仓实现，没有新增父任务自有的代码或组件改动；具体变更由两个子任务记录。

## Delivery Boundaries

- 基线提交为 5c5f1507a0865d9d77b41d65236f0af7c8150308；随后实现保留在两仓工作区，未追加提交或推送，也未安装更新用户运行环境。
- 新实现相关 49 个单元/集成测试与隔离构建通过，独立审查无阻塞；框架原套件仍有 1 项修改前就存在的 Contract 文案断言失败，未隐藏或修改。
- Skill Quality 0 failures，保留 1621-token context-budget 警告。真实 Codex 插件加载/信任/UI 与 marker 写入中途故障注入未验证，不作现场已生效声明。

## Children

1. [提交 Agent Hooks 迁移前的全部本地基线](commit-agent-hooks-baseline.md)
2. [实现 Codex 经 Agent Hooks 上报并执行单元测试](implement-codex-agent-hooks.md)

## Result

- T1: 基线子任务先完成提交5c5f1507a0865d9d77b41d65236f0af7c8150308，44文件、提交后清洁；随后才执行Agent Hooks源码变更，无推送。
- T2: assembled snapshot sha256:3a105201edcd834f2e1b0b04148ada18fbcc3c7d64a53f3146f8bb7c922352ad：Codex仅补两个框架事件入口，7个内置规则→既有reporter；Swift显式marker迁移不新增独立注册；跨仓7阶段生命周期及宿主隔离验证通过。
- T3: 实现子任务R2独立审查passed、最终49测试通过、隔离build-for-testing成功；原框架1项基线文案失败保留，真实安装加载未验证，不声称全套件/现场通过。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Stale
- Reason: 父Queue仅协调已完成且已审查的子任务，无父任务自有产品文件变更；仍执行组合身份与集成证据核验。
- Snapshot: baseline:5c5f1507a0865d9d77b41d65236f0af7c8150308; assembled:sha256:3a105201edcd834f2e1b0b04148ada18fbcc3c7d64a53f3146f8bb7c922352ad
- Evidence: Result T1-T3；实现子任务snapshot-01与round-01，49测试及跨仓真实dispatcher链路证据。
- Task fingerprint: 8d762d10a5e2dbbef3f45b138d5184077c2810298879a8e5201312b2a26e8c0d
