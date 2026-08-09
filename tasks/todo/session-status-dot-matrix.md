# 使用点阵屏动画展示 Session 状态

Status: Completed (2026-08-06 20:41)

## Scope

- 包含：以 36×16pt 的 AppKit 点阵屏替换 Session 行现有的运行与完成状态图标。
- 包含：Agent 外星人与普通命令机器人使用不同 Sprite 动画并带独立状态条；运行、成功、失败和未知完成结果持续动画，空闲不显示。
- 包含：点亮像素在模糊背景上保持全不透明，并通过向白色混合而非降低透明度表现动画亮度。
- 不包含：修改 Agent lifecycle、Shell PromptMonitor、前台任务 fallback、heartbeat 或状态清理判定。

## Target

- [x] T1：Session 快照携带由真实观察路径确定的 Agent/普通命令类型，既有状态观察与完成判定保持不变。
- [x] T2：Session 行使用 18×8 逻辑点阵、36×16pt AppKit 视图展示状态；Agent 与普通命令动画不同，运行、成功、失败和未知结果均可区分并持续动画，空闲不显示。
- [x] T3：动画不通过整体显隐制造闪烁；离开窗口后停止刷新，系统启用减少动态效果时显示静态关键帧。
- [x] T4：Bridge 自检、Swift 测试、完整构建与真实 App 启动通过，现有 Session 状态观察行为无回归。
- [x] T5：Agent 使用外星人、普通命令使用机器人，右侧均带状态条；各状态通过角色动作和状态条动画区分，帧率为 20 FPS，未点亮像素完全透明。
- [x] T6：确定性动画测试、完整构建和真实 App 截图确认头像布局、动画持续性与既有状态观察无回归。
- [x] T7：所有点亮像素保持 100% 不透明，动画亮度由语义色向白色混合产生；未点亮像素仍完全透明且不增加背景或描边。
- [x] T8：颜色计算测试、完整构建与真实 App 截图确认紫色和橙色头像在模糊背景上的对比度提升。

## Plan

1. 将点亮像素从透明度动画改为全不透明的颜色亮度动画。
2. 为颜色不透明度和亮度变化增加确定性检查。
3. 重新构建并在真实模糊面板上检查紫色与橙色头像。

## Result

- T1：Bridge 的 Agent lifecycle 写入 `activityKind: agent`，PromptMonitor 与原生前台任务 fallback 写入 `activityKind: command`；字段随既有状态快照传递，未修改 heartbeat、观察器或完成判定。Bridge self-test 与真实 Socket 快照均确认当前运行中的 Pi Session 标记为 `agent`。
- T2：Session 行已用 36×16pt AppKit 点阵视图替换沙漏及完成图标；七种动画模式以 Agent 外星人和普通命令机器人覆盖运行、成功、失败及未知结果，空闲保持无图标。真实 Debug App 截图确认 18×8 头像和状态条在 Session 行内正确显示。
- T3：所有动画帧始终至少保留一个亮点且模式序列互不相同；`NSView` 只在进入窗口且未启用减少动态效果时以 20 FPS 刷新，离开窗口或开启减少动态效果时停止计时并显示静态首帧。
- T4：Bridge `--self-test`、`py_compile`、Swift parse、`git diff --check` 与完整 Xcode 测试通过，37/37 测试成功；`venom-cli -p "$PWD" build --run` 构建并启动 Debug App，App PID 为 18984、Bridge PID 为 18989，源码、bundle 与已安装 Bridge 哈希一致。
- T5：外星人通过视线、跳跃和故障位移表达 Agent 状态；机器人通过眼睛扫描、点头、摇头和眨眼表达普通命令状态；两类头像右侧状态条同步动画。绘制循环跳过亮度为零的像素，不再绘制低亮度背景点。
- T6：确定性测试逐帧验证七种模式始终包含头像和状态条、模式持续变化且头像与状态条之间保持透明间隔；最终完整 Xcode 测试 37/37 通过，真实截图分别确认紫色外星人与橙色机器人可辨识且无点阵背景。
- T7：绘制路径现在跳过亮度为零的像素；其余像素统一以 alpha 1 绘制，并把 0.35–1 的动画亮度映射为语义色与 20.5%–40% 白色的混合，不增加背景、描边或光晕。
- T8：新增颜色测试逐个验证七种模式的基础色和高亮色均完全不透明，且高亮色亮度更高；完整 Xcode 测试 38/38 通过。`venom-cli -p "$PWD" build --run` 已重启 App（PID 23358）与 Bridge（PID 23363），真实模糊面板截图确认紫色外星人与橙色机器人对比度明显提高。
- Review gate: Skipped — no explicit user request (contrast follow-up).
