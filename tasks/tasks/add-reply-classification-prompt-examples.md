# 为回复分类提示词加入正反例

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 16:37) |
| Artifacts | [Artifacts](../artifacts/add-reply-classification-prompt-examples/) |
| Kind | Task |

## Target
- [x] T1: 分类 system prompt 明确区分结果交付附带操作说明与等待用户回应，包含用户提供的重启验证负例和确认、选择、必要信息正例。
- [x] T2: 仅调整分类提示词与必要的配套内容，不改变模型选择、分类标签或生命周期失败回退行为。
- [x] T3: 修改分类提示词前先执行回复类型分类相关单元测试并记录基线，修改后重新验证；区分单元测试结果与真实本地模型判定效果，不以模拟结果宣称准确率提升。

## Scope

- 只修改仓库中的 Pi 回复分类提示词及直接相关测试；模型选择、JSON标签、输入边界、超时和生命周期回退保持不变。
- 不覆盖用户已安装的集成，不启动或重启 App、Bridge、Pi 或 Ollama；不运行全项目测试套件。

## Plan

1. 修改提示词前执行现有分类与模型选择单元测试，记录基线，并用固定合成输入观察本地2B真实判定。
2. 收窄操作说明与等待回应的定义，加入中英文正反例，补充提示词接线与协议边界回归。
3. 复跑相关单元测试与同组本地样例，对比任务专属差异，记录限制并完成验证。

## Decisions

- 用户确认初始目标后追加“修改前先运行分类单元测试”；更新后的完整目标经用户再次确认，测试限制以此次授权为准。
- 修改提示词前：tsx运行分类与标签相关测试21/21通过。模型选择VM测试原入口因strip-only模式不支持现有TypeScript参数属性而无法加载；使用临时preload开启transform、不改源码后6/6通过。另一次临时preload尝试因data URL不能作为createRequire路径而失败，修正为绝对路径后成功；没有隐藏此类入口失败。
- 基线建立后，仅为本轮相关VM测试把stripTypeScriptTypes设置为transform，使标准命令可直接运行。新增提示词边界断言在旧提示词下失败，随后修改提示词使其通过。
- 本地模型诊断固定使用已安装的qwen3.5:2b及受支持digest，通过127.0.0.1调用；这是独立诊断，不是应用的模型选择或失败回退。4B库存不可用，未实测4B。
- 同一组12条样例基线为10/12；用户完整原文基线已为normal，误判的是另外两条操作说明。首轮修改修复两条说明但回归一条英文说明；加入英文对照后自主进展样例回归，再补充自主进展与引用负例后为12/12。各次原始观察均保留；最终提示词包含部分评估样例，结果不是独立泛化评估或准确率保证。
- 最终单元测试34/34通过，包含14项分类/旧规则、7项共享协议/标题边界、13项模型选择/回复接线测试；mock仅证明接线、解析与失败边界，不证明语义准确率。真实12条样例与mock证据分开记录。

## Task Summary

**Pi集成**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 收窄回复分类system prompt的等待回应定义，加入12条中英文正反例，覆盖结果附带操作说明、授权、选择、必要信息、隐式确认、混合报告、自主进展与引用；补充请求负载、严格标签和输入边界测试，并修复该测试入口的TypeScript转换模式。不修改生产调用逻辑。

## Evidence

- 本地合成样例诊断脚本：[probe.py](../artifacts/add-reply-classification-prompt-examples/evidence/probe.py)。运行参数before/after；执行时从生产函数提取当时的提示词。
- 修改前观察：[before.json](../artifacts/add-reply-classification-prompt-examples/evidence/before.json)。
- 中间回归观察：[after-initial.json](../artifacts/add-reply-classification-prompt-examples/evidence/after-initial.json)、[after-bilingual.json](../artifacts/add-reply-classification-prompt-examples/evidence/after-bilingual.json)。
- 最终观察：[after.json](../artifacts/add-reply-classification-prompt-examples/evidence/after.json)。
- 任务专属差异与内容快照：[changes.patch](../artifacts/add-reply-classification-prompt-examples/evidence/changes.patch)、[snapshot.json](../artifacts/add-reply-classification-prompt-examples/evidence/snapshot.json)。
- 验证命令：`tsx --test integrations/pi/iTermate-integration.test.ts integrations/pi/task-summary.test.ts`；`node --experimental-vm-modules --test integrations/pi/local-llm-selection.test.mjs`；`git diff --check`限定本轮源码、测试和Context。Context标准验证通过。
- 限制：未运行全项目测试、未做4B真实推理或独立留出集评估，未更新安装态或运行态；使用本轮提示词仍需通过App正常入口更新集成并重新加载Pi。

## Result

- T1: 当前生产classifyReplyWithModel的system prompt按等待回应定义question，包含12条中英文正反例；用户重启验证案例保留核心原文为normal，授权/选择/必要信息/隐式确认和混合报告为question。实际请求负载单元断言通过，本地2B同组12条最终12/12；证据见evidence/after.json，非独立准确率评估。
- T2: changes.patch逐项比较修改前快照：生产TS差异仅system prompt字面量；模型选择、输入限长、JSON标签、超时、keep_alive和生命周期回退无改动。13项VM隔离测试覆盖模型身份切换、不回退、normal/question、非法输出及空/超长输入，均通过。未修改用户安装态或重启进程。
- T3: 修改提示词前现有21项测试通过；原VM入口参数属性转换失败，临时transform预加载后6项通过。新增提示词单元断言在旧提示词下先红，修改后21+13=34项全绿。真实2B另行记录before 10/12及最终after 12/12，含中间回归；mock不宣称语义准确率。
- Review gate: Skipped — R1四项依据齐备：生产仅提示词文字变化，影响限定状态提示，34项相关单元回归与固定2B样例已检查。无显式或既有独立评审义务；不把自查称为独立评审。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 已验证的分类提示词文字修正，生产执行逻辑不变；测试入口修正仅影响隔离VM加载。
- Snapshot: sha256:6136b05b6762565ebd827b7007396382424d83776f4a57f47a7683febc09eb93; tasks/artifacts/add-reply-classification-prompt-examples/evidence/snapshot.json
- Evidence: 逐项对照T1-T3与changes.patch；修改前基线27项、最终34项单元测试通过，固定2B样例10/12到12/12，来源哈希一致；Context验证与限定diff空白检查通过。
- Result clarity: 定义与正反例由用户确认；操作说明normal、等待回应question；不要求未经实测的准确率阈值。
- Bounded impact: 仅classifyReplyWithModel传入的system文本及直接测试；status消费者、模型选择与回退未动，作用域由开始快照差异限定。
- Low risk: 只影响可恢复的会话状态提示，不执行用户授权动作，不改变权限、数据写入或外部发布；没有安装或重启。
- Sufficient verification: 34项相关单元测试覆盖请求负载/模型身份/严格标签/输入边界；实际2B小样本含最终提示词12/12且哈希匹配。未测试4B和泛化准确率，已明确限制。
- Task fingerprint: 7e6cef2c7191fc9cb3fd3d91e564db0bc95efc400e0b6bb693015fd3ad754377

## Verification

- Passed: 终验逐文件重算snapshot.json内全部源码/测试/证据哈希，无漂移；before/after样例及预期相同，最终生产源码哈希绑定2B 12/12观察。34项相关单元测试已通过；JS语法与限定diff空白检查通过。没有全套测试、4B真实推理或安装态更新。
