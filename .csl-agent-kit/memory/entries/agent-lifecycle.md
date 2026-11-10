---
title: Agent生命周期
summary: Agent生命周期的适用条件、实现边界及复查要点。
---

- [2026-11-05] 交互式Agent进程长期存活、外层Shell命令仍running，不代表Agent仍在工作。Agent真实生命周期优先于普通Shell Integration；退出后释放状态所有权，让后续普通命令由PromptMonitor继续观察。
- [2026-11-09] Pi使用agent_start与agent_settled等生命周期；handler等待有界Bridge状态确认，不等待后台模型分类。settled可能为等待、空闲、中止或完成，不能一律显示finished；状态派生以Pi集成源码为准。
- [2026-11-09] Codex使用原生进程、已核实thread的rollout及现有daemon被动监控，不使用UserPromptSubmit/Stop hooks。进程存活或文件增长均不能证明running；精确身份及状态映射见docs/codex-monitoring.md。
