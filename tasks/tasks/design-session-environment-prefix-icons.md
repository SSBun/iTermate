# 设计 Pi、Codex 与 Shell 会话前缀图标

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-16 17:43) |
| Artifacts | [Artifacts](../artifacts/design-session-environment-prefix-icons/) |
| Kind | Task |

## Target
- [x] T1: 形成截图所指条目前缀圆点位置的图标设计，让 Pi、Codex 和普通 iTerm Shell 三种环境可直接区分。
- [x] T2: 将已预览的三类图标接入真实会话列表，以实际环境信息区分 Pi、Codex 与普通 Shell；Pi 保持缩小后的居中尺寸，像素 Canvas 动画支持减少动态效果，保留焦点提示和右侧生命周期状态。

## Scope

视觉预览已完成；用户现要求将该设计实现到 App 会话列表，允许为真实环境识别调整必要的数据链路。不得根据会话标题猜测环境，不自动安装、覆盖用户集成副本或重启 App、Bridge、Agent。当前实施请求未另行要求测试，不运行单元测试或项目测试，采用构建及非测试检查验证。

## Plan

1. 对照截图和现有前缀、焦点及右侧状态语义，确定三类图标的像素造型。
2. 输出像素 Canvas 动画预览和实际渲染效果，展示原始尺寸、选中状态及列表应用效果：[Canvas 预览](../artifacts/design-session-environment-prefix-icons/specs/environment-prefix-icons.html)、[PNG 效果图](../artifacts/design-session-environment-prefix-icons/specs/environment-prefix-icons.png)、[GIF 动画](../artifacts/design-session-environment-prefix-icons/specs/environment-prefix-icons.gif)。
3. 视觉预览已交付；对齐实际接入目标后，补齐真实环境身份展示并保留既有交互与生命周期状态。
4. 检查渲染及必要链路，完成授权范围内的构建和静态验证；按实际变更风险完成审查并披露现场验收边界。

## Decisions

- 左侧表达会话环境，右侧保留运行、等待、完成等状态；不把身份动画当成工作状态。
- 预览沿用截图的深色原生面板视觉；三类使用不同形状，颜色仅作辅助。
- 依据项目既有约定采用像素 Canvas 和轻量动画，并提供减少动态效果时的静态显示。
- 设计阶段快照只有通用 Agent/command 分类；用户确认接入后，新增明确的 agentKind 身份信号，贯穿 Pi/Codex 上报、Bridge、Ghostty Registry 与 Pi 恢复路径。身份与运行租约独立，聚焦和租约过期不改环境；退出或终端复用清理身份。旧版通用 Agent 使用中性圆环，不猜作 Pi、Codex 或 Shell。
- 本稿使用固定14pt槽位：Pi 为紫色 π，按用户反馈缩至6×5网格、12×10pt并居中；Codex和Shell保持7×7网格与14pt槽位不变。形状承担主要识别，选中保留蓝色行背景。

## Task Summary

**图标视觉预览**： ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/design-session-environment-prefix-icons/specs"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/design-session-environment-prefix-icons/specs) 制作像素 Canvas、PNG 与 GIF 视觉稿，按反馈缩小 Pi，保持统一槽位及其余两类造型。

**原生面板与状态模型**： ["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 接入会话环境像素图标、轻动画、减少动态效果及可访问描述；在快照、Ghostty Registry 与 Pi 恢复中传递独立身份，不改右侧生命周期状态或会话操作。

**iTerm2 Bridge**： ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge) 校验明确身份并发布到快照，保留租约失效后的身份，随 Agent 释放清理；补充身份回归用例。

