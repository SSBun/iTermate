# 实现 Codex 经 Agent Hooks 上报并执行单元测试

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-13 10:41) |
| Kind | Task |
| Parent | migrate-codex-to-agent-hooks |

## Target

- [ ] T1: Agent Hooks 支持 Codex 所需中断与会话结束事件，并保持既有宿主行为。
- [ ] T2: iTermate Codex 集成复用 Agent Hooks 规则与分发入口，不重复安装独立 Codex 状态 hooks，保留正确状态、会话及轮次隔离。
- [ ] T3: 相关单元测试和构建通过，独立审查完成；不改变 Kiro/Pi 行为、不替换或重启当前运行应用、不推送远端。
