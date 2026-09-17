# 规划 Agent 待回复问题识别与问号状态提示

Status: Completed (2026-09-17 14:53)
Kind: Plan

## Target
- [x] T1: 首版针对 Pi 提出的明确需要用户回应的问题或确认请求，在 iTermate 中以问号状态图标提示；识别优先避免误报，接受部分漏报。
- [x] T2: 明确待回复状态的出现、保留和清除条件，并形成可实施方案及误报、漏报和状态转换的验证计划。
- [x] T3: 用户重启 App 后，对本轮明确的“请确认…我会等待你的回复，确认后再继续”请求显示问号而非绿色完成；定位并解决实际运行链路未生效原因。
- [x] T4: Pi 待回复默认问号使用与现有状态图标一致的像素风格，保持默认问号可辨认、状态区域布局及现有待回复行为。
- [x] T5: Status Animation 设置中提供待回复状态的配置入口，与现有设置交互一致，配置可持久化并作用于会话图标，默认保留像素问号且不改变待回复识别和清除行为。
- [x] T6: 为待回复像素问号增加摇晃动画，保留字形、颜色配置及状态识别/清除行为；减少动态效果启用时保持静态。

## Decisions

- 用户在规划完成后明确要求开始实施；沿用已接受的 Pi 首版目标。不提交 Git 改动、不运行测试，不覆盖用户安装态或启动、重启 App 与 Bridge。
- 识别策略优先减少误报；接受漏掉部分不明确的待回复情况，不以扩大召回率为首要目标。
- 首版仅支持 Pi；Codex 待回复识别不在首版范围内。
- 用户已确认识别与清除设计：明确的确认、选择和输入 UI 使用 Pi 事件；普通文字使用最后助手回复的保守规则，在 agent_settled 后判定；custom UI 不一概视为提问。
- 新增 awaitingInput 状态并显示问号；用户最新已确认实际像素问号显示成功，并要求增加摇晃动画，取代默认问号必须静态的约束。聚焦会话不清除；下一轮开始恢复 running；会话退出释放 Agent 状态。明确 UI 关闭或取消后按当前生命周期恢复，不直接宣告成功。
- 待回复不计入成功完成次数，也不发送成功完成通知。不新增模型调用，不扫描终端画面，不修改 Agent 提示词。
- 使用像素问号图标和“等待回复”辅助说明；用户最新要求在 Status Animation 增加待回复状态配置入口，取代此前“不新增动画配置”的范围约束。不新增系统提醒或菜单栏计数，不传输、保存或记录问题原文。
- 用户截图已出现蓝色圆圈问号，要求改成与其他状态图标相似的像素风格；原生圆圈问号不再作为最终视觉方案。最新请求进一步增加 Status Animation 配置，不改变识别和状态流转。
- 第三轮只读审查因用户新增设置范围而由主会话主动停止，不作为通过证据；设置完成并自检后重新发起 fresh 审查。
- Status Animation 的 Agent 分区增加 Waiting for Reply，默认 Question Mark；可选择已有 Alien/Robot/Classic；最新摇晃请求针对像素问号，其他预设保持当前行为。颜色独立持久化，可恢复默认（跟随 App 强调色）。会话与设置共用 AgentWaitingStatusView，不改变其他状态样式选项。
- 沿用现有 iTerm2 Bridge 与 Ghostty 本机状态通道。源码实现不等于用户安装态升级；本轮不替换已安装集成，不启动或重启 App、Bridge。

## Scope

- 包含：Pi 明确交互提示和最终文字确认请求的保守识别，两条现有终端状态通道、Session 行提示、恢复与失效行为，以及通知和统计边界。
- 不包含：Codex 识别、任意自然语言问题的完整理解、任务完成语义推断、远端模型服务、问题正文展示、跨进程持久化问题历史。

## Plan

1. Pi 识别与生命周期
   - 修改 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/iTermate-integration.ts)。保持现有串行报告队列与有界 Socket 等待。
   - 保留当前运行状态、最终回复候选及明确 UI 等待标记；统一推导可见状态，避免各个 handler 各自直接覆盖状态。
   - ui_prompt_start 只接纳 confirm、select、input、editor；custom 不触发。仅在本地交互 TUI 使用此检测，不把 headless 子任务的输出映射为用户待答问题。ui_prompt_end 清除明确 UI 标记，再按仍在工作、最终文字待答或此前空闲状态恢复；不单凭关闭事件发布 finished。
   - agent_start 清除上一轮文字候选并进入运行；agent_end 提取本轮最后一条助手消息；agent_settled 再核实 ctx.isIdle()，排除自动重试、压缩重试、排队续跑以及其他扩展启动新轮次。错误、中止、缺少最终文字或工具调用型结束不产生文字待答提示。
   - 文字只取 text 内容，排除 thinking、工具结果、代码块和 Markdown 引用；检查末尾有效自然语言段落。首版为中英文明确请求的有限规则：要求用户确认、从选项中选择或补充必需信息，并存在明确等待／继续依赖表达。问号本身、可选帮助、示例和否定等待表达不命中；不能可靠排除歧义时不触发。不将启发式声称为零误报。
   - 验证点：用户提供的 Task Target 示例命中；引用该示例的解释性回复、普通问句、代码问号、可选继续建议不命中。
