# 修复调整 iTerm2 窗口大小时 Session 状态串行

Status: Completed (2026-08-13 10:54)
Kind: Task

## Target
- [x] T1: 调整 iTerm2 窗口大小时，空闲或已完成 Session 不会错误显示 running 状态。
- [x] T2: 真实 running Session 在窗口调整和面板重绘后仍保持自身状态，其他 Session 不受影响。
- [x] T3: 针对根因的回归测试、相关测试与 Debug 构建通过。
- [x] T4: 调整窗口时的面板几何、Session 状态计数和状态视图动画变化会写入可过滤且不包含用户内容的诊断日志。
- [x] T5: Layout reconcile 不会把原本 idle 的 Session 恢复为 running；系统唤醒仍能恢复真实普通命令。

## Plan

1. Red：以 Bridge 发布的 Session 状态为 seam，复现 layout reconcile 把 idle Session 错误恢复为 running。
2. Green：拆分 layout 校验与 wake 恢复，布局变化只清理已有错误状态，不恢复 idle Session。
3. 运行 Bridge 自测、相关测试与静态检查；真实睡眠/唤醒验证仍由用户触发。

## Result

- T3: 新增 layout 变化窗口内丢弃 Prompt 重放事件，并在稳定后重新确认真实运行状态的回归；Bridge self-test、py_compile、完整 Xcode 测试 45/45、swiftc-parse 与 git diff --check 均通过。
- T1: 真实日志记录 17:34:08、17:34:10、17:34:15 三次 resize，期间 24 个 Session 的 Bridge 状态计数没有变化，未再把空闲 Session 批量标记 running，也未产生伪 finished。
- T2: resize 前已有 1 个 command running 与 1 个 agent running，三次 resize 期间均保持；17:34:19 新增的是独立 agent lifecycle running，当前快照为 2 agent + 1 command。
- T4: 真实 venom 日志可过滤 PanelResize、BridgeSnapshot、SessionStatusView，并只包含几何、数量和动画枚举，不包含 Session 名称、路径或 ID。
- T5: TDD Red：layout reconcile 实际发布 running 而预期 idle；Green：layout 使用 restore_commands=False 后 Bridge self-test 通过，且既有 wake 普通命令恢复断言继续通过。
- Review gate: Skipped — 用户未要求独立或对抗审查。

## Verification

- Passed: Bridge self-test、py_compile 与 git diff --check 通过；真实睡眠/唤醒验证需用户运行新构建后触发。
