# 调查 venom 调试会话未显示雷达图标的原因

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-12 15:42) |
| Kind | Plan |

## Target

- [ ] T1: 解释截图中 venom-cli 调试会话未显示雷达图标的原因，区分已验证事实与待验证推测。

## Scope

- 只读调查截图、当前 Bridge 快照、原生进程观察与相关源码；不修改产品代码、运行配置，不重启 App 或 Bridge，不运行测试套件。

## Decisions

- 雷达表示活跃日志采集阶段，不代表整个 `venom-cli build --run --debug` 生命周期。`iTermate/VenomDebugMonitor.swift` 要求前台 venom debug build 具有活跃的直接日志采集子进程；`iTermate/ItermBridge.swift:1042-1073` 另要求普通 running 命令、唯一 TTY 和匹配的状态时间戳。
- 截图先出现 Recording，随后出现 Rebuilding，最新停在 Installing。实际安装入口 `/Users/caishilin/.local/share/mise/installs/node/22/bin/venom-cli` 指向 `/Users/caishilin/Desktop/work/apps/venom-cli/node-bin/venom-cli.js`；同项目 `src/commands/android-build.js:175-272` 表明按 r 后先结束旧 logcat，在 close 事件后打印 Rebuilding；再次安装、启动成功并取得 PID 后才创建新 logcat。因此截图中的构建安装阶段不显示雷达符合当前设计，而上方 Recording 是上一轮输出。
- 本次实时观察中 Futureve 会话 727593B4-125B-4B8E-BC9F-9283D49117A5 的 Bridge 快照为 running/command，TTY 为 /dev/ttys026 且唯一；嵌套 PTY /dev/ttys027 上 venom PID 96794 的直接子进程 47048 为 adb logcat --pid=22027。通过 swift 标准输入执行未经修改的 VenomDebugMonitor 源码并调用 monitoringTTYs，实测返回包含 /dev/ttys026 与 /dev/ttys027，说明当前进程检测已经能识别该会话。
- 当前检测结果不证明截图时的历史进程状态，也不直接证明当前 SwiftUI 已显示雷达；没有读取 App 私有 Store 或获取新的 UI 截图，不把源码诊断当作 UI 验证。

## Plan

1. 向用户解释截图处于重建安装阶段及雷达的实际含义。
2. 若用户确认新的 Recording 阶段依旧没有雷达，再对照同一时刻的 UI、Store 与扫描结果调查；当前证据不支持直接修改检测逻辑。