2. 状态通道与存活边界（依赖节点 1）
   - 扩展 ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/iTermateBridge.py)、["/Users/caishilin/Desktop/personal/iTermate/iTermate/TerminalStatusServer.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/TerminalStatusServer.swift) 与 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/ItermBridge.swift) 的状态校验、模型和快照映射，统一 wire 值 awaitingInput，仅 Agent 通道可报告，无 exitStatus。
   - 等待期间续报当前等待状态而非 running，复用现有心跳节奏和超时常量。队列发送前核对生命周期 generation，丢弃旧轮次或旧等待区间的排队续报；状态转换和后续心跳保持发送顺序。重复续报不重置 statusChangedAt，也不产生完成转换。
   - 两端为等待状态维护有限存活租约；Pi 崩溃、断线超时或唤醒后失去可靠证据时清除问号，不能依赖 Agent 进程名称确认待答。仍存活的 Pi 续报可在通道重建后恢复等待状态；接收端不得只接受已有 running 状态的心跳而拒绝等待恢复。
   - Ghostty 保持 TTY 唯一匹配、reporter 与 sequence 验证和 Terminal identity 变化清理；防止旧 reporter 的等待结束事件覆盖新轮次。iTerm2 保持真实 Session ID 路由，不根据标题或目录猜测。
   - session_shutdown 停止续报并 detached；/new、/resume、/reload 和分支切换清除旧候选。首版 Pi 重启后不从历史文字重建待回复；避免旧分支或已回答的问题复活。App/Bridge 重建则允许由仍活跃的 Pi 当前状态恢复。
   - 验证点：长时间等待不因无 running 心跳而丢失；新一轮运行不被旧等待续报覆盖；无新证据时问号不永久残留；对话框关闭、取消和超时均恢复正确状态。
3. Session 行与现有完成行为（依赖节点 2）
   - 修改 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/iTermateApp.swift) 的状态分支，使用与现有状态图标一致的像素问号及间歇摇晃，沿用状态区域尺寸与项目强调色，提供 help 和 accessibilityLabel。界面英文文案使用 Waiting for your reply，不显示消息原文。
   - awaitingInput 不映射为成功、失败或 idle；聚焦清除逻辑仅处理原有 finished。检查现有行显式身份能随新状态更新，并检查运行/完成耗时文案不将等待时长误称执行时长。
   - 检查 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/SessionNotifications.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/SessionNotifications.swift) 与 Store 完成统计：running → awaitingInput 不通知、不计成功；awaitingInput → running → finished 的最终成功仍按原有规则计一次。普通 Shell 与 Codex 状态行为保持原样。
4. 待回复状态设置（用户追加，依赖节点 3）
   - 复用 AppConfig/AppSettings 状态偏好、序列化和读盘后单字段更新路径，新增 agent_awaiting_input 与 question_mark 枚举值，不新建配置文件或历史迁移。
   - Agent 分区的 Waiting for Reply 行使用共享预览、状态限定样式列表、颜色选择与恢复默认；会话实际图标使用同一偏好。问号的 TimelineView 每四秒做四次 ±1pt 整点水平位移，然后居中停顿；减少动态效果时暂停时间轴且强制零位移。其他待回复预设保持静态，原七种动画不变。
   - 新增配置持久化/颜色重置/并发实例保留与静态可见性回归测试源码；仅静态语法检查，未执行测试。