**Agent 集成**： ["/Users/caishilin/Desktop/personal/iTermate/integrations"](file:///Users/caishilin/Desktop/personal/iTermate/integrations) Pi 与 Codex reporter 在既有路由中明确上报各自身份，不修改安装副本或启动命令。

**原生回归用例**： ["/Users/caishilin/Desktop/personal/iTermate/iTermateTests"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests) 补充身份解码、来源限制、聚焦、租约、乱序、退出和终端复用断言；本轮仅编译，未执行。

**使用文档**： ["/Users/caishilin/Desktop/personal/iTermate/README.zh-CN.md"](file:///Users/caishilin/Desktop/personal/iTermate/README.zh-CN.md) 说明三类图标、未知来源回退及用户自行更新、重载集成的生效条件。

## Verification Notes

- 在独立无界面 Chrome 配置中实际渲染 Canvas，不使用 AI 图片生成或现有用户浏览器窗口。
- 实际 PNG 为2040×1640；GIF 为1020×820、4帧、每帧800毫秒。每个图标的颜色帧均存在实际差异，Pi 为4种、Codex/Shell各2种。
- 强制减少动态效果后，在两个不同时间点实际渲染，像素逐一比较完全相同，证明动画停用。
- 已检查更新后的整体效果图：Pi 缩至12pt宽，中心仍落在14pt槽位；Codex和Shell的放大图标与修改前逐像素相同，配色不变，未发现遮挡；JS 的 node --check 通过。
- 原始图标用像素 Canvas 绘制；PNG/GIF 均来自实际浏览器 Canvas 输出，GIF仅做尺寸转换与编码。
- 未运行单元测试或项目测试；本次交付仅是视觉稿，不是 App 现场截图，也不代表运行时身份识别已实现。验证与内容身份见 evidence/render-validation.json。

## Implementation Verification Notes

- 用户已确认当前完整实施 Target；本轮不运行单元测试或项目测试。新增用例仅通过 build-for-testing 编译，不能据此称测试通过。
- App 使用独立 DerivedData 构建，不启动 iTermate；原生图标通过提取真实视图源码的独立 SwiftUI ImageRenderer 辅助程序渲染，不是运行中的面板截图。
- 原生 Pi 图形为12×10pt并居中于14pt槽位；Codex/Shell保持7×7网格。减少动态效果以源码暂停 TimelineView 和固定透明度路径验证，未切换用户系统设置。
- 旧版 Pi 未提供身份时暂显示中性图标，需要更新集成并 reload；现有 Codex 包装器进程不会自动加载新 reporter。尚未验证真实新 App、Ghostty映射或模型轮次现场。
- 实施独立基线、差异、构建及编译日志、语法与类型检查、原生渲染和内容身份保存在 evidence/implementation-baseline 与 evidence/implementation-01；不将其他未提交改动归入本任务。

## Result

- T1: 按用户反馈将Pi图形宽从14pt缩为12pt、保持14pt槽位居中，重新实际渲染HTML/PNG/GIF并展示；Codex/Shell放大图标与修改前逐像素一致，动画及减少动态效果验证通过。仅调整预览，未改App或运行项目测试。
- T2: 已接入真实agentKind上报、Bridge快照、Ghostty Registry和Pi恢复；原生图标与确认稿三类网格一致，Pi12×10pt居中。最新App及回归用例编译成功，Python语法/TS严格类型检查、bundle资源比较通过；右侧状态及操作差异自查未变。observations.json记录边界：未执行测试，未启动新App或改变安装态；现场仍需用户验收。
- Review gate: Passed — 第01轮全新只读Reviewer（733bb3de）无实质发现，报告已保存并索引；主会话复算manifest全部42项内容及identity一致，消除条件性快照阻塞。现场及未执行测试边界不变。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 身份跨Pi/Codex上报、Bridge、恢复与Ghostty Registry，涉及租约及退出清理，不能按纯视觉改动豁免。
- Snapshot: sha256:c966a6ed28b94d85fce07ce2156874bcb4d967cd828de1012b70bf7f74990aa6
- Evidence: implementation-01/observations.json及task.diff：原生网格/尺寸、App与回归用例编译、TS类型、Python语法和bundle字节核对；未执行测试及现场App验收。
- Task fingerprint: 725029cc966201de058511aaa4d579fef17d85a8ba88c5f99809d206d6c4bc92

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第01轮](../artifacts/design-session-environment-prefix-icons/reviews/round-01.md) | sha256:c966a6ed28b94d85fce07ce2156874bcb4d967cd828de1012b70bf7f74990aa6 | no blocking findings；主会话随后复核42项内容hash一致，现场及测试执行边界保留。 |

## Verification

- Passed: 审查后再次复算42项清单hash和identity均一致，报告引用/快照匹配，Python语法、git diff --check及Context校验通过；既有最新App/测试bundle编译、TS类型与原生渲染证据未漂移。未执行测试或App现场验收，未安装或重启。
