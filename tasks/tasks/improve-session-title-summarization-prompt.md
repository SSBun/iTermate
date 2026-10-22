# 改进会话标题提示词以生成简短目标摘要

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 18:01) |
| Artifacts | [Artifacts](../artifacts/improve-session-title-summarization-prompt/) |
| Kind | Task |

## Target
- [x] T1: 会话标题生成提示词引导模型从上下文提炼当前主要目标并生成简短标题，不照抄任务目标段落、Markdown格式或冗长进度汇报。
- [x] T2: 修改限定在标题生成及必要配套内容，不改变回复类型分类、会话状态或发布安装态；验证结果与未覆盖范围如实记录。

## Scope

- 同步改进Pi集成与原生Codex现有的两份标题生成system prompt；只用提示词引导概括，不加入截断、清洗或长度拒绝逻辑。
- 不修改回复分类、会话状态、模型选择、请求参数、失败回退、归档摘要或安装态，不启动或重启App/Bridge/Pi/Ollama。
- 本轮未获运行单元测试或项目测试套件授权；使用类型/语法检查、Debug构建和本地合成输入的手工模型观察。

## Plan

1. 核实截图选中会话对应的标题生成路径，检查Pi和Codex提示词及显示校验边界。
2. 用固定合成上下文观察旧提示词，加入上下文到短标题的示例并强调目标提炼，而非原句摘录。
3. 同步两处提示词及必要回归断言源码，验证原始模型输出、生产差异、类型和构建，记录限制。

## Decisions

- 用户确认本轮完整目标后执行；截图选中的三角形图标由SessionEnvironmentIcon映射为Pi。Pi与原生Codex均各有一份相同旧标题提示词，故同步改进两处现有文字，不新增跨语言资源或抽象。
- 只读检查已安装Pi集成，确认磁盘安装副本仍包含旧标题提示词；未覆盖安装副本，不能据此证明截图进程内的加载版本或完整输入。
- 固定8条合成上下文复现了类似长标题：旧提示词曾把历史编号任务、校验完成、保留证据、父子关联等拼接输出，或把旧目标与新目标同时输出；不是取得截图原会话的完整输入进行回放。
- 早期修订仍出现空格、平台泛称和目标拼接，相关两次生产提示词观察保留在after-initial.json、after-expanded.json。另做了两版临时候选的手工本地观察，最终选择分行的对话/标题对照示例，随后用最终生产文字重新观察。
- 最终8条原始输出分别为优化会话切换、修复会话覆盖刷新、修复历史任务重复编号、排查侧栏选中丢失、排查登录白屏、添加标题日志、修复搜索结果排序、修复报表中文乱码，均为6至10个汉字，未做清洗或截断。
- 本地诊断固定使用已安装的qwen3.5:2b及受支持digest；不读取真实会话，不改变应用选择，不使用云端或其他模型作为后备。4B库存不存在，未进行真实4B验证。部分场景也用于提示词示例，8条观察不是独立留出集或总体准确率保证。
- TypeScript严格noEmit检查、Swift解析、最终Debug构建及限定diff空白检查通过；补充5条标题提示词断言源码，但没有运行单元测试或测试套件。最终构建3.082秒成功；没有主动启动产物或真实UI验收。

## Task Summary

**Pi集成**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 将标题提示词改为提炼最近用户的单一核心目标，排除原句摘录、Markdown、进度拼接和过时目标，加入5组分行的上下文与短标题对照示例；补充相关提示词断言源码，保留原有原始输出接收与生命周期逻辑。

**原生Codex标题生成**：在 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/) 仅同步LocalLLMService中的同一标题提示词，保留模型、网络参数、非空校验和失败回退。

## Evidence