5. 验证与交付（依赖节点 1–4）
   - 实现前按 Swift、Pi 集成和 macOS 构建相关 SOP 执行。类型检查、静态差异检查和不启动 App 的构建作为默认验证；未经用户在执行请求中明确授权，不运行单测、回归套件或以 mock 回放替代命名的测试。
   - 后续获准测试时覆盖：中英文正反例、无问号确认、引用/代码/可选建议、错误/中止、自动重试和续跑、明确 UI 关闭/取消/超时、旧队列续报、等待租约失效、通道重建、TTY 复用、分支/会话切换、聚焦不清除及通知/计数隔离。
   - 真实 UI 验证由用户自行重建并运行后进行，确认两个终端均显示问号、状态转换即时可见、聚焦不会消失、开始下一轮恢复运行动画。若未获运行观察机会，明确留下未验证项，不能以构建通过替代。
   - 实施涉及多语言状态机、异步生命周期与两条数据通道，应按实际结果评估 R2 并履行独立 task-review；当前已获实施授权，执行自检后进入独立审查；不执行测试或启动 App。

## Planning Evidence

- 当前 Pi 集成已经在 agent_end 读取最后助手消息，并在 agent_settled 报告 finished；两条通道当前只接受 idle/running/finished/detached。
- 本机 Pi 扩展文档已确认 ui_prompt_start/ui_prompt_end、提示种类、嵌套提示合并及 best-effort 不等待 handler 的语义；agent_settled 是自动续跑结束边界。实现时以目标 Pi 安装包的类型与运行代码再次核对；旧 Pi 缺少 UI 事件时不声称支持明确对话框检测，文字识别路径仍可独立工作。
- 当前 Ghostty registry 的租约和 heartbeat guard 仅适用于 running；iTerm2 协议也只允许 running heartbeat，必须同步扩展，不能只改 UI。
- 两端聚焦清除目前只处理 finished；Session 行身份包含 status。通知当前按 running → finished 判定，这为新增等待状态提供了明确隔离点。
- 当前 Lessons 文件为旧式标题结构，索引未提取有效触发条件；已回读原文。方案遵循：真实生命周期优先、用户安装态不覆盖、不主动重启、唤醒不信任陈旧运行状态、显式视图身份覆盖状态变化。实际运行和画面检查留待执行阶段授权。
- 规划阶段未运行测试、构建或真实运行验证；上述仅为调研证据。实施阶段的自检与证据另列。

## Runtime Follow-up

- 用户自行重启 App 后，明确测试提问仍显示绿色完成图标；已重新打开本任务，T3 未验证。
- 只读检查确认运行 App bundle 中 Pi 扩展和 Bridge 的 SHA256 与第二轮审查源码一致，用户已安装 Pi 扩展也与源码一致；对应助手消息确实为 text、stopReason=stop。
- 首次检查时当前 Pi 是否 /reload 尚无证据；重启 App 不会替换 Pi 内存中的 handler。提示用户重载并再次提问后，用户提供截图已出现问号，证明该次实际链路可以显示待回复；用户未明确确认重载操作，因此不把旧 handler 推测当作已证实根因。未修改识别代码来处理这次安装态反馈。
- 用户随后确认将圆圈问号改成像素风格。新增静态 SwiftUI Canvas 问号，5×7 字形，沿用状态矩阵的 2pt 间距、1.75pt 颗粒和 0.35pt 圆角，在 36×16pt 状态区域居中；颜色、帮助说明、无障碍标签及状态逻辑保持不变。
- 从实际新增 View 提取源码，用独立 SwiftUI ImageRenderer 离屏渲染 8 倍预览并读取图片检查：问号头部、弯折与底点可辨认，无遮挡；没有启动 iTermate 或 Bridge。预览为 ../artifacts/detect-agent-pending-questions/evidence/pixel-question-preview.png，不是运行中 App 截图。Debug build 再次成功，真实新图标仍需用户自行运行新版观察。

## Implementation Checks

- T6：问号 View 新增 TimelineView，10Hz 最短刷新，四秒周期中用 [0,-1,1,-1,1,0] 整点位移，其余时刻零位移。直接读取 accessibilityReduceMotion，暂停 schedule 并零位移；会话和设置共用该 View。未改字形、颜色或其他预设。Debug build 通过，当前 View 离屏单帧预览可辨且未裁剪；未实测连续动画或系统减少动态效果切换。
- 离屏预览最初尝试通过 environment 覆写减少动态效果，但该环境键只读，预览辅助程序编译失败；已删除辅助程序的覆写后成功渲染普通单帧，不把它当作减少动态效果的运行验证。未更改系统偏好或启动用户 App。

