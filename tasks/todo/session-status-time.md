# 显示 Session 运行与完成时间

Status (2026-07-30 01:18): In Progress

## Scope

- 包含：在当前 running/finished 状态旁显示自动刷新的时间，并允许在 Basic Settings 中显示/隐藏或选择紧凑、详细格式。
- 不包含：跨 Bridge 重启持久化状态历史、命令历史列表或用户自定义格式模板。

## Target

- [x] T1：运行中的 Session 显示 `Running · 4m` 形式的已运行时间，并在无需新 Bridge 快照时继续更新。
- [x] T2：已完成的 Session 显示 `Finished · 2m ago` 形式的完成时间，原有成功/失败图标与 Session 操作保持不变。
- [x] T3：Bridge 为状态转换提供时间来源，协议及随 App 分发的 Agent integrations 保持同步，并兼容更新前已安装的 integration。
- [ ] T4：Basic Settings 提供默认开启的 Session 时间显示开关，关闭后仍保留原有状态图标。
- [ ] T5：Basic Settings 提供 Compact 与 Detailed 格式选择；Compact 显示 `4m`，Detailed 显示 `4m 32s`，并按各自精度自动刷新。
- [ ] T6：显示开关与格式写入现有 TOML 配置，并能在重启后恢复。

## Plan

1. 将时间显示开关与格式加入共享设置并持久化。
2. 按设置决定时间文本可见性、格式与刷新精度，同时保留状态图标。
3. 覆盖默认值、持久化和两种格式，运行完整验证。

## Result

- T1：Session 状态行使用 SwiftUI `TimelineView` 每 60 秒重新计算显示文本；固定时间用例验证 running 4 分钟输出 `Running · 4m`，无需依赖新 Bridge 快照。
- T2：finished 状态继续保留成功/失败图标、tooltip 与原有 Session 激活/关闭路径，并追加 `Finished · 2m ago` 文本；Swift 编译与 App 测试构建通过。
- T3：Bridge 在每次 running/finished 转换时记录 Unix 时间并随快照发布；Swift、Python、Pi 与 Codex 协议同步升级到 v6，Bridge self-test 验证 v4/v5 已安装 integration 仍可上报。系统 Python 与 iTerm Python 3.14 self-test、py_compile、Swift parse、`git diff --check` 和完整 Xcode 测试通过，31/31 测试成功。
