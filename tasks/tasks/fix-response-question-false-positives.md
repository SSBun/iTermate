# 修复普通回复被误判为问题的分类逻辑

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-23 16:10) |
| Artifacts | [Artifacts](../artifacts/fix-response-question-false-positives/) |
| Kind | Task |

## Target
- [x] T1: 普通陈述、执行结果和完成报告不再仅因包含问题措辞而被识别为等待回答的问题
- [x] T2: 真正要求用户回答、选择或确认的回复仍识别为问题

## Scope

- 以用户截图中「已提交、推送并创建 MR」「验收中」「MR 未合并」「未运行测试或完整构建」的完成报告作为明确 normal 样例，保留真实等待回答的 question 语义。
- 仅修改回复分类和直接相关回归数据，不改标题、生命周期、模型选择或用户安装态；保留工作区原有未提交改动。
- 当前请求不授权运行单元测试或测试套件；采用真实生产函数的手动样例观察及类型、语法、差异检查，不把未执行的回归测试声明为通过。

## Plan

1. 追踪实际回复输入及二分类请求，使用截图正文进行修改前手动观察。
2. 最小调整分类语义及相关样例，保留已有问题与完成报告的预期。
3. 对修改后生产函数进行手动烟雾观察、类型检查和差异检查，按实际风险完成复核。

## Decisions

- 用户补充截图明确红框为普通回复。截图中的 Task/Workspace 清单及 Writing check 位于回复之外，不凭截图臆测其进入生产分类输入。
- 不重启 App、Bridge 或 Ollama，不覆盖用户安装副本。仓库集成文件含其他任务已有改动，本轮以修改前文件为差异基线。
- 通过生产函数直接调用本机所选 qwen3.5:2b，修改前截图正文返回 question，修改后两次返回 normal。实际输入由 agent_end 最后一条 stop 助手消息的 text blocks 合并而来，agent_settled 发起后台判断；未发现按全屏文字分类的路径。
- 只收紧 system prompt 的当前用户请求证据：没有实际请求时使用 normal；隐式确认门也必须体现助手下一步依赖用户回复；等待 QA/CI/reviewer、MR 未合并和未测试不能推导用户确认门。不添加关键词硬覆盖，不修改推理参数、标签解析、生命周期或失败为 unknown 的行为。
- 新增截图转录、Markdown 报告、英文第三方等待报告及显式/隐式确认对照共5条样例；原22条文本和预期完整保留。回归测试仅更新固定数量，不执行测试入口。手动烟雾调用无 mock，无断言测试框架，不运行完整样例集。
- 手动观察还确认英文第三方等待报告为 normal，合并权限请求及用户确认门为 question，Markdown 报告为 normal。类型检查通过；仅本机2B观察，不宣称4B、UI或任意自然语言准确率已验证。

## Task Summary

**Pi 回复分类**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 收紧问题分类提示词，区分当前用户回复请求与 QA/CI/审查等状态事实；新增5条完成报告和确认对照回归数据，保留原样例并更新数量约束。

## Evidence

- [修改前观察](../artifacts/fix-response-question-false-positives/evidence/before.log)、[修改后观察](../artifacts/fix-response-question-false-positives/evidence/after.log)、[授权与第三方等待烟雾观察](../artifacts/fix-response-question-false-positives/evidence/manual-smoke.log)、[最终截图及Markdown观察](../artifacts/fix-response-question-false-positives/evidence/final-manual.log)。布尔 false 表示 normal，true 表示 question；unknown 不当作 normal。
- [生产差异](../artifacts/fix-response-question-false-positives/evidence/production-change.patch)、[样例差异](../artifacts/fix-response-question-false-positives/evidence/cases-change.patch)、[数据保留检查](../artifacts/fix-response-question-false-positives/evidence/data-check.log)、[类型检查](../artifacts/fix-response-question-false-positives/evidence/typecheck.log)。差异以本轮修改前内容为基线，不归属其他任务已有改动。

## Result

- T1: 直接调用生产函数与真实本机2B：截图转录修改前为question（before.log），修改后及最终复查均为normal（after.log/final-manual.log）；英文等待审查和Markdown状态报告也为normal。新增5条数据，原22条文本和预期不变；未运行测试套件。
- T2: manual-smoke.log中显式请求合并权限和隐式等待用户确认均为true即question；与等待QA/CI/reviewer的normal对照成立。模型参数、JSON解析、生命周期和unknown回退完全未改（scope-check.log）。只验证手动样例，不保证任意自然语言准确率。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 局部分类提示词修正，有真实生产函数修改前失败及修改后观察；不涉及权限执行或生命周期重构。
- Snapshot: snapshot:tasks/artifacts/fix-response-question-false-positives/evidence/c9ad10a63ce9c240019d680f5d960a85dc667a15f058613d340e9c815df643e6.json#c9ad10a63ce9c240019d680f5d960a85dc667a15f058613d340e9c815df643e6
- Evidence: T1/T2的生产函数手动观察、typecheck.log、data-check.log、scope-check.log及生产差异。
- Result clarity: 用户截图明确为normal；当前用户回复请求为question，与单纯等待第三方流程区分，无未决需求。
- Bounded impact: 生产改动限定classifyReplyWithModel提示词三段；上游仅最后助手文本，下游仍使用同一严格二分类结果，取消与失败路径不变。
- Low risk: 仅影响可恢复的会话等待标识，不执行MR合并或授予权限；不写用户配置、安装目录或重启进程。
- Sufficient verification: 截图修改前question到修改后两次normal；英文、Markdown报告normal及显式/隐式确认question的直接生产烟雾观察；TS noEmit、JSON和原22条保留比较、限定diff检查通过。未运行任何单元测试/套件，未验证4B或UI。
- Task fingerprint: e5256efd0378e340f7f951fbb4ca83ed5bd5cc5c14e94535059afcd7e637b610

## Verification

- Passed: 最终重新检查受管快照13项内容未漂移；final-manual.log截图与Markdown均normal，正例见manual-smoke.log；TS noEmit退出0、限定git diff --check通过，Context结构有效但保留既有未索引章节警告。源码未安装到运行态，未重启App或Bridge。
