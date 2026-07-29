# 设计 iTermate 菜单栏状态图标

Status (2026-07-29 19:02): Completed

## Scope

- 包含：设计一个可缩放的 SVG 模板图标，将其加入 App 资源并用于 macOS 菜单栏入口。
- 不包含：修改应用主图标、修改状态菜单内容或复制参考图中的具体品牌图形。
- 本次跟进包含：将菜单栏状态图标替换为用户提供的透明 PNG，保持现有菜单入口和模板着色行为。
- 本次跟进包含：为用户提供的 PNG 增加内部透明留白，降低实际可见绘制区域，不改变菜单入口 frame。
- 本次跟进包含：替换为用户指定的 `terminal-icon.png`，并转换为适配模板渲染的透明单色资源。
- 本次跟进包含：保留 `terminal-icon.png` 的原始高分辨率，不再将源图降采样到 24×24px。
- 本次跟进包含：修正 `MenuBarExtra` 对自定义图片忽略 SwiftUI frame 的运行时尺寸行为。
- 本次跟进包含：在保留原始高分辨率资源的前提下，将运行时图标高度从 16pt 调整为 18pt。

## Target

- [x] T1：交付一个适合 macOS 菜单栏尺寸的 SVG 矢量状态图标，语义包含终端与伴随/连接关系。
- [x] T2：图标在浅色和深色菜单栏上均可读，并通过 Xcode 资源编译和项目构建验证。
- [x] T3：按用户选择使用官方 Tabler Terminal 2 SVG，并保留 MIT 许可声明。
- [x] T4：将菜单栏显示尺寸从 18×18pt 调整为 16×16pt，保持 SVG 资源和模板渲染不变。
- [x] T5：在 SVG 内增加明确的 32×32 viewBox 留白并固定模板色，令实际可见绘制区域从原先约 75% 缩小到约 62.5%，避免仅改变外层 frame 而无明显视觉变化。
- [x] T6：菜单栏入口使用用户提供的透明 PNG，并保留浅色/深色模板着色与 16×16pt 显示尺寸。
- [x] T7：用户 PNG 的实际可见绘制区域缩小到适合菜单栏的尺寸，同时保留原始图形、模板着色和 16×16pt frame。
- [x] T8：菜单栏使用用户指定的 `terminal-icon.png` 图形，并保留模板着色、内部留白与 16×16pt frame。
- [x] T9：菜单栏资源保留用户源 PNG 的原始 554×549px 分辨率，仅由运行时 16pt 图像尺寸控制显示大小。
- [x] T10：自定义菜单栏图片在运行时按 16pt 高度显示，保持原始分辨率和宽高比，不再按源 PNG 像素尺寸撑大菜单栏。
- [x] T11：自定义菜单栏图片在运行时按 18pt 高度显示，保持原始分辨率、宽高比和模板渲染。

## Plan

1. 保留用户指定的 `terminal-icon.png` 原始像素尺寸，仅转换模板所需的颜色/透明度。
2. 在 AppKit 图像层显式设置目标点尺寸，保持 `MenuBarExtra` 的状态菜单内容不变。
3. 用 `actool`、Xcode 构建和实际菜单栏运行验证分辨率与视觉尺寸。

## Result

- T1：将官方 Tabler Terminal 2 的 24×24 SVG 放入 `iTermate/Assets.xcassets/StatusIcon.imageset`，并保留 `template-rendering-intent`，供菜单栏模板着色。
- T2：`xcrun actool` 成功编译 `Assets.xcassets`；用蓝色背景渲染预览确认终端轮廓、命令提示符和圆角边框清晰；`xcodebuild ... build test` 成功。
- T3：来源为 Tabler 官方图标页及 `@tabler/icons` CDN，许可为 MIT；版权和许可文本记录在 `THIRD-PARTY-NOTICES.md`。
- Delivered: `iTermateApp.swift` 已将 `MenuBarExtra` 从 SF Symbol 替换为 `Image("StatusIcon").renderingMode(.template)`。
- T4：根据用户提供的尺寸参考，将 `iTermateApp.swift` 中的菜单栏标签 frame 从 18×18pt 改为 16×16pt；SVG 内容未变，`xcodebuild ... build test` 与 `git diff --check` 通过。
- T5：用户反馈外层尺寸变化不明显；将 `status-icon.svg` 改为 32×32 viewBox、内容居中平移 4px，并固定黑色模板 stroke。`rsvg-convert` 渲染预览确认可见边界约为 150×136/240（约 62.5%），`actool` 和 `xcodebuild ... build test` 通过。
- T6：将用户提供的 24×24 透明 PNG 安装为 `StatusIcon.imageset/status-icon.png`，同步更新资源清单和第三方资源说明；保留 `template-rendering-intent`、`Image("StatusIcon").renderingMode(.template)` 与 16×16pt frame。`xcrun actool` 成功，`assetutil` 确认 `StatusIcon` 使用 `status-icon.png` 且为 template mode，Xcode Debug build 和实际菜单栏重启验证通过。
- T7：不改变用户提供的终端图形，仅将其缩放到 15×15px 并居中放入 24×24px 画布，实际可见边界由 `24×24+0+0` 变为 `15×15+4+4`；重新运行 `actool`、Xcode Debug build、`assetutil` 和菜单栏截图验证，图标视觉尺寸已缩小。
- T8：将用户指定的 `terminal-icon.png` 转换为模板友好的单色透明资源，缩放到 18×18px 画布后居中放入 24×24px；当前可见边界为 `17×15+4+5`，保留终端气泡、提示符和下划线负空间。`actool`、Xcode Debug build、`assetutil` 与实际重启验证通过。
- T9：不再缩放或重采样源图；`StatusIcon` 直接使用 554×549px 资源，模板转换只改变颜色/透明度，源图可见边界为 `475×412+42+84`，显示大小由运行时 16pt 图像尺寸控制。`actool`、Xcode Debug build、`assetutil` 和实际重启验证通过。
- T10：`MenuBarExtra` label 改为先将 `NSImage(named: "StatusIcon")` 按原始宽高比设置为 16pt 高，再创建 `Image(nsImage:)`；移除无效的 SwiftUI `.resizable().frame(...)` 约束。高分辨率资源仍为 554×549px，运行时截图确认不再按源 PNG 像素尺寸撑大。
- T11：将 AppKit 图像层的目标高度从 16pt 调整为 18pt，仍保持 554×549px 源图、原始宽高比和 template rendering；重新构建、重启并截图验证通过。
- Review gate: Skipped — 用户未要求独立审查；图标资源替换不涉及关键风险，资源编译、bundle 检查和实际运行验证均已通过。
