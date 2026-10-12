# Vela 会话状态实测

## 范围与方法

使用固定版本 `vllm-sr/Vela-2.0-0.3B`（revision `d6f03aa9baca4f9017fa8f8e9c2764d3bed3f409`），本地缓存、隔离进程、CPU 推理。48条作者合成样本，中英各24条，running、awaitingInput、idle、unknown 各12条，每条两轮。标签在推理前写入 suite.json，模型只接收文本与产品 SESSION_QUESTIONS。样本较短，不覆盖屏幕截断及长上下文，不是盲标生产数据。

执行实际产品 Handler.do_POST 的 /v1/session 分支（内存请求，无 HTTP 监听，认证以 mock 放行），使用真实 VelaAgent。随后从产品源码 AST 提取实际 Bridge.update_model_observation 方法，使用隔离的合成屏幕及空缓存检查采纳结果。没有重写其阈值逻辑；没有运行用户 App、连接终端或更改现有服务。原始结果、冻结源码及脚本哈希保存在 evidence 下。

## 结果

首轮原始四分类准确率 **36/48（75%）**，第二轮预测完全一致；96次调用不能当作96个独立样本。全部 Handler 返回200。

| 真实状态 | 原始分类正确 | Bridge 采纳正确 |
| --- | ---: | ---: |
| running | 8/12 | 7/12 |
| awaitingInput | 10/12 | 0/12 |
| idle | 11/12 | 8/12 |
| unknown | 7/12 | 不适用：Bridge 不发布 unknown |

Bridge 总共采纳16/48条，其中15条正确、1条错误；其余32条不发布模型辅助状态。采纳覆盖率33.3%，已采纳状态正确率93.75%；后者不能代替整体准确率。12条 unknown 全部拒判符合辅助状态机制，不能把拒判一概算作分类错误或正确。

首轮 Handler（含推理、不含网络与加载）P50 55.63ms，P95 102.72ms（nearest-rank）。没有验证完整 HTTP 800ms 超时或生产延迟。

## 关键发现

当前 Bridge 要求状态概率至少0.85；awaitingInput 还要求 needs_reply.noul 至少0.6。

- “请确认范围。”：模型选择 awaitingInput，概率0.967，但 needs_reply 为0.267，Bridge 不采纳。
- “请选择方案 A 或 B。”：awaitingInput 概率0.977，needs_reply 为0.321，Bridge 不采纳。
- “确认后我再继续。”：awaitingInput 概率0.843、needs_reply 0.568，两个门槛均未满足。
- “Compiling, 42% complete. Please wait.”：模型误判 idle，而且被 Bridge 采纳。
- 中英文覆盖文件确认提示 `[y/N]` 均被模型选为 unknown。

因此，Vela 原始分类与产品最终状态不同；本组12条等待输入样本最终均没有产生等待辅助状态。这里只证明当前多头输出及门槛组合的实际表现，不证明 noul 偏低的训练根因，也不能直接推导所有真实会话都不会显示问号。Pi 生命周期与 /v1/question 是独立路径，真实状态优先于辅助模型。

## 回归与限制

产品 Python 协议单元测试通过（详见 protocol-tests.log）。本次未修改产品提示词、阈值或服务逻辑，未进行 UI 验收。没有执行性能优化、调参或用本组结果反复调整提示词。真实 socket、认证、安全拒绝、并发、缓存已有值及原生状态竞态不属于本次模型样本实验覆盖范围。
