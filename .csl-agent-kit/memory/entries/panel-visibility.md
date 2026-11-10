---
title: 面板前台可见性
summary: 浮动面板跟随目标应用前台状态的条件及可见性验收。
---

- [2026-11-05] 浮动 companion 使用 .floating 或 orderFrontRegardless() 跟随另一应用时，Core Graphics 能找到屏幕窗口仍不足以证明目标在最前；显示面板 MUST 同时满足目标为系统前台应用且目标窗口可见。目标失去前台、窗口最小化或不存在时 MUST 隐藏面板，MUST NOT 覆盖其他应用；切回目标前台且窗口可见后 MUST 恢复原跟随位置。验收 MUST 覆盖其他应用置前、切回目标、目标最小化及无窗口四种情形。
