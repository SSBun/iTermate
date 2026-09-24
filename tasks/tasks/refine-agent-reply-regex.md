# 增强 Agent 待回复消息的正则识别

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-20 17:16) |
| Kind | Task |

## Scope

仅增强 Pi 集成中的末尾消息正则识别及其回归用例；不引入 LLM、不修改状态传递或图标、不覆盖用户安装态。按当前授权不运行测试。

## Plan

1. 扩展中英文请求与等待表达，同时保留保守的双重判据和误报防护。
2. 补充正反例回归用例，进行静态语法检查及逐项源码核对；不运行测试。
3. 记录验证范围、审查分级及交付限制。

## Target
- [x] T1: 扩展中英文待回复表达的正则识别，减少明确请求确认、选择或补充信息时的漏判。
- [x] T2: 保留对代码、引用、否定及非阻塞建议的误报防护，不引入 LLM 调用。

## Result

- T1: 源码逐项核对新增请求与等待模式：批准/授权/选定/告知/告诉我、approve/clarify/specify/preference、awaiting/收到回复再继续等均有对应分支；新增21条正例用例但未执行。TypeScript 5.9.3 strict noEmit 对实现与用例检查为0 diagnostics。
- T2: git diff 核对清理代码/引用、最后两段及1200字符限制、request && waiting、生命周期与传输代码保持不变；新增否定保护及21条反例，覆盖RFC建议、非阻塞问句、否定、引用与代码。仅仓库源码改动，无LLM、安装覆盖或App重启；测试及端到端未运行。
- Review gate: Skipped — R1四项依据已记录，纯局部提示判断由源码对照和静态检查支持；无独立审查请求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 局部纯布尔正则扩展，仅影响等待图标分类，不触发或授权操作。
- Snapshot: sha256 integration.ts=00ac14ca0b060f6ddaa79a15ea862450094b90fef23b944b0ecb36b381f6daf5; integration.test.ts=92c6caed38bdc1edc60e259ed96779e8882fb7b2ce078b354d0d396b04e887a2; scoped unstaged diff
- Evidence: T1/T2 源码逐分支核对及严格类型检查；git diff --check通过。
- Result clarity: 保留双判据，扩充中英文阻塞请求词形；隐含意图不承诺识别，RFC提纲仍无匹配。
- Bounded impact: 仅needsReply及回归用例；调用方仍在正常agent_end保存布尔值并于agent_settled发布，交互事件和传输未改。
- Low risk: 误判只改变可恢复的提示状态；无执行权限、网络调用或用户数据写入，输入窗口仍有1200字符界限。
- Sufficient verification: 直接比较旧正则与新增分支，逐项人工核对42条新增正反例及原有防护；TS5.9.3 strict noEmit为0诊断；未运行测试，未验证安装态。
- Task fingerprint: fb2ece047b86e8438b642b098f42b95b8d0142676fad2d3e2c952ee2e3fdd49a

## Verification

- Passed: 最终git diff --check通过；两个源码文件SHA-256与审查评估完全一致，TypeScript5.9.3严格类型检查证据仍有效。逐项源码核对双重判据及排除逻辑，未运行测试或App、未修改用户安装副本。
