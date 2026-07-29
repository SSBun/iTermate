# 设计 iTermate 菜单栏状态图标

Status (2026-07-29 00:45): Completed

## Scope

- 包含：设计一个可缩放的 SVG 模板图标，将其加入 App 资源并用于 macOS 菜单栏入口。
- 不包含：修改应用主图标、修改状态菜单内容或复制参考图中的具体品牌图形。

## Target

- [x] T1：交付一个适合 macOS 菜单栏尺寸的 SVG 矢量状态图标，语义包含终端与伴随/连接关系。
- [x] T2：图标在浅色和深色菜单栏上均可读，并通过 Xcode 资源编译和项目构建验证。
- [x] T3：按用户选择使用官方 Tabler Terminal 2 SVG，并保留 MIT 许可声明。
- [x] T4：将菜单栏显示尺寸从 18×18pt 调整为 16×16pt，保持 SVG 资源和模板渲染不变。
- [x] T5：在 SVG 内增加明确的 32×32 viewBox 留白并固定模板色，令实际可见绘制区域从原先约 75% 缩小到约 62.5%，避免仅改变外层 frame 而无明显视觉变化。

## Plan

1. 以用户参考图的终端与伙伴关系为灵感，设计单色模板 SVG。
2. 将 SVG 加入 `StatusIcon.imageset`，并替换 `MenuBarExtra` 的 SF Symbol 标签。
3. 用 `actool` 和 Xcode 测试构建验证资源与集成。

## Result

- T1：将官方 Tabler Terminal 2 的 24×24 SVG 放入 `iTermate/Assets.xcassets/StatusIcon.imageset`，并保留 `template-rendering-intent`，供菜单栏模板着色。
- T2：`xcrun actool` 成功编译 `Assets.xcassets`；用蓝色背景渲染预览确认终端轮廓、命令提示符和圆角边框清晰；`xcodebuild ... build test` 成功。
- T3：来源为 Tabler 官方图标页及 `@tabler/icons` CDN，许可为 MIT；版权和许可文本记录在 `THIRD-PARTY-NOTICES.md`。
- Delivered: `iTermateApp.swift` 已将 `MenuBarExtra` 从 SF Symbol 替换为 `Image("StatusIcon").renderingMode(.template)`。
- T4：根据用户提供的尺寸参考，将 `iTermateApp.swift` 中的菜单栏标签 frame 从 18×18pt 改为 16×16pt；SVG 内容未变，`xcodebuild ... build test` 与 `git diff --check` 通过。
- T5：用户反馈外层尺寸变化不明显；将 `status-icon.svg` 改为 32×32 viewBox、内容居中平移 4px，并固定黑色模板 stroke。`rsvg-convert` 渲染预览确认可见边界约为 150×136/240（约 62.5%），`actool` 和 `xcodebuild ... build test` 通过。
- Review gate: Skipped — 用户未要求独立审查；图标资源替换不涉及关键风险，也不同时满足两类复杂性与验证缺口，资源编译、预览和项目测试均已通过。
