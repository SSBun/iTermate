---
title: 通用经验
summary: 项目内源码交付、安装与运行边界，以及 macOS 界面和通知验证经验。
---

- [2026-11-08] 真实视觉/运行验证涉及 venom-cli build --run、open 或启动/重启 App、Bridge 时，MUST 核对 tasks/lessons.md 的禁止自行启动条目和当前会话授权。默认 MUST 仅做不启动/重启的源码检查、构建、测试；交付时 MUST 提示用户自行重新构建运行，收到确认后再观察。构建通过不授权替换运行实例；MUST NOT 以验证为由擅自启动、替换或重启 App、Bridge。
- [2026-11-08] 修改常驻 Bridge、daemon 或 AutoLaunch helper 的协议或版本时，MUST 区分磁盘安装版本与运行中实例；旧进程可能继续持有 socket 或单实例锁，替换文件不证明运行升级，App 重连也不证明 helper 重启。
- [2026-11-10] 默认由用户运行新版 App；仅当前会话明确授权运行升级时才考虑 helper 重启，MUST 保留 iTerm2 主进程及终端会话。运行升级验收 MUST 确认旧 helper 退出、新实例接管 socket、运行实例与源码和安装文件一致、App 连接并收到快照。当前 App 自管安装及重启 Bridge，内部不做协议版本校验；MUST NOT 为验证版本一致性而新增 App↔Bridge 版本握手校验，独立更新的集成仍按其格式兼容边界处理。仅完成源码或磁盘替换时 MUST 如实说明；操作入口见 tasks/lessons.md，MUST 同时核对较新的运行限制和当前授权。
- [2026-11-05] 修改随 App 分发的 Bridge、hook 或 agent integration 源码不等于授权安装：用户未明确要求安装、启用或覆盖运行时副本时，MUST 仅修改仓库源码和构建产物，MUST NOT 直接覆盖 ~/.pi、~/.codex 或 iTerm AutoLaunch 等用户安装目录。运行验证 MUST 使用临时目录、受控 mock 或已授权的 App 自有安装入口；改变用户安装态前 MUST 取得明确许可。完成前 MUST 检查用户安装目录未被擅自覆盖，交付 MUST 区分源码已构建与用户已安装/启用。
- [2026-11-08] macOS SwiftUI 滚动条：MUST NOT 仅凭 .scrollIndicators(.hidden) 或构建通过判定隐藏；SHOULD 优先使用 ScrollView(showsIndicators: false)，运行画面 MUST 无指示器且溢出内容仍能滚动。菜单栏/LSUIElement 的 Settings：macOS 14+ MUST 激活 App 后调用 openSettings；selector/button action 触发不证明窗口创建。MUST 逐入口核对实际构建产物路径，防 LaunchServices 打开同 bundle ID 旧副本，并通过 Accessibility 观察窗口创建且可见。
- [2026-11-08] UNUserNotificationCenter：add MUST 提供 completion handler 记录系统错误；完整状态转换后 MUST 核对 usernoted 接受、投递与展示。诊断信号为 hasError: 0、Delivering、Presenting ... as banner；失败日志为 iTermate notification failed 及系统错误。验证 MUST 单实例且签名 identifier=CFBundleIdentifier，MUST NOT 用 CODE_SIGNING_ALLOWED=NO 产物验证原通知授权身份；运行中重构建/签名后 MUST 重新运行再验证。
- [2026-11-08] NSPanel 默认 MUST 接收覆盖区域点击；仅用户明确要求 click-through 时才启用穿透。默认验收 MUST 检查 ignoresMouseEvents=false 且点击不命中下层应用。上述 macOS 界面与通知的真实运行验证 MUST 遵守当前项目启动授权限制，默认由用户重新构建运行后观察。
