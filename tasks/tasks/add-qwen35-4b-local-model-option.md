# 新增Qwen3.5四十亿参数本地模型选项

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 15:55) |
| Artifacts | [Artifacts](../artifacts/add-qwen35-4b-local-model-option/) |
| Kind | Task |

## Scope

- 新增Qwen3.5的4B选项，与既有2B并存；没有保存选择时维持2B，不自动下载模型或替换用户运行态。
- App与Pi共用独立LocalLLM选择配置，不读取或恢复旧Decision偏好。选择无效、不可读或所选模型未安装时明确失败，不静默回退。
- 每次推理使用所选模型的库存身份，并检查配置在请求过程中未变化；十分钟keep_alive、取消、失败保留原标题与旧Decision停用保持不变。
- 用户修订标题格式为软预期：中文可含英文技术词、最多十六元素及无标点/空白/数字仅放提示词，程序格式验收只要求非空标题，不因偏离这些预期而拒绝；响应完整性、身份、超时和通信安全边界不放宽。
- 本机当前没有4B；仅查询库存与核实官方标签，不擅自安装。当前请求未授权运行测试套件，采用构建、类型检查和不改偏好的本地观察，披露4B真实推理未验证。

## Plan

1. 设置提供2B/4B选择并原子保存共享配置，支持重启读取、可用性检查和对应模型预热。
2. 问题分类和标题生成读取同一配置，校验所选库存和请求身份，丢弃切换时的迟到结果。
3. 更新模型选择与边界的测试源码、说明和Context，构建并记录已验证范围。
4. 按实际跨进程配置风险进行独立只读评审，处理确认问题后终验。

## Task Summary

**Local LLM设置**：在 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/) 新增2B/4B模型枚举与选择控件，用独立配置原子保存模型标签和UUID版本；重启读取、对应库存检查和预热均跟随所选模型，配置或库存变化时不发布过期就绪状态。

