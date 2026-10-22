# 将本地提交完成报告加入问题分类回归并修正提示词

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-22 11:54) |
| Artifacts | [Artifacts](../artifacts/classify-local-commit-report-as-normal/) |
| Kind | Task |

## Target
- [x] T1: 截图中的已本地提交、工作树干净、未推送远端和未运行测试的结果报告加入问题分类回归，预期为normal。
- [x] T2: 调整分类system prompt后，新用例与全部现有问题分类用例通过，不删除用例、不放宽预期；区分真实本地模型效果与mock协议检查。
- [x] T3: 修改限于问题分类提示词及直接相关测试，不改变标题、模型选择、状态生命周期或用户安装态。

## Scope

- 执行问题分类相关测试：既有分类/旧规则测试、共享二分类协议测试、隔离模型选择与提示词覆盖测试，以及新增的真实本地模型语义回归。不运行全项目测试套件或与本轮无关的归档、子代理生命周期和UI测试。
- 新回归集保留前次12条本地语义样例、结构化Task Target正反例与英文授权例，新增截图提交报告、中英文同义与正反对照；不将mock返回标签当作语义准确率证据。
- 不推送远端，不执行样例里的提交、测试或移动端操作，不修改安装配置、不启停Ollama、不覆盖集成或重启App/Bridge。

## Plan

1. 运行既有分类/协议测试，建立源码与模型行为基线。
2. 将既有语义观察样例和截图提交报告整理成持久回归集，通过生产分类函数执行，记录旧提示词的真实失败。
3. 仅补充system prompt的事实披露/等待授权边界及中英文对照例，添加直接请求负载回归。
4. 复跑全部本轮分类测试与真实模型案例，核对没有删改原预期，类型/语法检查后记录结果及验证限制。

## Decisions

- 用户确认完整目标后执行。Lessons查询器把旧式Trigger/Rule/Check拆成无标题项，已按原文检索并应用不得重启App及不得覆盖用户安装态的约束；本轮不新增或修改Lessons。
- 修改生产提示词前，既有分类/协议测试35项通过。将前次语义观察整理为持久回归后，用真实生产classifyReplyWithModel调用本机默认qwen3.5:2b复现：22条语义用例中，截图正文和英文同义提交报告错误返回question，其他20条通过；原始失败日志保留。
- 只补充“未推送/未测试是事实披露，不应臆测确认门”的提示词说明，并加入截图正文normal、英文报告normal及显式请求推送授权question三条对照例。没有新增关键词规则或normal强制覆盖逻辑。
- 新增22条固定语义用例与显式启用的真实本地模型测试入口，包含全部前次12条样例及其原始预期、Task Target正反例、英文授权和本轮提交报告对照；额外清单版本是截图界面混合内容的稳健性变体，不声称运行时分类输入包含该界面清单。
- 新真实语义测试未注入标签或mock HTTP，直接使用生产配置、输入限制、模型库存身份校验和严格JSON解析；undefined视为失败，不转成normal。默认不自动启动模型测试，显式设置ITERMATE_REPLY_CLASSIFICATION_LIVE=1后按序执行，避免并行挤占本地模型。
- 更新提示词后，两次完整真实分类复跑均为22/22；相关测试检查总计60项通过、0失败、0跳过（Node计数包含用例集检查及父测试）。隔离VM新增覆盖只证明请求负载和协议接线，不用于宣称模型准确率。
- 默认配置文件不存在，生产函数按既有规则选择已安装2B并核验固定digest；本轮库存不含4B，未验证真实4B。全套项目、子代理生命周期及真实UI未运行，未安装或reload集成；固定回归全部通过不意味着所有自然语言上下文都能正确分类。

## Task Summary

**Pi问题分类**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 增强分类system prompt对本地提交、工作树状态及未执行动作的事实披露边界，并加入中英文报告与推送授权对照例；新增22条共享语义回归、生产函数真实本地模型测试入口及隔离VM请求覆盖，不改变分类调用或状态生命周期。

## Evidence

