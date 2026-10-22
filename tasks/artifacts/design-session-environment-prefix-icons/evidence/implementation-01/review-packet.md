# 会话环境图标接入：审查资料

## 原始请求与有效修订

- 用户提供面板截图并说："As you can see, I want to design multiple icons for case prefix dot view. So we can distinguish if it a Pi, Codex or normal iTerm shell environment"。
- 用户先要求："yes, and you should first give me the final rendering result about this icons"。
- 用户反馈："seems the pi icon is a little big"；预览将 Pi 缩至12×10pt，保持14pt槽位，另两类保持原图形。
- 用户请求："begain to implement this feature"。
- 主会话展示完整实施 Target：将预览中的 Pi、Codex、Shell 图标接入真实会话列表，替换左侧圆点；真实环境信息，不靠标题猜测；Pi缩小尺寸，像素Canvas动画与减少动态效果；保留选中提示、右侧状态及交互；不自动重启、安装或覆盖用户副本；本轮仅构建和静态检查、不运行测试。用户随后回复："yes"。

## 委派范围

所属任务：design-session-environment-prefix-icons，当前T1为已交付视觉稿，T2为真实接入。只执行一次独立、只读的 task-review，返回遗漏与风险，不修复、不批准、不修改任务状态、不进一步委派。

先核对原始要求、确认稿和实际产品差异，再阅读作者详细验证资料。产品范围为 task.diff 中9个文件，其他工作区已有变更不属于本任务；相关未改调用方可按需读取。确认稿位于同任务 specs/environment-prefix-icons.html、PNG/GIF；用户截图是会话行最左侧圆点，不是右侧工作状态。

## 约束与验收边界

- 所有新标记必须使用像素Canvas及动画；减少动态效果时静止。保留焦点背景与会话操作及右侧生命周期语义。
- 不允许猜标题来识别环境；旧通用Agent没有明确身份时可显示中性圆环，不把未知说成已识别。
- 仅源码和构建产物；不得启动/重启 App、Bridge、Codex或覆盖用户安装副本。
- 本轮没有测试执行授权。新增Swift用例仅编译，Python用例仅语法检查。不得称测试通过，也不要要求执行未授权的测试来替代审查。
- 本次交付不是现场验收：没有用户新App中的列表/焦点/减少动态效果截图，没有新Pi/Codex真实轮次和Ghostty现场映射；不能声称这些已经验证。
- 独立ImageRenderer仅绘制提取自真实源码的图标，不是完整App启动。首次辅助程序尝试写入只读的accessibilityReduceMotion环境失败，改为正常系统环境渲染；未改系统设置。减少动态效果仅检查暂停时间线与常量透明度源码。
- 不审计整个项目，也不重复此前独立Codex包装器任务的审查。

## 内容身份

同目录 manifest.json 的 identity 绑定产品、相关只读依赖、确认稿与证据；task.diff 使用任务独立基线，不以整个git diff替代。基线位于相邻 implementation-baseline 目录。由于当前审查工具不提供shell，若无法独立复算hash，请明确该条件性限制，主会话会在接收及完成前复算全部范围。

初次接入审查：当前没有TR条目，新的阻塞发现从TR-1开始。

## 作者证据（在检查要求和实现后读取）

同目录 observations.json 含逐项观察及限制：

- T1：原先实际Canvas预览与尺寸缩小证据在上层 render-validation.json；此次原生图标三类网格与该HTML逐项比对相同。
- T2视觉：pi-native.png、codex-native.png、shell-native.png、unknown-native.png 与 native-icons.png；14pt槽位按8倍渲染成112×112px，Pi alpha范围约12×10pt，位置居中。render-native-icons.swift为提取后的可复现辅助程序。
- T2源码链路：task.diff 展示身份字段的生产、校验、保存、快照、Pi恢复、Ghostty合并及行重建；焦点和右侧状态按差异与调用方静态核对。
- build.log：初步App构建成功。compile-tests.log：最新App与测试bundle的build-for-testing成功，不是执行测试。
- typecheck.log：tsc --noEmit严格检查成功，既有代码需要ES2023的findLast类型库。
- Python三个修改文件通过ast.parse；bundle中Bridge、Pi集成及reporter字节与当前源码相同，记录在observations.json。
- Context验证及git diff --check通过。现有App/Bridge PID和启动时间未变，没有安装态写入。

## 返回格式

中文反馈，包含实际审查模式、范围与快照、Findings、Unverified risks（注明影响T1/T2及是否阻塞）、实际检查、仅阅读的作者证据及覆盖限制。每个实质发现包含稳定TR-ID、严重性、位置、问题、证据、影响及建议下一步。没有实质问题则 Findings: none。只读输出，不给完成批准。
