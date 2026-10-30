# 调研 iTermate 后续必要功能与优先级

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-28 14:52) |
| Kind | Plan |

## Target

- [ ] T1: 基于现有能力与外部产品证据，识别值得补充的功能，区分必要性、优先级和可观察验收条件。

## Scope

仅研究当前 iTermate 的增量需求并提供后续决策依据；不修改产品、安装态、Context 或 Lessons，不启动 App、Bridge，不发布、不运行测试。候选功能不是用户已接受的实现需求；后续实现需单独授权和明确 Target。

## Decisions

- 继续以 iTerm2 伴随面板为定位，不把竞品的完整终端、Agent 编排或云端协作能力照搬进来。
- 优先级为产品判断，不是用户访谈或使用数据已证实的刚需。判断依据是核心使用闭环、当前源码缺口与官方外部功能证据。
- 首选方向：待处理事项入口与待回复提醒、快速搜索筛选、可解释的状态诊断。已有完成通知、全局跳转、Pi 归档、收藏项目、自动标题与统计不重复立项。
- 保持生命周期、身份、已读状态分离；缺少观察不等于 idle 或失败，浏览待处理项不自动解除等待。诊断默认不导出对话、凭据和原始工具输出。

## Plan

### 1. 当前能力与证据边界

本轮读取基线 HEAD 为 `83b28c3`；仅检查源码、文档和网页，没有运行真实产品验证。当前工作区另有推送任务记录，未修改该记录。

