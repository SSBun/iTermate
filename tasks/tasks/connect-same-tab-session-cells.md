# 用连接线标识同一 Tab 的会话组

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-20 11:46) |
| Artifacts | [Artifacts](../artifacts/connect-same-tab-session-cells/) |
| Kind | Task |

## Scope

只在既有 Tab 会话区块内增加视觉连线；保留图标、行间距、标题开关、折叠、焦点、悬停与激活/关闭操作。不改 Bridge、数据源、会话排序或实际终端布局，不启动或重启 App。

## Plan

1. 核对会话图标与 Tab 容器的实际布局，选择不依赖固定行高的连线位置。
2. 按相邻图标的布局锚点绘制细竖线，限制在各 Tab 容器中并关闭装饰层交互。
3. 编译及语法检查，尽可能使用隔离的离屏预览核对多行、单行、混合行高和分组边界；不运行测试套件。

## Decisions

- 截图红色笔迹表示连接位置，不作为新状态颜色；采用低对比度语义次要色，保持现有图标。
- 行高受 Agent 状态、字体和内容影响；读取图标实际布局锚点，不用硬编码行高推算端点。
- 现有 Lessons 索引未识别旧格式正文，已直接查阅原文并应用不得重启 App、保留视觉参考主体和正确分组层级的约束。

## Task Summary

**会话列表**，组件目录 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/)，为会话环境图标收集实际布局锚点，在每个 Tab 容器内按既有顺序绘制图标间的 1pt 细竖线；连线为语义次要色，不依赖固定行高，不参与命中测试或辅助功能，不改变现有图标和操作。

## Evidence

- [离屏预览源码](../artifacts/connect-same-tab-session-cells/evidence/connector-preview.swift) 提取实际 `SessionIconAnchors`、`SessionGroupConnectors` 和 `SessionEnvironmentIcon`，通过 SwiftUI ImageRenderer 渲染 [深浅色预览](../artifacts/connect-same-tab-session-cells/evidence/connector-preview.png)（1752×778）。这是隔离视觉证据，不是运行中 App 截图。
- 已查看预览：三会话组显示两段对齐竖线；混合字体行高及 Agent/Shell 行高均能衔接；开启 Tab 标题的缩进组对齐正确；不同 Tab、项目及单行、空/折叠组无跨界连线。
- 隔离 Debug 构建通过；`swiftc -parse`、`git diff --check` 通过。未运行单元测试或项目测试套件。
- 未重启运行中的 App（PID 49214，启动时间 11:35:49）或 Bridge（PID 49365，启动时间 11:35:51），未验证真实窗口中的点击、悬停和滚动；装饰层不拦截事件由源码检查确认。

## Target
- [x] T1: 侧边栏中同一项目内同一 Tab 的多个会话，像用户截图标注一样在左侧图标之间显示竖向连接线，直观表达同组关系。
- [x] T2: 连接线不跨越不同 Tab 或项目分组，单会话不显示连接线；保留既有图标、会话顺序与操作。

## Result

- T1: 已查看 Evidence 中 1752×778 SwiftUI 离屏预览：三会话组的两段竖线连接相邻左侧图标，在深浅色及混合字体/行高下对齐。预览提取实现与当前源码完全一致；隔离 xcodebuild Debug build 和 Swift 解析通过。非运行中 App 截图。
- T2: 源码自检与预览共同确认：每 Tab 独立锚点 overlay，仅在 sessions.count > 1 时绘制相邻 ID 对；标题缩进组对齐，跨 Tab/项目、单行和空组均无跨界连线。overlay 禁用命中测试并隐藏辅助功能；对照修改前副本，图标、行顺序、间距及原动作未改；App/Bridge 未重启。真实点击悬停未验证，未运行测试。
- Review gate: Skipped — 当前 R1 四项具体依据齐备：非交互视觉增量，区块与绘制范围已核对，并有编译及深浅色离屏图像证据；无显式或既存独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅新增按真实图标锚点绘制的非交互装饰层，相关布局边界已由编译、源码对照及实际离屏渲染确认。
- Snapshot: sha256:App=694845757a89d41f45c12fc745d76cc5df51316ef6bd09333d156253c117df8e;PreviewSource=32b2d6f55717bad37fcb0569c9d5391ab5eeb80aea29875a4934d067b04ffc20;PreviewPNG=41587dc159c74576eea26ce43d697d5a3c85855ec2d645e3ee5a1688440cffc0
- Evidence: T1/T2 Result 和 Evidence 中的预览源码及图片；离屏预览已查看；构建、解析、diff 和 Context 校验通过；测试未运行。
- Result clarity: 用户确认只为同项目同 Tab 的相邻会话图标连线，不跨组，保留图标、顺序及操作。
- Bounded impact: 限定在 Tab VStack overlay、图标 anchorPreference 和两个私有 UI 类型；单行与折叠状态受现有容器控制，数据源及布局操作未改。
- Low risk: 低风险可恢复的视觉装饰；无持久化、隐私、权限或终端操作变化，overlay 不参与命中测试或辅助功能。
- Sufficient verification: Debug build、Swift 解析、源码 diff 检查通过；提取生产组件生成的深浅色预览实际可见，覆盖混合行高、缩进、多行、单行及空组；未声称真实窗口交互或未运行测试通过。
- Task fingerprint: 89c97a4c22b8b770ad6e49022370dedbee68e4cc4bba37fb02528fb4c376a0ee

## Verification

- Passed: 终验：生产源码、离屏预览源码和 PNG 的 SHA256 与当前 assessment 完全一致；再次 Debug build 成功，Swift 解析和 diff 检查通过；已查看深浅色预览的对齐与分组边界。未运行测试，未启动或重启 App/Bridge，真实窗口交互需用户自行重新运行 App 后确认。