- 已实现 Pi 的有限中英文末尾请求识别、明确 UI 事件映射、TUI 模式过滤、串行状态报告和 generation 检查；等待态维持两秒续报，消息正文不离开扩展。
- 两端等待态接入八秒租约；同状态续报保留状态起始时间。Ghostty 沿用 reporter/sequence/TTY 匹配，iTerm2 增加不同状态旧心跳拒绝。聚焦清除仍只作用 finished。
- 已检查通知和统计调用方只接受 running → finished，因此 waiting 不计成功；SwiftUI 问号独立绘制，不进入原运行/完成动画或耗时分支；最新摇晃仅由问号 View 自有时间轴负责。
- Python ast.parse 静态语法检查通过；TypeScript strict/noEmit 检查通过（本机 TypeScript 5.3.2，ES2022 + ESNext lib，Bundler module resolution，对照本机 Pi 类型）。初次 ES2023 target 参数不被该编译器接受，已改用其支持的参数；类型检查发现的 Socket 推断与 text block 窄化问题已修复。
- xcodebuild Debug build 在独立临时 DerivedData 中成功；未启动产物。未执行测试、事件回放、真实界面检查或安装升级，不能据此宣称运行时场景已通过。
- 后续需用户自行运行新版 App 并按现有设置入口更新 Pi 集成、重载 Pi，人工观察待回复/续跑/退出及两个终端行为。
- 追加 Status Animation 设置后，Debug build 再次成功；修改后的 Swift 测试文件通过 swiftc -parse，未执行测试。静态检查配置默认值、读写 key、颜色重置和共享预览/会话渲染路径；新增设置页尚未在用户运行 App 中观察。
- 首轮独立审查后修正四项：session_tree 改用 agent_start/agent_end 维护的实际运行标记；加入中英文否定等待排除；报告区分明确 ACK 与失败并在当前 generation 内重发完整转换，接收端 ACK 表示实际接受而非仅解析成功；Bridge 自检改为先断言旧心跳拒绝，再发送合法新运行转换。
- 新增 integrations/pi/iTermate-integration.test.ts 固化确认门槛、否定等待、引用/代码/可选建议样例；仅做 TypeScript 静态类型检查，未执行这些测试或 Bridge 自检。修正后再次通过 TS strict/noEmit、Python AST、Debug build 和 git diff --check。

## Result

- T2: Plan 已明确出现、保留、清除和重连边界及正反例/生命周期验证清单；源码实现与计划对照完成。未运行测试或真实 UI，人工验收待用户自行运行新版。
- T1: 当前 product-2.diff 与新增 Pi 测试源码接入保守识别/问号/租约，修正首轮四项发现；静态逐路径检查、TS strict/noEmit、Python AST、Debug build 通过。未执行测试或真实 UI，证据见 Implementation Checks 与 evidence/review-snapshot-2.txt。
- T3: 运行 App bundle、已安装 Pi 扩展与源码哈希一致；再次提问后用户截图已显示问号，当前运行链路有效。首次绿色完成的旧 handler 原因仅为推测，未确认；未改识别源码或用户安装态。
- T4: 默认 Question Mark 继续使用已离屏检查的5×7像素View；设置与会话共用AgentWaitingStatusView，选其他预设也固定静态，状态区域/识别逻辑不变；当前Debug build成功，真实新UI待用户运行。
- T5: Agent分区新增Waiting for Reply，含Question Mark/Alien/Robot/Classic、独立颜色与默认重置；AppConfig自动按新增枚举key读写，AppSettings保持读盘合并更新；设置/会话共用渲染及颜色解析。Debug build和Swift测试源码语法通过，测试未执行，设置交互未实测。
- T6: 实际问号View中TimelineView每四秒短暂±1pt水平摇晃，会话/设置共用；reduceMotion暂停且零位移，字形和偏好不变。Debug build通过，普通离屏帧已目视确认无裁剪；未运行测试、未观察连续动画或系统reduce-motion切换。
- Review gate: Passed — fresh reviewer 8ffa41a4-dddb-433b-a776-c78799d4b4ed reports/review-5.md无新问题，TR1–4仍resolved；父会话复核九文件/HEAD/diff与snapshot5一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 保留既有Required，用户追加问号摇晃与减少动态效果行为需独立复核。
- Snapshot: product-5.diff sha256:e194fe9557592c76518f8faf2b50d5a0b55028e2f68fe836d97ae0d38e80205d; evidence/review-snapshot-5.txt
- Evidence: 第四轮后只改问号View；Debug build、离屏单帧、diff/Context校验通过，连续动画未实测。
- Task fingerprint: f6afc8f6a4c5660c92b494d22fa818f596c782f09a44653f11e63ac3bad1e427

## Verification

- Passed: 复审后内容身份一致，Swift parse、git diff --check、Context validate通过；同快照Debug build成功，实际View离屏单帧已检查。未运行测试/App或实测连续摇晃与Reduce Motion切换，交付限源码。
