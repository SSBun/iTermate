# 【开发者自荐】iTermate：开源的原生 macOS 终端伴侣，让 iTerm2 / Ghostty 的活动状态实时可见

> 无需离开终端，iTerm2 与 Ghostty 的每个 Session、每条命令、每个编程 Agent 的动态，都在眼前一块实时面板里。

---

## 为什么会有这个项目

终端窗口开得越多，越容易失控：哪个 Tab 里的构建跑完了？哪个 Agent 正在工作、哪个在等你输入？项目又散落在哪几个窗口里？

iTermate 就是为解决这个问题而生的：它像一块「状态屏」一样贴在当前前台终端窗口旁，实时汇总你所有的 Window → Tab → Session，并把**普通 Shell 命令**与**编程 Agent（Pi / Codex）**的运行、完成、失败、等待输入状态变成一眼可读的动画图标。

**它完全不需要 macOS 辅助功能（Accessibility）权限**——iTerm2 通过官方 API 与本机 Python Bridge 读取，Ghostty 使用官方 AppleScript 接口；App 由原生 SwiftUI/AppKit 编写，全程本机通信，不采集任何云端数据。

**那为什么不基于 tmux / Zellij，或者干脆做一个 AI 终端？**

这是被问得最多的问题。因为自从 AI 出现以后，终端工具已经变成了和 Todo、日历一样的**新手项目**——每个人都要写一个。但真正每天承载我工作、被成千上万用户打磨了十几年的，还是 iTerm2、Ghostty 这样成熟的终端，它们才是最稳定、最合适的选择。

所以 iTermate 的定位很克制：**不重造终端，只做终端的「状态屏」**——在成熟终端旁边，用官方 API 补上实时状态这一块拼图。

## 核心能力

- **始终紧随当前工作区**：跟随前台终端窗口自动出现，终端不在前台时自动隐藏，零打扰。
- **灵活组织 Session**：按 Window 或 Project Path 分组，可折叠的 Tab 子分组，跨窗口聚合同一项目。
- **直接操作 Session**：点击聚焦、悬停关闭，或一键关闭整个 Window / Tab / 项目分组，面板两侧可调宽度。
- **实时活动状态**：区分普通 Shell 命令与编程 Agent 工作，显示运行 / 完成时间，完成时可选系统通知。
- **可配置状态视觉**：Running、Success、Failed 等每种状态都可独立选择 Alien、Robot、Classic 三种点阵动画与颜色，并实时预览。
- **编程 Agent 集成**：可选接入 [Pi](https://github.com/badlogic/pi-mono) 与 [Codex](https://github.com/openai/codex) 生命周期状态，Agent 等待输入时显示低干扰的静止图标。
- **项目个性化**：固定、收藏项目目录，并可为每个项目设置专属颜色。
- **原生 macOS 体验**：登录时启动、菜单栏控制、深浅外观、模糊背景、Sparkle 自动更新。
- **Ghostty 支持**：除 iTerm2 外，也支持 [Ghostty](https://ghostty.org/) 终端，同一套面板体验。

## 截图

![iTermate 在 iTerm2 窗口旁展示分组 Session 及其活动状态](https://raw.githubusercontent.com/SSBun/iTermate/main/docs/images/itermate-preview.webp)

![iTermate 应用图标](https://raw.githubusercontent.com/SSBun/iTermate/main/iTermate/Assets.xcassets/AppIcon.appiconset/icon_512x512.png)

> **配图说明**：更多功能截图（状态动画设置、Project Path 分组、Agent 集成配置、Ghostty 跟随等）请从应用内截取后替换此处，建议 16:10 或 4:3 横图、浅色深色各一组。

## 价格

**完全免费，代码开源。** 无内购、无订阅、无云服务，所有状态读取与渲染都在本机完成。欢迎在仓库提交 Issue 与 PR。

## 仓库与下载

- 仓库地址：<https://github.com/SSBun/iTermate>
- 下载最新版：<https://github.com/SSBun/iTermate/releases/latest>
- 系统要求：macOS 13 Ventura 及以上，Apple Silicon（arm64），需已安装 iTerm2 或 Ghostty

> [!IMPORTANT]
> 当前公开构建为 ad hoc 签名、未经 Apple 公证，请核对发布页 `.sha256` 文件；若 macOS 拦截首次启动，Control 点击 App → 打开即可。

安装后打开 iTermate；使用 iTerm2 时，它会自动安装并管理随 App 分发的 Bridge，无需单独配置 Python。在 Settings → Agents 里启用 Pi / Codex 集成即可看到 Agent 状态。

## 写在最后

iTermate 是我业余时间用 Swift 5 写的原生 macOS 应用，目前仍在快速迭代中（Ghostty 支持已在 v0.3.0 落地）。如果你和我一样经常开着十几个终端窗口同时跑构建和 Agent，欢迎试试它——好用的话，一个 Star 就是最大的支持 🌟

有问题或想法，直接来 <https://github.com/SSBun/iTermate/issues> 聊聊。
