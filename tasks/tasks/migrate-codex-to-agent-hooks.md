# 提交当前改动并将 Codex 状态接入 Agent Hooks

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-13 10:39) |
| Kind | Queue |

## Target

- [ ] T1: 在开始新实现前，将当前 iTermate 仓库全部本地改动提交为可恢复的 Git 基线，不推送远端。
- [ ] T2: Codex 状态通过现有 Agent Hooks 框架接入 iTermate，覆盖所需生命周期，避免重复的独立 hook 入口；不改 Kiro 或 Pi 行为。
- [ ] T3: 执行相关单元测试并修复本次改动造成的失败，完成构建与独立审查，明确安装态与真实运行验证边界。

## Scope

- 先提交当前 iTermate 仓库全部本地改动作为基线，再修改 iTermate 与 Agent Hooks 框架中与 Codex 接入相关的源码；其他仓库既有改动不顺带提交。不推送，不替换或重启用户当前运行应用。

## Plan

1. commit-agent-hooks-baseline：保存当前工作区基线，完成后进入实现。
2. implement-codex-agent-hooks：实现跨组件接入、相关单元测试与独立审查。

## Children

1. [提交 Agent Hooks 迁移前的全部本地基线](commit-agent-hooks-baseline.md)
2. [实现 Codex 经 Agent Hooks 上报并执行单元测试](implement-codex-agent-hooks.md)