**Pi本地模型调用**：在 ["/Users/caishilin/Desktop/personal/iTermate/integrations/pi/"](file:///Users/caishilin/Desktop/personal/iTermate/integrations/pi/) 新增共享选择解析与所选库存身份绑定，问题分类和标题生成按保存选择调用，校验配置及digest在请求中未变化；新增隔离协议测试源码。

**原生模型选择验证源码**：在 ["/Users/caishilin/Desktop/personal/iTermate/iTermateTests/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests/) 补充默认选择、4B保存重读、无推理保存、无效配置与库存不替代其他模型的检查用例；本轮只编译，未执行测试。

**模型使用说明**：在 ["/Users/caishilin/Desktop/personal/iTermate/docs/"](file:///Users/caishilin/Desktop/personal/iTermate/docs/) 说明模型选择共享、4B自行安装、无回退、配置身份和安装digest校验，以及原有标题保留策略。

## Decisions

- 用户确认增加Qwen3.5 4B，与2B并列可选；保留当前默认2B，不自动下载、切换或恢复旧Decision体系。
- 选择的唯一保存来源是独立LocalLLM/configuration.json；只在用户明确选择时写入。配置不存在时默认2B，配置错误或不可读时不选择其他模型。
- 2B保留已有固定digest限制；4B按已安装同名标签校验合法digest，并在预热/推理前后绑定同一库存身份，不虚构尚未安装模型的revision。
- 本机库存只有2B与0.8B，4B未安装。官方4B标签已只读核实，不执行安装。真实4B推理、准确率和速度未验证。
- 应用与测试目标的build-for-testing编译成功，没有执行测试；TypeScript严格类型检查与新JavaScript测试源码语法检查通过。未做真实UI验收，不启动或替换运行中的App/集成。
- 手工只读观察默认选择仍为2B，合成分类返回true、标题十五元素；4B库存判定不可用，配置文件仍不存在且前后未变化。证据见manual-observation.json。
- 检测到同一Pi文件的并行日志改动及其他Context Pack的快捷键变更，均保留且不归属本任务。原始baseline不修改；review-base为当前文件减去本任务功能的比较基线，round-01.diff仅呈现本任务差异，unrelated-observed.diff记录被排除的无关改动。新增隔离测试仅适配当前已有导入，不更改并行日志功能。
- 第一轮TR-1的readdirSync模拟遗漏已修复，第二轮独立评审确认静态根因解决；第二轮因并行标题规则变化及内容漂移未通过终验，旧快照与旧T3证据不再代表当前内容。
- 用户明确选择宽松规则并确认完整修订Target：格式限制仅为提示词预期，程序只拒绝空白标题。当前Pi、Swift消费者、测试、说明与Context已由并行标题修复采用该规则；本任务接纳为已授权合并基础，不回写硬过滤，也不将其实现归为本任务新增。
- 按当前合并内容重新编译应用及测试目标成功，严格TS检查、JS语法、静态模拟导出核对与Context校验通过；未执行测试或UI验收。手工当前源码返回含HTTP、空格及429的非空标题且原样保留，选择仍为2B、配置文件未写入，见manual-accepted-03.json。
- 第三轮比较基线review-base-03保留已接受的并行宽松标题与日志实现，只剔除本任务4B选项相关改动；Context身份仅绑定本任务相关模型Pack，不把无关Pack的并行更新视作本任务源码。原始及前两轮材料保持不改。

## Target
- [x] T1: Local LLM设置支持Qwen3.5的2B与4B选项，模型选择可保存。
- [x] T2: 问题类型判断和标题生成均使用所选本地模型，模型不可用时不静默切换或调用云端。
- [x] T3: 保持每次推理后十分钟空闲热驻留，以及旧Decision体系停用状态。
- [x] T4: 标题的中文、十六元素及无标点/空白/数字要求仅作为提示词预期，程序格式验收只要求非空，不因不满足这些预期而拒绝。

## Result

- T1: 当前合并版本的2B/4B选择、原子配置保存与初始化重读已检查，应用及包含原生选择用例的测试目标在build-accepted-03.log编译成功；没有执行测试或真实UI操作，也没有写入用户选择。
- T2: 当前源码两类推理共用所选配置及前后身份检查，无回退其他模型或云端分支；当前2B实际生成标题成功且配置前后未变，见manual-accepted-03.json。协议模拟导出静态核对无缺失。4B真实推理未验证，未安装/下载模型或执行测试。
- T3: 当前预热/推理keep_alive=10m与三端旧Decision关闭门保持；当前合并内容编译、严格TS检查、JS语法和Context校验通过，证据更新到第三轮，不再沿用第二轮已漂移快照。
- T4: 用户已确认格式仅作提示词预期；当前提示词仍有十六元素、中文及无标点空白数字指导。Pi谓词仅检查trim后非空并返回原文，Swift仅保留非空与通信大小边界。实际返回含HTTP、空格和429的标题并原样保留；accepted-content-03.json与manual-accepted-03.json记录当前证据。
- Review gate: Passed — 第三轮fresh只读reviewer运行ed533769-2ad7-48c7-b437-73a2692ca355无新发现或阻塞风险，TR-1与TR-2均resolved；原始反馈保存reviews/round-03.md并索引。主Agent结束后重算10源码/17证据/相关Context Pack无漂移，报告与返回原文一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 用户修订为宽松标题规则后，重新采用当前合并内容及新快照；跨进程模型选择和异步身份校验的Required独立评审义务保持。
- Snapshot: sha256:8e3b91560ff9463aa08bdabe3e12c721c2914e697197b60800964e1683eb8e6e; tasks/artifacts/add-qwen35-4b-local-model-option/evidence/round-03-snapshot.json
- Evidence: 当前合并版本应用/测试只编译成功，TS严格检查、JS语法、静态导入导出匹配、Context校验通过；实际2B非空标题含数字与空格可原样返回，用户配置未改。4B推理及UI未验证，未执行测试。范围已按获准并行宽松规则重建。
- Task fingerprint: 973f85578afecdc15360da11e9c761a345ed42b5afc53eaa39d473b74be94187
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第一轮](../artifacts/add-qwen35-4b-local-model-option/reviews/round-01.md) | sha256:f1ffcdf29b761638ed444a99c85377ec8d92a4c4d6b3f770ce5257f9dcc33cf0 | findings: TR-1 |
| 02 | [第二轮](../artifacts/add-qwen35-4b-local-model-option/reviews/round-02.md) | sha256:b769269cc3a72b38ff562efa8a1391325607aec1cce5e820096950b7004e6193 | invalidated by drift; TR-1 resolved |
| 03 | [第三轮](../artifacts/add-qwen35-4b-local-model-option/reviews/round-03.md) | sha256:8e3b91560ff9463aa08bdabe3e12c721c2914e697197b60800964e1683eb8e6e | no blocking findings; TR-2 resolved |

## Verification

- Passed: 终验再次核对第三轮快照、全部绑定源码/证据及相关Context Pack哈希，无漂移；独立报告已保存且原文一致。当前合并内容应用/测试目标仅编译成功、TS与静态检查通过；2B手工非空标题含空格数字原样返回。4B真实推理及UI未验证，未执行测试或更改用户选择。
