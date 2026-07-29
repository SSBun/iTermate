# 创建标准设置页与菜单栏状态视图

Status (2026-07-29 13:47): Completed

## Scope

- 包含：使用 macOS SwiftUI Scene 构建带 Basic、About 标签的设置窗口，以及展示 Bridge 摘要和常用操作的菜单栏状态视图。
- 不包含：登录时启动、手动隐藏面板、Bridge 高级控制或新增偏好项。
- 本次跟进包含：移除 Basic Settings 中的 Panel/Width 配置 UI。
- 本次跟进不包含：移除浮动面板的原生边缘拖拽或其宽度持久化支持。
- 本次跟进包含：在浮动面板左下角提供打开 Settings 的齿轮图标。
- 本次跟进包含：将全部用户配置迁移到用户 Application Support 目录下的 TOML 文件，移除 UserDefaults 持久化。
- 本次跟进包含：将 TOML 配置路径切换为用户主目录下的 `.iTermate/config.toml`。
- 本次跟进不包含：读取或迁移旧 Application Support 配置。

## Target

- [x] T1：用户可从菜单栏打开原生 Settings 窗口，并在 Basic、About 两个标签间切换。
- [x] T2：Basic 标签可实时调整 180–600pt 面板宽度、恢复默认值，并沿用跨启动持久化。
- [x] T3：About 标签展示 App 图标、名称、版本和版权信息。
- [x] T4：菜单栏状态视图展示 Bridge 连接状态、窗口数和 Tab 数，并提供 Settings 与 Quit 操作。
- [x] T5：功能兼容 macOS 13，原有面板跟随、调整宽度、Tab 同步和点击行为不回归。
- [x] T6：Basic 标签不再展示 Panel/Width 配置，同时保留面板原生边缘调整和宽度持久化。
- [x] T7：浮动面板左下角显示 Settings 齿轮图标，并可打开原生 Settings 窗口。
- [x] T8：面板宽度、Session 列表样式和 Tab 标题开关全部从用户 TOML 配置文件读写，不再使用 UserDefaults。
- [x] T9：用户直接编辑有效 TOML 配置后，应用下次启动能加载修改值，并继续执行默认值和宽度边界约束。
- [x] T10：默认配置文件路径为用户主目录下的 `.iTermate/config.toml`，而不是 Application Support 目录。
- [x] T11：配置加载只访问用户主目录下的 `.iTermate/config.toml`，不读取旧 Application Support 配置。

## Plan

1. 保持 `AppSettings` 的默认配置路径为用户主目录下的 `.iTermate/config.toml`。
2. 移除旧 Application Support 配置读取逻辑，保留当前 TOML 读写和默认值行为。
3. 更新路径回归测试，运行构建、测试与差异检查。

## Result

- T8：`AppSettings` 使用 TOML 文件作为唯一持久化源，写入 `panel_width`、`session_list_style` 和 `shows_tab_headers`；`iTermate` 与测试代码中已无 `UserDefaults` 引用。
- T9：TOML 写入与手动编辑加载测试确认编辑后的值可在下次初始化时生效，面板宽度仍执行 180–600pt 约束。
- T10：默认路径改为 `~/.iTermate/config.toml`，首次启动在新路径写入配置。
- T11：已移除旧 Application Support 路径的声明和读取逻辑；测试确认当前配置路径回归通过。
- `xcodebuild -project iTermate.xcodeproj -scheme iTermate test` 通过，共 24 个测试；`git diff --check` 通过。
- Review gate: Skipped — no explicit user request (TOML path follow-up)。

- T1：运行构建产物后，MenuBarExtra 的 Settings 控件打开系统 Settings scene；Accessibility 操作确认 Basic、About 标签可切换，窗口使用原生 TabView/Form 外观。
- T2：Accessibility 将 Basic 滑杆从 260pt 调至 320pt 后，Core Graphics 确认面板实时变为 320pt且 `UserDefaults` 同步；Restore Default 恢复 260pt。测试覆盖 180–600pt 限制、持久化与重置。
- T3：About 运行时窗口展示 App 图标、iTermComrade、`Version 0.1.0 (1)` 与当前年份版权信息；版本来自生成的 bundle metadata。
- T4：运行时菜单栏窗口展示 Bridge 状态、错误详情、Windows/Tab 数量和 Settings/Quit；Accessibility 分别触发 Settings 与 Quit 成功。
- T5：工程 deployment target 保持 macOS 13；macOS 14+ 使用 `SettingsLink`，macOS 13 编译到标准 `showSettingsWindow:` fallback。默认 `xcodebuild test` 运行 13 个测试全部通过，`swiftc -parse`、bundle 版本检查和 `git diff --check` 通过；当前环境无 macOS 13 主机进行 fallback 运行时验证。
- T6：检查 [`SettingsViews.swift`](../../iTermate/SettingsViews.swift) 已移除 Panel/Width 配置，并将设置窗口调整为 220pt；`xcodebuild -project iTermate.xcodeproj -scheme iTermate build test` 通过 17 个测试，覆盖原生边缘调整与宽度持久化行为；`git diff --check` 通过。
- Review gate: Required — SwiftUI Scene、AppKit 面板与持久化状态构成跨组件和状态变更；macOS 13 设置入口缺少对应系统的运行时环境，存在验证缺口。
- Review gate: Skipped — no explicit user request (width-config follow-up).
- T7：检查 [`iTermateApp.swift`](../../iTermate/iTermateApp.swift) 已在面板底部左侧加入 `gearshape` Settings 入口，并保留 macOS 13 fallback；`xcodebuild -project iTermate.xcodeproj -scheme iTermate build test` 通过 17 个测试，`git diff --check` 通过。
- Review gate: Skipped — no explicit user request (panel Settings icon follow-up).
- Review decision: `APPROVED` — 2 次 Reviewer pass 后无未解决 finding；[审查报告](../../reports/adversarial-review/settings-and-status-menu.md)。
