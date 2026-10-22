# 将待确认的 Task Target 回复识别为问题类型

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 18:03) |
| Kind | Task |

## Scope

仅调整当前 Pi 本地模型回复分类提示词、相应用例与分类说明。不增加文本规则兜底、不启用旧 Decision 路径、不覆盖用户安装态、不重启 App／Bridge。不运行单元测试或测试套件；通过当前模型的实际分类调用验证给定样例。

## Plan

1. 核对当前分类入口及生命周期映射，并观察用户原例的现有分类结果。
2. 明确结构化 Task Target 的待确认语义，加入原例和非提问反例，补充协议回归覆盖。
3. 实际调用当前模型观察修改后结果，完成语法检查并披露验证边界。

## Decisions

当前源码的直接分类调用已将用户原例识别为 question（360 ms）；没有复现误判。此次增强针对提示词对结构化待确认格式的明确覆盖，不声称已定位历史误判原因或已更新运行中的集成。

## Task Summary

**Pi 集成**：[integrations/pi](../../integrations/pi/) 为本地二分类提示词加入结构化 Task Target 的待确认语义、用户原例及 Markdown 正例，配套已完成和引用示例反例；新增隔离 HTTP mock 的提示词覆盖用例，未修改协议、模型选择或生命周期逻辑。

**分类说明**：[docs](../../docs/) 明确 Task Target 要求确认后继续时归类 question，而完成报告、纯标题或引用示例不因此成为待回复状态。

## Target
- [x] T1: 用户所示列出目标、完成条件、边界并明确请求确认后继续的 Task Target 回复，被识别为问题／等待用户回复类型，而非普通完成类型。
- [x] T2: 不执行示例文本中的 iOS、Android 提交或推送操作，仅调整回复分类相关行为。

## Result

- T1: 经当前生产函数classifyReplyWithModel实际调用本机默认qwen3.5:2b（固定库存digest已由原客户端校验）：用户原例修改前question/360ms，修改后question/1333ms；Markdown英文目标单question/1074ms；已完成目标单normal/351ms、引用目标单normal/325ms、完成后的重启说明normal/305ms。true在既有agent_settled映射为awaitingInput。未复现历史误判，不把提示词mock用例视为模型准确率证据；未执行测试或验证4B、安装态和真实UI。
- T2: 本任务仅编辑Pi分类提示词、隔离mock用例和说明文档；实际调用仅通过固定127.0.0.1 Ollama发送作为数据的示例文本，未调用扩展默认注册函数，未执行git commit/push、移动端操作或修改用户安装态。TS转换及模块解析、MJS node --check、限定git diff --check通过；单元测试与测试套件未运行。
- Review gate: Skipped — 当前R1四项依据成立：提示词局部增强、现有状态路径不变、低风险可恢复、当前指定格式及反例已有实际分类输出；没有显式或既有独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 局部提示词和正反例增强，不改变协议、模型选择、鉴权或生命周期逻辑；用户指定格式通过当前本地模型的实际生产函数验证。
- Snapshot: sha256:Pi=f603483719c028f6d3638dd6b0e7af8f7792505ebf430165a33d59eef8ad081c;Mock=da0768eff9011f661a33f695f03337ee0a1e67b4ae92be380a154ba39a611104;Docs=8ed465844af4a0fe7c420c30ee21d5dec27467c4d967372a4824b63e9b3a8a0e
- Evidence: T1/T2包含原例前后实际模型输出、Markdown正例与完成/引用/重启反例，及当前语法检查结果和运行边界。
- Result clarity: 目标仅为明确待确认结构化回复属于question；无问号也成立，标题和引用单独不构成当前提问；不执行示例工作。
- Bounded impact: 仅classifyReplyWithModel的system prompt增加说明和示例；调用、输入长度、JSON二分类解析、错误保持和awaitingInput映射均未变。
- Low risk: 结果只影响会话待回复展示与导航优先级，不执行或授予提交/推送等权限；无需不可逆操作即可恢复。
- Sufficient verification: 当前本机2B通过实际生产函数完成五条分类观察，原例和Markdown为question，三条反例为normal；模块与测试文件仅语法检查通过。未验证4B或真实运行集成，不保证所有文本的模型准确率，不声称单元测试通过。
- Task fingerprint: 7d894c6b733251f9b3c381eae8878b44739b6b1629be8f94516ec3e24bbdef2d

## Verification

- Passed: 最终三文件SHA256与当前评估一致，实际模型观察绑定的Pi源码未变；再次TS模块解析、MJS node --check与限定git diff --check通过。当前2B对原例/Markdown均question，对完成/引用/重启说明均normal；未运行单元测试、测试套件、4B或真实UI，未覆盖或reload用户集成。
