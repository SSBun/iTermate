---
title: 面板悬停与命中
summary: 面板悬停与命中的适用条件、实现边界及复查要点。
---

- [2026-11-08] 非激活NSPanel在其他应用保持前台时，悬停采用.activeAlways的NSTrackingArea；不只依赖.onHover或addCursorRect。tracking覆盖整行、不拦截原点击。父视图分别保存唯一的悬停行ID与关闭按钮ID；进入替换，离开仅清理匹配ID，离开整个面板无条件清空。避免视图复用或tracking exit遗漏造成按钮残留，不采用每行独立布尔状态。隐藏按钮同时关闭hit testing。边缘tracking设置/恢复调整光标，原生.resizable负责拖拽。检查目标应用保持前台时的边缘光标、跨行按钮跟随、面板外全部隐藏及不可见按钮不能点击；回归覆盖.activeAlways。实际运行遵守项目运行授权入口。
