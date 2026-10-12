# Agent最后回答是否向用户提问：修正目标后的实测

## 定义与边界

按已确认边界判断向用户提问；仅等待确认的陈述不是问句。疑问句/疑问表达为正，命令句/请求句本身不是疑问表达；自问自答、文档标题和引用/代码中的问句为负。判断整条最后回答，而非只看最后一句。

- 正例包含已完成工作后的可选追问，以及没有问号的疑问表达。
- “确认后我再继续”“等待你授权后继续”为负例；“请确认范围”“请选择版本”是请求/命令句，不因需要回应就判为问句。
- 这里不是评估是否等待用户输入，也不是评估终端状态或最终问号UI。
- 全部48条样本为合成数据，中英文各24条，每种语言问句/非问句各12条。每配置两轮；正确率只计首轮48条。
- 标签和提示词在输出产生前冻结，没有根据结果调参；没有独立盲标或真实生产样本。部分文本沿用前次，但标签目标改变，不应把新旧准确率差看作同任务提示词提升。

## 结果

| 配置 | 正确/48 | 漏报/24问句 | 误报/24非问句 | 中文正确/24 | 英文正确/24 | P50 | P95 | 后端 | 两轮变化 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Laya choice | 23/48（47.9%） | 12/24 | 13/24 | 16/24 | 7/24 | 26.1 ms | 396.8 ms | existing-loopback-service | 0/48 |
| Laya noul | 20/48（41.7%） | 10/24 | 18/24 | 11/24 | 9/24 | 17.3 ms | 316.3 ms | existing-loopback-service | 0/48 |
| GLiNER2.5-multi-Decide | 23/48（47.9%） | 23/24 | 2/24 | 12/24 | 11/24 | 93.9 ms | 125.7 ms | torch-cpu | 0/48 |
| GLiClass multilingual mini | 24/48（50.0%） | 24/24 | 0/24 | 12/24 | 12/24 | 678.4 ms | 1218.8 ms | torch-cpu | 0/48 |
| Vela 2.0 0.3B | 41/48（85.4%） | 3/24 | 4/24 | 21/24 | 20/24 | 55.1 ms | 76.5 ms | torch-cpu | 0/48 |
| Kev 0.8B | 27/48（56.2%） | 17/24 | 4/24 | 14/24 | 13/24 | 87.6 ms | 96.8 ms | mlx | 0/48 |
| system-one Qwen3 0.6B | 37/48（77.1%） | 5/24 | 6/24 | 18/24 | 19/24 | 91.4 ms | 106.3 ms | mlx | 0/48 |
| Liquid d1-3B | 33/48（68.8%） | 10/24 | 5/24 | 17/24 | 16/24 | 345.5 ms | 428.9 ms | torch-mps | 0/48 |

延迟不含下载、初始化和独立warm-up，但含分词/输出读取；Laya还包含本地HTTP开销。M4/32GiB机器不是独占环境，各后端不同，不能当作纯模型速度或生产SLA。两轮一致不是准确性证明。

## 边界实例

| 输入 | 正确标签 | Laya choice | Laya noul |
| --- | --- | --- | --- |
| 我可以开始修改了吗？ | question | question | question |
| May I begin making the changes? | question | normal | question |
| 文档已经写完。是否还需要我更新示例？ | question | question | question |
| The documentation is done. Would you like me to update the examples too? | question | normal | normal |
| 确认后，我会修改解析逻辑并重新评审。 | normal | normal | normal |
| Once you confirm, I will modify the parser and review it again. | normal | question | question |
| 请确认范围后我再开始。 | normal | question | question |
| Please confirm the scope before I begin. | normal | question | question |
| 为什么构建失败？因为缺少依赖。我已经补齐依赖并完成构建。 | normal | question | question |
| Why did the build fail? A dependency was missing. I have added it and completed the build. | normal | question | question |

## 本轮结论

- 在当前固定定义及样本上，Vela为41/48（85.4%），漏报3条、误报4条；system-one为37/48（77.1%）。小样本不能证明稳定的生产排名。
- Laya choice为23/48（47.9%），noul为20/48（41.7%）；明确提问与非问句边界都存在错误。不能声称当前Laya配置已经可靠解决该二分类，也不能由这一固定配置推出模型所有提示词都无效。
- Vela也会漏掉“文档已经写完。是否还需要我更新示例？”及“Continue?”，并把说明性问句标题或请选择类命令误判为提问；因此尚无可宣称完美的候选。
- 本轮不更换模型、不改问号图标逻辑。后续若要集成，仍需独立标注验证及明确可接受的误报/漏报指标。

## 执行与证据

- 复用上轮已审查的模型适配器，evaluate.py仅替换冻结SUITE/QUESTION和本任务输出目录；旧报告、旧样本与产品源码不变。
- 八个配置都调用真实模型，各96条原始输出；分类函数只接收文本，不传样本expected标签。Kev内部固定占位标签不进入输入token，沿用上轮已审查服务编码路径。
- 所有候选使用离线缓存，未重新下载；Laya仅调用原有loopback服务。未重启用户App/Pi/Laya、未上传真实会话。
- 指标自检、两轮完整性检查、原始输出重新推导预测、样本与SHA256核对通过。未执行产品测试套件或UI验收。
- [冻结样本及定义](../evidence/suite.json)、[评估入口](../evidence/evaluate.py)、[串行执行及源版本绑定](../evidence/run-manifest.json)、[指标和逐类别汇总](../evidence/summary.json)。
- 版本与环境沿用[上轮固定版本](../../explore-open-system-one-models/evidence/models.json)和[机器记录](../../explore-open-system-one-models/evidence/environment.json)；当前每个结果还记录运行时包版本。
- Laya choice：[原始输出](../evidence/result-laya-choice.json)
- Laya noul：[原始输出](../evidence/result-laya-noul.json)
- GLiNER2.5-multi-Decide：[原始输出](../evidence/result-gliner.json)
- GLiClass multilingual mini：[原始输出](../evidence/result-gliclass.json)
- Vela 2.0 0.3B：[原始输出](../evidence/result-vela.json)
- Kev 0.8B：[原始输出](../evidence/result-kev.json)
- system-one Qwen3 0.6B：[原始输出](../evidence/result-system-one.json)
- Liquid d1-3B：[原始输出](../evidence/result-d1.json)
