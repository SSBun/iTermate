# 配置面板背景样式

Status: Completed (2026-08-07 11:43)

## Scope

- 包含：为整个浮动面板提供 System/Dark/Light × Blur/Opaque 六种背景预设。
- 包含：强制 Dark/Light 时同步调整面板文字、图标和控件配色以维持对比度。
- 不包含：模糊强度、透明度滑杆、自定义背景色或图片。

## Target

- [x] T1：General Settings 的 Appearance 区域提供六种 Background Style，默认保持当前 System Blur。
- [x] T2：Blur 使用系统 Material，Opaque 使用不透明语义窗口背景；Dark/Light 作用于整个面板，System 跟随 macOS 外观。
- [x] T3：选择结果即时生效并持久化到现有配置文件，重建 AppSettings 后保持一致。
- [x] T4：现有面板布局、悬停、Session 操作和设置保持不变，相关测试与 macOS 构建通过。

## Plan

1. 在现有配置模型中加入单一 Background Style 枚举与持久化字段。
2. 在 Appearance 设置和面板根背景接入对应的 Material、语义背景及整体配色。
3. 添加最小映射与持久化测试，并运行相关测试和 Debug 构建。

## Result

- T1：General Settings 的 Appearance 区域新增 Background Style Picker，按固定顺序提供 System Blur、Dark Blur、Light Blur、System Opaque、Dark Opaque 与 Light Opaque，缺省值为 System Blur。
- T2：面板根视图按预设在 `.regularMaterial` 与语义 `windowBackgroundColor` 之间切换，并在根环境统一应用 System/Dark/Light 配色，使文字、图标、控件与背景同步变化。
- T3：`panel_background_style` 已加入现有 TOML 配置读写；设置对象继续作为单一状态源，修改会即时触发面板重绘。映射与重建持久化测试通过。
- T4：Swift 解析、`git diff --check`、40/40 全量测试及 Debug build 均通过。未启动真实 App，以免改变当前 Bridge 安装态；六种样式的最终窗口视觉仍需人工确认。
- Review gate: Skipped — no explicit user request.
