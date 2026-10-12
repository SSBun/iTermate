# 调查 Session 仅显示目录而非当前任务摘要的原因

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-12 17:22) |
| Kind | Plan |

## Target

- [ ] T1: 查明截图中的 Session 行为何显示目录及 shell 标题而非当前工作任务摘要，并以实际数据流证据说明原因与尚未确认之处。

## Scope

- 只调查实时 Session 标题的数据来源，不修改应用、集成或用户安装态，不运行测试、不重启进程。

## Decisions

- 当前实时行展示终端标题，不具备当前任务摘要通路：`iTermate/iTermateApp.swift:932,1075` 直接显示经空白裁剪的 `session.name`；`iTermate/ItermBridge.swift:121` 的快照没有任务摘要字段。
- `iTermateBridge/iTermateBridge.py:842-899` 读取 Session 动态 name，并以 Tab title 覆盖该 Tab 当前 Session 的名称；不是从任务记录生成标题。
- `integrations/pi/iTermate-integration.ts:109-146` 的生命周期上报包含状态、退出码、心跳与子代理活动，不包含工作任务摘要。现有 summarizeArchive 只在归档请求时执行，不能作为实时标题来源。
- 2026-10-12 只读连接当前 Bridge socket 获取快照，native-short-reader 的四个 Session 的 name 均为 `π - native-short-reader ('zsh (kiro-cli-term)')`，与用户截图一致；因此缺失发生在 UI 展示之前，不是文字截断隐藏了摘要。状态与截图拍摄时可能不同。
- 当前磁盘安装 Bridge 与仓库源码 SHA-256 均为 `5bfffb75b109b40d1dbe68fe3a839fbd57eab49421b3b328bf0a0df8c47118bb`；仅证明磁盘内容一致，不宣称运行进程内存代码或 App 二进制与当前源码完全一致。
- 尚未追查 Pi 或 shell 内部如何形成该终端标题；不影响 iTermate 实时数据没有任务摘要这一结论。

## Plan

1. 向用户说明当前标题通路与归档摘要的区别，给出源码及运行快照证据。
2. 如用户后续要求实现，另行对齐实时摘要来源、更新时机与缺失时回退规则；本次调查不授权实现。