- [手工本地观察脚本](../artifacts/improve-session-title-summarization-prompt/evidence/probe.py)：从两份源码提取并解码system prompt，检查一致后以相同64 token、温度0、seed42和10分钟驻留参数请求固定回环2B。
- [修改前观察](../artifacts/improve-session-title-summarization-prompt/evidence/before.json)、[早期修订](../artifacts/improve-session-title-summarization-prompt/evidence/after-initial.json)、[扩展修订](../artifacts/improve-session-title-summarization-prompt/evidence/after-expanded.json)、[最终观察](../artifacts/improve-session-title-summarization-prompt/evidence/after.json)。包含合成输入、当时提示词、原始输出、时长、模型digest和两处源码哈希。
- [最终构建日志](../artifacts/improve-session-title-summarization-prompt/evidence/build-final.log)：xcodebuild的Debug build成功，未运行测试或启动App。
- [本轮精确差异](../artifacts/improve-session-title-summarization-prompt/evidence/changes.patch)、[内容快照](../artifacts/improve-session-title-summarization-prompt/evidence/snapshot.json)：以本轮开始时的源码快照隔离已有未提交改动；生产TS/Swift对照确认除标题提示词文字外没有差异。
- 验证命令：`tsc --project tasks/artifacts/local-llm-only-question-and-title/evidence/tsconfig.json`；`swiftc -parse iTermate/LocalModelService.swift`；`xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/itermate-title-prompt-build build`；限定源码/测试/Context的`git diff --check`；Context标准验证。
- 限制：当前运行App和已安装Pi集成未更新，现有标题不会因源码改动自动变短；用户需自行运行本轮构建并通过正常入口更新/重新加载集成及刷新标题，才可进行实际UI验收。

## Result

- T1: Pi和原生Codex的system prompt已同步为重新概括最近用户单一目标，含5组分行对照示例，排除原句、Markdown、状态及多事项拼接；最终生产提示词以固定本地2B观察8条合成上下文，原始输出均6至10个汉字。最终after.json绑定两份源码哈希；是小样本观察，不承诺总体准确率。
- T2: 相对开始快照精确替换检查：两份生产源码仅标题提示词文字改变；无截断/清洗/长度拒绝，回复分类、状态、网络、模型和回退保持不变。5条回归断言仅更新源码未执行；TS严格检查、Swift解析、最终Debug build、Context验证和限定diff检查通过。未覆盖安装态或主动启动App；4B和真实UI未验收。
- Review gate: Skipped — 当前R1的清晰结果、限定影响、低后果和充分授权检查均有证据；生产只改提示词，无显式或既有独立评审要求。不将自查或手工观察表述为独立评审或单元测试。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 两处同义标题提示词文字修正，生产流程未变，属于已验证的低风险显示文本生成调整。
- Snapshot: sha256:1cfaff5f9d4c9271d70f5c558c124abfb9a31553a621b981853b4ae850830aa4; tasks/artifacts/improve-session-title-summarization-prompt/evidence/snapshot.json
- Evidence: 开始快照对照证明两份生产源码除提示词外无差异；8条实际本地2B合成输出均6至10字且匹配最终源码；TS noEmit、Swift parse、Debug build及diff/Context检查通过，测试未运行。
- Result clarity: 用户已确认：用提示词提炼上下文生成简短目标标题，不摘录任务目标、Markdown或进度；边界与实际修改一致。
- Bounded impact: Pi summarizeTask与Swift LocalLLMService仅替换system文字；显示/手动刷新既有原始输出边界不动，无多个行为改造。
- Low risk: 结果仅影响可刷新会话显示名，不改权限、状态、归档或数据操作；失败仍保留旧标题，未安装或重启。
- Sufficient verification: 同组8条前后合成模型观察包含结构化目标、完成报告、新旧目标、确认回复、英文和格式注入；最终无前缀且6至10字。两份提示词解码一致，类型/语法/构建成功。4B与真实UI未验证且明确披露。
- Task fingerprint: d582d289594bfd54fdf8fd148f56561389c19f52a2c7d7875be046c806470182

## Verification

- Passed: 最终逐文件重算snapshot全部源码/测试源码/证据哈希无漂移；两份提示词一致，8条本地2B原始标题均6至10字，绑定最终源码。TS类型检查、Swift解析和Debug build已成功；测试未运行，4B/真实UI/安装态未覆盖。