| 能力 | 已有依据 | 本轮识别的增量空间 |
| --- | --- | --- |
| 完成通知及点击跳转 | ["/Users/caishilin/Desktop/personal/iTermate/iTermate/SessionNotifications.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/SessionNotifications.swift) 的 SessionCompletionTracker、handle、sendNotification | 当前通知消费完成事件；未见等待事件通知、持久待处理列表与按事件类别控制 |
| 全局 Agent 跳转 | ["/Users/caishilin/Desktop/personal/iTermate/iTermate/FinishedSessionShortcut.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/FinishedSessionShortcut.swift) | 已存在，无需重建快捷键系统；待处理列表可复用激活链路 |
| 分组、收藏和 Archive | ["/Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift) 的 PanelContent、sessionList、archiveSection | 检查面板入口并搜索源码，未发现面向用户的搜索查询或状态筛选入口；这不是对所有潜在实现的形式证明 |
| 连接状态、日志、通知授权提示 | ["/Users/caishilin/Desktop/personal/iTermate/iTermate/SettingsViews.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/SettingsViews.swift) | 有基础诊断，缺少统一的逐会话身份绑定、状态新鲜度及修复指引展示 |
| Pi 归档与安全恢复 | ["/Users/caishilin/Desktop/personal/iTermate/docs/pi-session-archives.md"](file:///Users/caishilin/Desktop/personal/iTermate/docs/pi-session-archives.md) | 已有原生记录快照及恢复确认；不是整个项目备份，也不是跨 Agent 恢复 |
| Agent 接入 | ["/Users/caishilin/Desktop/personal/iTermate/iTermate/AgentIntegrations.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/AgentIntegrations.swift) 的 CodingAgent.isSupported | 当前仅 Pi/Codex；枚举中存在其他名称不代表已支持 |

Context 的快捷键描述、快捷键文档与当前设置文案存在优先级差异，本轮不据旧描述提出重复改动，也不在规划范围内修正文档。实现待处理入口前应以 Bridge 当前选择逻辑重新核实。Context 有未索引章节，Lessons 旧格式被脚本拆散，本轮已读原文；不据历史 Codex hooks 经验覆盖现有原生监控架构。

### 2. 候选需求与建议顺序

**P0：待处理列表与待回复提醒（高价值，范围中等）**

- 问题：用户离开 iTerm2 时面板隐藏，完成通知无法覆盖“Agent 正等待操作”；桌面横幅消失后也缺少专门的待处理入口。
- 最小方案：菜单栏增加等待回复、失败、未读完成列表；等待/失败/成功分别控制提醒，按同一会话的事件身份去重；当前正在查看的会话抑制桌面打扰。保留现有面板，不另做大型任务管理器。
- 验收建议：切到其他 App 后，明确等待事件按设置提醒一次；重连与心跳不重复提醒；点击只激活原会话；查看不清除等待；下一轮事件不继承旧已读标记；关闭的会话不能错误跳转到复用身份；系统通知禁用时应用内仍可见。
- 依赖：Pi/Codex 可提供的等待证据不必完全对称；无可靠事件身份时先明确受支持范围，不根据标题猜测。若持久保存只保存必要元数据及有界保留期，不存完整回复。

**P0：逐会话状态诊断（高价值，范围中等）**

- 问题：连接成功不表示每个 Agent 都已绑定；没有状态、旧集成未重载、本地模型不可用可能在用户眼里都表现为“不正常”。
- 最小方案：复用设置与行上下文入口，展示 Bridge 连接、Agent 身份是否绑定、最近观察是否新鲜、Pi 运行实例能力、Codex 原生标题/共享 daemon 条件、本地模型可用性；每项给明确下一步，不自动改用户配置。
- 验收建议：区分未安装、已安装未加载、未绑定、失联、正常空闲；无法检测时显示无法确认而非通过；模型故障不伪造生命周期故障；复制诊断不含凭据或对话；刷新不终止终端或任务。
- 约束：仅对独立更新的 Pi 集成检查能力，不新增 App 与其自管 Bridge 的冗余协议版本系统。

**P1：快速搜索与状态筛选（高价值，范围小至中）**

- 问题：多项目、多会话下，分组和逐个循环不能代替按目标定位。
- 最小方案：搜索标题、项目完整路径与 Agent 类型；筛选待回复、运行、完成/失败；活动会话与归档结果明确区分；支持键盘选择、Enter 激活、Esc 返回。
- 验收建议：同名不同路径可区分；筛选不改变底层状态或现有导航候选；列表刷新保持稳定身份；空结果可清除条件；归档搜索命中不自动恢复；输入框能在非激活面板模型下实际获得输入焦点且退出后恢复终端操作。
- 初期只做本地元数据搜索，不建立全文对话索引，不依赖模型。

**P1：Codex 会话续接入口（条件性需求，范围中至大）**

- 问题：当前 Pi 有明确归档恢复，Codex 主要覆盖活跃观察；长期任务需要跨终端重开时缺少对称入口。
- 最小方案候选：优先研究按已验证原生 thread ID 在新终端续接，而非复制 Pi 的快照格式或宣传跨 Agent 归档。
- 验收建议：恢复精确 thread，核对工作目录；目录缺失、记录不可用或已有活跃实例时明确处理；新窗口出现不算续接成功，需重新观察原生身份；不自动重放危险命令、不覆盖原始历史。
- 前置研究：本轮未验证当前 Codex CLI 恢复参数、并发续接语义与共享 daemon 行为，因此不是可直接执行的实现规格。明确契约后再立项。

**P2：Git 分支/worktree 上下文（条件性需求，范围中等）**

- 问题：同一项目多分支并行时，目录末级名和自动标题可能不足以辨认环境。
- 最小方案：按需在悬停详情或项目层显示仓库与分支/worktree，支持复制路径；不把每行塞满元数据，不加入 worktree 自动创建/删除。
- 验收建议：同名仓库和 detached HEAD 不混淆；非 Git 目录正常；Git 查询异步、有超时和缓存失效；不扫描整个磁盘、不阻塞状态采集。
- 只有实际多 worktree 使用频繁时提升优先级。

**P2：更多 Agent 接入（条件性需求，范围大）**

- 当前用户是否使用 Claude Code、OpenCode 等尚无证据，不据竞品数量决定必须接入。
- 先选一个实际使用的 Agent，再验证官方生命周期接口；验收需覆盖运行、等待、失败、退出、重连与准确终端身份，不能只增加菜单名称或进程图标。

### 3. 外部证据与不照搬的边界

- [cmux 官方通知文档](https://cmux.com/docs/notifications)：提供通知面板、未读标记、跳转和前台抑制；Agent 通知区分 turn-complete、needs-permission、idle-reminder。支持“注意力管理”方向，但不能据此认定 iTermate 的自然语言 question 等同权限请求。
- [Agent Deck 官方仓库](https://github.com/asheshgoplani/agent-deck)：README 列出多会话状态、搜索/全局搜索、分组、归档、fork 和 Git worktrees。只采纳与现有伴随面板契合的搜索和上下文展示，不引入完整编排系统。网页提取 README 截断于 8K，引用限于已读片段。
- [iTerm2 官方 Session Restoration](https://iterm2.com/documentation-restoration.html)：崩溃/升级后的进程恢复与 OS 窗口恢复有关，重启机器不会恢复运行中的进程；因此不建议 iTermate 重造终端进程恢复，不承诺“重启后任务继续运行”。Agent 原生会话续接与之是不同能力。

暂缓：云同步、手机远控、自动回答权限请求、内嵌终端/浏览器、全量成本看板、更多装饰动画。没有直接用户需求证据，且易扩大权限、隐私和维护边界。

### 4. 后续实施与验证边界

建议先选择待处理入口或诊断其中一个作为独立实现结果，再做搜索；不因本记录列出多项就自动创建执行 Queue。各项均有可观察的验收建议，但不是已通过验收的产品能力。

本轮本地只读检查和网络取证能力可用；未运行单元测试、构建或启动产品。后续通知需实际 macOS 投递证据；搜索需验证非激活面板键盘输入；恢复需真实原生身份确认。真实 App 运行由用户控制，不擅自重启。研究没有用户访谈、使用频率或转化数据，因此优先级仍需实际使用反馈验证。

Context 不更新：本轮是规划，只将新发现及来源冲突保存在本记录；不把候选需求写成已确认项目事实。
