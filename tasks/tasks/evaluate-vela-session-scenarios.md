# 构建场景数据评估 Vela 终端状态分类准确率

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-12 14:17) |
| Artifacts | [Artifacts](../artifacts/evaluate-vela-session-scenarios/) |
| Kind | Task |

## Target
- [x] T1: 构建预先标注预期状态的终端文本场景集，覆盖运行、等待回复、空闲、未知及易混淆场景。
- [x] T2: 使用实际 Vela 服务逐例分类，报告总体和各类别准确率、混淆情况、错误样本，以及现有展示阈值下的覆盖率和准确率。

## Result

- T1: 推理前写入 artifacts/evaluate-vela-session-scenarios/evidence/scenarios.json：40个唯一ID，四类各10条，每类中英各5条；包含旧问题已回答、引用问句、监听服务、失败退出、未知片段。结果中的dataset_sha256与输入一致，复核逐条输入无改动、无删题。
- T2: 实际Vela-2.0-0.3B /v1/session 40/40成功且无重试，分类39/40正确；现有阈值展示18/40且18条全对；明确状态覆盖18/30，等待回复仅1/10显示。报告 ../artifacts/evaluate-vela-session-scenarios/reports/report.md，原始结果及可复跑脚本位于同任务 evidence；独立重算逐例概率阈值、输入哈希、混淆矩阵、唯一错题I03及等待输入过滤结果通过。仅评估合成集，不修改产品/提示词/阈值，不重启App；未运行项目套件。
- Review gate: Skipped — R1 四项依据具备，无独立评审要求；独立重算为主Agent自检，不宣称子代理评审。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 任务产物仅固定数据、只调用本机鉴权API的顺序评估脚本、原始输出和报告；不改变产品行为；结果可逐例复算。
- Snapshot: scenarios.json sha256:130f1eab118cd1fd48b850722ea8b871e6c1de61f7468fb25bb6330d94869b25; evaluate.py sha256:acf4eb1a35deff68fecec4d0d0fdc658bad1f6c5eb145bd57c01376e87372c0d; results-20261012T061500650477Z.json sha256:c3793b2ff6e29df4a8851ef80ffed22911cf6459d9dd5f1e4b9831472ef303fc; report.md sha256:cc02cbe1a16645fb0559eba11b7cc644b6815f9c2565265aa77c90ea1a0f5207; 均为本任务目录新增产物。
- Evidence: T1/T2 Result，40条实际响应；另外一次独立汇总校验、AST语法检查、git diff --check及Context validate通过。
- Result clarity: 预标注四类场景、固定数据单轮真实调用、原始准确率及阈值后的覆盖率/正确率均已给出。
- Bounded impact: 仅本任务产物和生命周期记录；请求固定回环地址、禁止重定向，未修改配置或服务，未输出凭据。
- Low risk: 合成非敏感文本，无生产写入；每条最多3次仅429重试；报告明确小样本及显式线索偏差，不以97.5%推断真实场景准确率。
- Sufficient verification: 输入/结果逐条对照及SHA256核验、混淆矩阵独立重算、展示条件逐例核对、成功率40/40、全部未超800ms；展示18条全对但等待回复仅1/10，限制已写明。
- Task fingerprint: 3281c59b1881f7f5580f19992258b6a534429db9e0049d3f18e42a14c3673b90

## Verification

- Passed: 最终四个产物哈希与assessment一致；数据未依据结果修改；原始API、逐例重算与报告相符，AST、diff及Context检查通过；未修改产品或运行项目套件。
