# 生成四款 App 图标候选

Status (2026-07-28 23:57): Completed

## Scope

- 包含：新增可重复运行的脚本，将透明 PNG 转换为完整的 macOS `AppIcon.appiconset`，并生成当前图标资源。
- 不包含：改变主体设计或修改 Xcode 构建设置。

## Target

- [x] T1：交付四个视觉上不同的方形 PNG 图标候选，均采用终端窗口与浮动伙伴模块的核心构图。
- [x] T2：每个候选至少为 1024×1024，主体和阴影保留 macOS 裁切安全边距，且不含文字或第三方品牌标志。
- [x] T3：四个候选采用用户提供参考图的明亮半透明玻璃质感、圆润立体造型、银色高光边缘和柔和水蓝背景，但不复制其中的海马与书签元素。
- [x] T4：交付四个重新设计的提示词概念；每个概念都有鲜明的 iTermComrade 语义主体、参考图视觉语言和明确的禁用元素，并在用户确认前不生成图片。
- [x] T5：交付一张基于已确认“终端小伙伴”提示词的方形 PNG 首稿，参考图仅用于视觉风格，输出至少 1024×1024，并通过主体、禁用元素和小尺寸辨识度检查。
- [x] T6：交付一张深色主题编辑稿；保持首稿的机器人、磁性双臂、镜头、金色核心、层叠面板、构图和比例，仅将背景、玻璃材质与光线改为深海蓝黑主题。
- [x] T7：交付一张纯白背景 PNG 和一张透明背景 PNG；两者保持暗色主体，透明稿四角完全透明且主体边缘无明显白边或缺损。
- [x] T8：脚本使用 macOS 原生工具从至少 1024×1024 的方形 PNG 生成 16–512pt、1x/2x 的完整 macOS AppIcon 图集及 `Contents.json`，默认处理当前透明图标，并拒绝无效输入或非 `.appiconset` 输出路径。
- [x] T9：生成的 `iTermate/Assets.xcassets/AppIcon.appiconset` 包含全部十个正确像素尺寸的 PNG，并通过 Apple `actool` 编译验证。

## Plan

1. 使用 `sips` 编写最小的 macOS AppIcon 生成脚本，并写入标准资源清单。
2. 用当前透明 PNG 运行脚本生成 `AppIcon.appiconset`。
3. 检查十个输出尺寸，并用 `actool` 验证资源目录。

## Result

- T1：通过 Pi `codex_generate_image` 的 gpt-image-2 路径分别生成四个候选；接触表目视检查确认其浮动伙伴分别为竖向侧栏、圆形模块、晶体方块和圆角胶囊，文件 SHA-256 均不同。
- T2：`identify` 与 `sips` 确认四个 PNG 均为 1254×1254 sRGB；全尺寸与 32×32 缩略接触表目视检查确认主体位于安全区，未出现文字、Logo 或第三方品牌造型。
- T3：四次生成均将用户提供的 `seahorseIcon.png` 标注为纯风格参考；接触表目视检查确认输出具有水蓝半透明玻璃、银色高光边缘、圆润 3D 造型、层叠彩色面板和柔和焦散，且未复制海马、书签或书页。
- T4：当前回复交付“玻璃桥梁”“磁吸搭档”“伙伴轨道”“终端小伙伴”四个独立提示词；每个都明确产品隐喻、继承的材质语言与禁止复制的参考元素，本轮未调用任何图像生成工具。
- T5：通过 Pi `codex_generate_image` 的 gpt-image-2 路径生成 `artwork/app-icon-variants/terminal-sidekick-draft-1.png`；`identify` 与 `sips` 确认为 1254×1254 sRGB PNG。全尺寸检查确认机器人抱住层叠终端面板、参考图仅转移玻璃与焦散风格，未出现文字、品牌、动物、书签或界面细节；32×32 缩略检查仍可辨认面板、伙伴镜头与金色核心。
- T6：以 T5 首稿为编辑目标，通过 Pi `codex_generate_image` 的 gpt-image-2 路径生成 `artwork/app-icon-variants/terminal-sidekick-dark-draft-1.png`；`identify` 与 `sips` 确认为 1254×1254 sRGB PNG。全尺寸对比确认机器人、双臂、镜头、金色核心、层叠面板和整体构图保持一致，背景与玻璃改为深海蓝黑、靛蓝和暗紫；32×32 缩略检查仍可辨认主体及暖色核心。
- T7：通过 Pi `codex_generate_image` 将暗色稿编辑为 `terminal-sidekick-dark-white-bg.png`，全画布边缘采样为 99.2%–100% 白且主体四周留白；使用本机已有 ImageMagick 3% 容差边界连通洪泛移除背景，生成 `terminal-sidekick-dark-transparent.png`。`identify` 确认两者均为 1254×1254 PNG，透明稿为 sRGBA，四角 alpha 均为 0，非透明边界为 `1099x813+95+206`；分别合成到深灰与浅灰背景目视检查，未见明显白边或主体缺损。
- T8：新增可执行脚本 `scripts/generate-app-icon.sh`，默认将当前 1254×1254 透明稿转换到 `iTermate/Assets.xcassets/AppIcon.appiconset`，也接受自定义输入与输出参数；`bash -n` 通过，缺失输入、非 `.appiconset` 输出路径和非方形小图均被拒绝。当前代码风格 SOP 没有 Shell 参考，因此采用仓库局部最小风格和 Bash 3.2 兼容语法。
- T9：脚本生成 16、32、64、128、256、512、1024px 对应的十个 sRGBA PNG 与标准 `Contents.json`；逐文件尺寸检查通过。`xcrun actool` 以 macOS 13 目标成功编译出 `AppIcon.icns` 与 `Assets.car`，无警告。
- Review gate: Skipped — 用户未要求独立审查；本地确定性图片转换不涉及关键风险，也不同时满足两类复杂性与验证缺口，脚本语法、失败输入、全部输出尺寸与 Apple 资源编译均已直接验证。
