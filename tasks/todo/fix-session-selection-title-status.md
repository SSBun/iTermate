# 修复 Session 选择后的标题与状态错配

Status (2026-07-30 22:12): Completed

## Target

- [x] T1：选择任一 Session 后，该单元格继续显示同一 Session 的正确标题，不会显示其他 Session 的标题。
- [x] T2：选择切换不会让运行或完成状态图标关联到错误的 Session，当前运行状态显示正确图标。
- [x] T3：相关回归测试与应用构建通过。

## Plan

1. 复现并追踪 Session 标识、动态标题与状态从 Bridge 到单元格的关联关系。
2. 先增加聚焦回归测试，再在共享根因处做最小修复。
3. 运行相关测试、完整测试与应用构建，记录结果。

## Result

- T1：Bridge 回归自检先复现“动态标题瞬时为空、对象属性变为 `caishilin (python)`”时覆盖正确标题；修复后已有非空缓存优先于瞬态对象属性。部署后的真实选中 `babyfs-ios · 课程配音 API 调研 (pi)` 单元格保持正确标题。
- T2：Session 单元格身份现在包含状态与退出码，运行状态变化会重建对应行。真实 App 注入 `running` 快照后，选中的 babyfs Session 显示橙色沙漏与 `Running · 0m`，随后已发送 `detached` 清理验证状态。
- T3：`py_compile`、Bridge `--self-test`、`git diff --check` 与完整 Xcode 测试通过；共 32 个测试、0 失败。Debug App 已启动，已安装 Bridge 与源码 SHA-256 一致。
- Review gate: Skipped — no explicit user request.