- 新增固定用例：[reply-classification-cases.json](../../integrations/pi/reply-classification-cases.json)。真实本地模型入口：[reply-classification.test.ts](../../integrations/pi/reply-classification.test.ts)。
- [旧提示词真实失败](../artifacts/classify-local-commit-report-as-normal/evidence/live-before.log)：22条语义用例中2条失败，父测试随子项失败；不是协议mock制造的失败。
- [首次修改后分类通过](../artifacts/classify-local-commit-report-as-normal/evidence/classification-after.log)、[协议mock通过](../artifacts/classify-local-commit-report-as-normal/evidence/protocol-after.log)、[最终完整复跑](../artifacts/classify-local-commit-report-as-normal/evidence/final-suite.log)。最终TS组45项、VM组15项全部通过，含22条真实语义子用例，无跳过。
- 测试命令：`ITERMATE_REPLY_CLASSIFICATION_LIVE=1 tsx --test integrations/pi/iTermate-integration.test.ts integrations/pi/task-summary.test.ts integrations/pi/reply-classification.test.ts`；`node --experimental-vm-modules --test integrations/pi/local-llm-selection.test.mjs`。
- 其他检查：`tsc --project tasks/artifacts/classify-local-commit-report-as-normal/evidence/tsconfig.json`严格noEmit通过，覆盖新增测试源码；MJS的`node --check`、JSON解析及限定`git diff --check`通过。精确比较开始快照，生产源码除classification system prompt外无变更；自动逐条比对前次12条文本和预期全部保留。
- [本轮差异](../artifacts/classify-local-commit-report-as-normal/evidence/changes.patch)、[内容快照](../artifacts/classify-local-commit-report-as-normal/evidence/snapshot.json)绑定生产源码、测试/用例与实际日志；不将HEAD当作已有大量未提交变更的内容标识。

## Result

- T1: 共享回归集中local-commit-report按截图正文转录并预期normal；旧生产提示词在真实2B调用中返回question复现失败，最终两次复跑均返回normal。清单变体与英文同义报告也通过，显式请求推送授权仍为question。见live-before.log和final-suite.log。
- T2: 既有35项分类/协议检查基线通过；最终TS组45项及VM组15项全部通过，0失败0跳过，含直接生产函数的22条真实语义用例。前次12条原始文本和预期逐条比对不变，Task Target及其他旧断言未删除/放宽。严格TS类型检查、MJS语法、JSON解析和diff检查通过。
- T3: 开始快照精确对照证明生产源码除classifyReplyWithModel的system prompt以外一致；没有修改标题、模型参数、标签解析、输入限制或生命周期。其他交付变更仅共享测试数据、新真实模型测试和隔离mock覆盖。未写用户安装态或配置、未重启App/Bridge/Ollama，未执行样例里的commit/push。
- Review gate: Skipped — R1四项依据齐备：已复现并验证的提示词修正、限定影响、低后果、60项当前相关检查通过；无显式或既有独立审查要求。没有用mock替代真实模型效果或宣称独立审查。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 提示词局部语义修正及直接相关测试，生产调用与状态逻辑保持不变，目标由真实模型失败到通过证明。
- Snapshot: sha256:5577d18653ff5a84d48b041e1056284e9a949fded9ebd9c6c8ada24e2437c3ea; tasks/artifacts/classify-local-commit-report-as-normal/evidence/snapshot.json
- Evidence: 22条真实模型回归从20/22到22/22，更新后两次完整复跑通过；最终相关检查60项、0失败0跳过。前次样例预期及既有断言保留；生产差异只有提示词。TS/MJS/JSON和diff检查通过，证据与源码由manifest绑定。
- Result clarity: 已确认目标：提交完成报告的未推送未测试属normal，真正请求授权或必要信息仍question；不改变其他系统边界。
- Bounded impact: 仅classifyReplyWithModel已有system文本；状态消费者和失败回退未改，测试入口直接调用同一生产函数且不注册扩展。
- Low risk: 只影响可恢复的会话待回复显示和切换优先级，不授予权限或执行commit/push，无代码路径或安装态改变。
- Sufficient verification: 既有分类单元、协议mock、提示词负载和真实生产本地推理均检查；22条语义用例保持预期并全部通过，另外严格类型/语法和精确差异检查。仅真实2B，4B和UI未验收；不承诺固定样例以外的准确率。
- Task fingerprint: 7c6688c3a2f4a79c219c1ad035a167d9545c76f90943484a0ed6380de424b8b7

## Verification

- Passed: 终验逐文件重算snapshot源码、用例、测试和日志哈希，无漂移；最终日志确认45+15=60项通过、0失败、0跳过，含22条生产函数真实本地2B语义回归。TS严格检查/MJS语法/JSON与限定diff检查通过；不宣称真实4B、UI或全项目测试通过，未更新运行态。
