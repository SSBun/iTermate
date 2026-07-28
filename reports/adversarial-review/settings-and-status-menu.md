---
created: 2026-07-28
task: settings-and-status-menu
review_cycles: 2
---

# Settings 与菜单栏状态视图审查

Topic: macOS 13 的 Settings 入口兼容性

> **E1:** 实现使用 SwiftUI `Settings` scene；macOS 14 及以上由 `SettingsLink` 打开，macOS 13 通过 `showSettingsWindow:` action 打开。当前主机只能运行验证 macOS 14+ 分支，但工程以 macOS 13 为 deployment target 编译通过。
>
> **R1:** 确认 selector 和 availability gate 正确，同时指出缺少 macOS 13 主机上的运行时验证。
>
> **E2:** 接受并记录该环境性残余风险；不为低风险、已知正确的系统 selector 引入额外兼容层或测试抽象。
>
> **R2:** 确认该 NOTE 已被完整回应，Settings、MenuBarExtra、共享偏好状态、版本元数据和 13 个测试均满足验收，没有新的有效 finding。

**Conclusion:** macOS 13 编译兼容与标准 fallback 已获批准；仅保留尚未在 macOS 13 主机执行 smoke test 的环境性风险。

---

**Final decision:** `APPROVED`

**Outcome:** Basic/About Settings、实时宽度偏好、About 元数据和 MenuBarExtra 状态/操作通过独立审查。

**Remaining:** none
