# 将 Basic 设置改为卡片布局

Status (2026-07-30 12:54): Completed

## Scope

- 包含：Basic 标签采用参考图的分区标题、圆角描边卡片、左侧说明与右侧原生控件布局，并随系统浅/深色外观适配。
- 不包含：修改 Agents、About 标签内容，或强制 App 使用深色外观。

## Target

- [x] T1：Basic 设置以大写分区标题和圆角描边卡片展示 Appearance、Sessions、Notifications，视觉层级与参考图一致。
- [x] T2：每项保留左侧名称/说明及右侧控件，字体、Session 显示、项目路径标题和通知配置的原有行为及禁用状态不变。
- [x] T3：设置窗口能完整容纳新布局或垂直滚动，且构建与现有测试通过。

## Result

- T1：Basic 标签改用大写 section 标题、语义色圆角描边卡片与行分隔；每行的文字信息在左，原生控件在右。
- T2：保留原有字体、Session 时间、Tab 标题、路径标题和完成通知绑定；相关依赖条件仍禁用并降低对应行的不透明度。
- T3：设置窗口调整为 620×520pt，Basic 内容使用无指示器的垂直滚动；`xcodebuild -project iTermate.xcodeproj -scheme iTermate -destination 'platform=macOS' test` 通过 34/34，`swiftc -parse iTermate/SettingsViews.swift` 与 `git diff --check` 通过。
- Review gate: Skipped — no explicit user request.
