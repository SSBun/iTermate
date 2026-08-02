# 修复 Session 选择后的标题与状态错配

Status: Completed (2026-07-31 17:53)

## Target

- [x] T1：选择任一 Session 后，该单元格继续显示同一 Session 的正确标题，不会显示其他 Session 的标题。
- [x] T2：选择切换不会让运行或完成状态图标关联到错误的 Session，当前运行状态显示正确图标。
- [x] T3：相关回归测试与应用构建通过。
- [x] T4：选择 Session 后，单元格继续显示 iTerm 当前可见的 Session 标题，不退化为用户名或 shell 名称。
- [x] T5：新增回归检查覆盖“选中后动态名称仍非空但已变为 fallback”并通过完整构建测试。
- [x] T6：Bridge 已发布正确新标题时，Session 行无需等待后续状态变化即可立即重绘该标题。
- [x] T7：真实选择 Session 后的窗口截图不再短暂显示用户名或 shell fallback。

## Plan

1. 同步采集 Bridge 广播与 iTermate 窗口截图，定位正确快照到错误渲染之间的断点。
2. 修正 Session 行对标题变化的视图身份刷新条件。
3. 通过自动选择、定时窗口截图、Bridge 自检与完整 Xcode 测试验证。

## Result

- T1：Bridge 回归自检先复现“动态标题瞬时为空、对象属性变为 `caishilin (python)`”时覆盖正确标题；修复后已有非空缓存优先于瞬态对象属性。部署后的真实选中 `babyfs-ios · 课程配音 API 调研 (pi)` 单元格保持正确标题。
- T2：Session 单元格身份现在包含状态与退出码，运行状态变化会重建对应行。真实 App 注入 `running` 快照后，选中的 babyfs Session 显示橙色沙漏与 `Running · 0m`，随后已发送 `detached` 清理验证状态。
- T3：`py_compile`、Bridge `--self-test`、`git diff --check` 与完整 Xcode 测试通过；共 32 个测试、0 失败。Debug App 已启动，已安装 Bridge 与源码 SHA-256 一致。
- T4：现场变量对比确认 `tab.title` 表示 iTerm 当前可见标题，而选中的 `session.name` 仍可能短暂变成 `caishilin (zsh)`；Bridge 现在只对每个 Tab 的当前 Session 用该 Tab 标题覆盖行标题，未选中的 Session 继续使用各自动态名称。
- T5：Bridge self-test 先稳定复现“选中后动态名称非空但为 fallback、Tab 标题仍正确”的失败，修复后通过；`py_compile`、`git diff --check` 与完整 Xcode 测试 35/35 通过，构建产物 Bridge 哈希与源码一致。
- T6：同步追踪确认 Bridge 在选择后 0.012 秒和 0.020 秒的快照已携带正确标题，但面板在 0.15 秒仍显示旧 fallback，直到后续状态变化改变显式视图 ID 才重绘；Session 行的显式 ID 现已包含名称，名称变化本身即可触发重建。
- T7：重新构建并启动 Debug App 后，通过 iTerm API 创建临时 Session、选择该 Session，再把 Tab 标题从 `zsh` 改为 `Expected selected title`；Bridge 广播序号 125 后 0.15 秒的窗口截图已显示新标题，临时 Session 随后强制关闭并恢复原活动 Session。Swift 解析、Bridge self-test、`git diff --check` 与完整 Xcode 测试 35/35 通过。
- Review gate: Skipped — no explicit user request.
