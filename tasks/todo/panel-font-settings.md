# 配置浮动面板字体

Status (2026-07-30 12:44): Completed

## Target

- [x] T1：用户可通过 macOS 原生字体面板选择任一本机已安装的字体字形和字号，选择即时应用于浮动面板。
- [x] T2：所选字体的 PostScript 名称与字号持久化到 `~/.iTermate/config.toml`，无效或已卸载字体安全回退为系统字体。
- [x] T3：字体配置的默认值、持久化及不可用字体回退有自动化验证。

## Result

- T1：Basic Settings 的 Appearance 区域通过 `NSFontManager` 打开原生字体面板；选择的字体与字号立即用于浮动面板的文本层级。
- T2：`panel_font_name` 与 `panel_font_size` 保存精确字形和字号；无法构造的字体回退到同字号系统字体。
- T3：`PanelLayoutTests.testPanelFontDefaultsPersistsAndFallsBackWhenUnavailable` 覆盖默认值、持久化与回退；`xcodebuild -project iTermate.xcodeproj -scheme iTermate -destination 'platform=macOS' test` 通过 34/34。
- Review gate: Skipped — no explicit user request.
