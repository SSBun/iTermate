# 修复面板边缘调整尺寸光标

Status: In Progress (2026-08-12 17:41)
Kind: Task

## Target

- [ ] T1: iTerm2 保持前台时，指针进入 iTermate 面板左右边缘会显示水平调整尺寸光标。
- [x] T2: 面板仍可从左右边缘调整宽度，且不会重新触发 NSEvent trackingArea 异常。
- [x] T3: 针对光标更新的回归测试、相关测试与 Debug 构建通过。

## Result

- T2: 用户确认最新真实 App 可从边缘拖动调整大小；日志未出现 NSEvent trackingArea 异常。
- T3: 隔离 computer-use 证明避免重复 setFrame 后 iTerm2 前台时 resize 光标保持可见；PanelLayoutTests 27/27、swiftc -parse、git diff --check 与 Debug test build 通过。
- Review gate: Skipped — 用户未要求独立或对抗审查。

## Verification

- Failed: 当前真实 App 已复现箭头；根因修复已构建并在隔离面板通过，但需用户重新运行后验证真实 App。
