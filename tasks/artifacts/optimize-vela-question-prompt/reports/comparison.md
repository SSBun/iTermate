# Vela 提示词优化：整体准确率验收

## 结论

**本轮未达到整体准确率超过90%的目标。** 开发集尝试20个候选后最高为43/48（89.6%）；按预先规则选出的speech-kind在留出集为62/80（77.5%），基线为61/80（76.25%）。只多对1条，不能认为获得稳定改进。

## 方法与边界

- 目标仍是Agent最后一条回答是否实际向用户提问，不是是否等待回复。隐含确认、命令请求、引用、代码和自问自答为负例。
- 48条旧评估样本仅作开发集；运行前另行冻结80条留出样本，各有一半中英文、一半问句/非问句，每语言每类别20条。二者无完全相同文本。
- 留出由同一作者合成，含中英对应及相关语义结构，不是独立人工盲标或生产随机抽样。所谓留出独立仅指不参与提示词选择，不能据此建立生产准确率。
- 第一轮12种候选，第二轮根据开发错误追加8种并先冻结再跑；包括简短、中英、few-shot、noul、顺序及answer角色字段。角色字段/类型变化不是纯措辞单因素。
- 按开发accuracy、较弱语言accuracy、预设序号依次选取。没有对类别阈值调参。selection.json先落盘，才运行所选项和预设baseline的留出验收。没有用留出结果重选模型或追加候选。
- 每个配置跑两轮以检验稳定性；合计2240次样本推理，另有22次warm-up。首轮48或80条计算准确率，不把重复执行视为更多独立样本。
- 固定Vela版本、PyTorch CPU fp32、4线程，复用离线缓存；没有产品改动、服务重启、真实会话上传或新模型下载。

## 留出集结果

| 配置 | 正确/80 | 漏报/40问句 | 误报/40非问句 | Precision | Recall | P50 | P95 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 基线 | 61/80（76.25%） | 11 | 8 | 78.38% | 72.50% | 49.3 ms | 71.4 ms |
| 选定speech-kind | 62/80（77.50%） | 5 | 13 | 72.92% | 87.50% | 40.3 ms | 63.3 ms |

逐例对比：9条从错变对，8条从对变错，63条正确性不变。减少漏报的同时增加了误报。

| 配置 | 中文正确/40 | 英文正确/40 | 两轮预测变化 |
| --- | --- | --- | --- |
| 基线 | 31/40 | 30/40 | 0/80 |
| 选定speech-kind | 32/40 | 30/40 | 0/80 |

延迟不含加载和warm-up，包含分词/输出读取；机器不是独占环境。本表只描述本轮观测，不是速度保证。

## 按开发集选择的提示词

```json
{
  "type": "choice",
  "instructions": "What is the communicative form of this assistant message?",
  "criteria": {
    "normal": "A statement, imperative, instruction, explanation, or quotation; no interrogative directed to the user.",
    "question": "An interrogative directed to the user, asking them something rather than explaining or quoting a question."
  }
}
```

这只是开发集胜者，不是通过验收的生产配置。不能把它描述为“90%以上准确率的提示词”。

## 开发候选全量对照

| 排名 | 候选 | 正确/48 | 较弱语言准确率 |
| --- | --- | --- | --- |
| 1 | speech-kind | 43/48 | 87.5% |
| 2 | minimal-noul | 43/48 | 83.3% |
| 3 | minimal | 43/48 | 79.2% |
| 4 | chinese | 42/48 | 83.3% |
| 5 | boundary-examples | 42/48 | 83.3% |
| 6 | unanswered | 42/48 | 75.0% |
| 7 | baseline | 41/48 | 83.3% |
| 8 | minimal-zh | 41/48 | 83.3% |
| 9 | speech-act | 41/48 | 79.2% |
| 10 | minimal-reversed | 41/48 | 79.2% |
| 11 | examples | 40/48 | 75.0% |
| 12 | positive-first | 39/48 | 75.0% |
| 13 | typed-examples | 39/48 | 70.8% |
| 14 | typed-answer | 38/48 | 75.0% |
| 15 | unanswered-detailed | 37/48 | 70.8% |
| 16 | recipient | 36/48 | 66.7% |
| 17 | noul | 35/48 | 66.7% |
| 18 | bilingual | 34/48 | 62.5% |
| 19 | unanswered-zh | 31/48 | 58.3% |
| 20 | grammar | 30/48 | 50.0% |

## 留出误判

| 输入 | 正确标签 | 预测 |
| --- | --- | --- |
| May I restart this process now? | question | normal |
| 现在发布？ | question | normal |
| Publish now? | question | normal |
| 无需再讨论上周的问题。今天的修改要发到正式环境吗？ | question | normal |
| I found the cause and have not changed any files. Should I fix it now? I will only write after confirmation. | question | normal |
| 任务暂停中，仍在等待你的许可。 | normal | question |
| The task is paused and is still waiting for your permission. | normal | question |
| 请提供设备编号，然后我会继续排查。 | normal | question |
| Please provide the device identifier, then I will continue investigating. | normal | question |
| ### How do you export data? / Click Export and choose a folder. | normal | question |
| 这条日志记录了用户昨天的问题：“什么时候发布？” | normal | question |
| This log records the user's question from yesterday: "When will it be released?" | normal | question |
| 用于测试的字符串如下，不是当前对话的问题： / js / const message = "要保存吗？"; /  | normal | question |
| Let me know if you need another export in the future. | normal | question |
| 你可以向管理员询问“我是否有访问权限？”，然后按其答复操作。 | normal | question |
| You can ask the administrator "Do I have access?" and follow their response. | normal | question |
| 谁会想丢失文件呢？这只是说明备份很重要，并不是要你作答。 | normal | question |
| Who would want to lose files? This is just a rhetorical point about backups, not a request for an answer. | normal | question |

## 下一步判断

仅调整提示词在本轮没有建立足够可靠的问句识别。更值得验证的方向是有独立标注集的专用分类微调，或更强模型；不能承诺任一方向必达90%。若继续调优，本轮留出集必须退役为已见数据，另建新的验收集。

## 证据

- [冻结输入哈希](../evidence/frozen-inputs.json)与[第二轮候选哈希](../evidence/frozen-round2.json)
- [开发样本](../evidence/development.json)、[留出样本](../evidence/holdout.json)
- [第一轮提示词](../evidence/prompts.json)、[第二轮提示词](../evidence/prompts-round2.json)
- [选择依据与时间](../evidence/selection.json)、[完整统计](../evidence/summary.json)、[自检](../evidence/self-check.json)
- [所选配置留出原始输出](../evidence/holdout-speech-kind.json)、[基线原始输出](../evidence/holdout-baseline.json)
- [真实执行脚本](../evidence/experiment.py)及[第一轮脚本快照](../evidence/history/experiment-round1.py)
- [指标核算与报告生成](../evidence/report.py)
