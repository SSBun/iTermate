# 执行会话标题对比测试并汇报结果

| Field | Value |
| --- | --- |
| Status | Blocked (2026-10-20 18:52) |
| Artifacts | [Artifacts](../artifacts/run-session-title-model-tests/) |
| Kind | Task |

## Target
- [x] T1: 实际执行刚新增的会话标题离线单元测试，记录通过、失败和跳过情况。
- [ ] T2: 在显式远程接口、模型及凭据配置具备时执行远程与本地2B的合成会话对比，报告双方实际标题、耗时与约束结果；缺少配置或服务不可用时如实报告具体阻塞，不将跳过当作比较成功。
- [x] T3: 仅执行本次标题测试，不运行其他测试套件、不修改测试或生产代码、不上传真实会话历史、不切换生产模型。

## Scope

- 仅执行新增标题对比测试文件，保存实际 TAP 输出；只检查显式远程环境变量是否具备及 Ollama 已安装模型列表。
- 不读取远程凭据文件、不猜测账号或模型，不修改代码、配置、模型选择，不运行其他测试套件。

## Decisions

- 用户已明确授权执行本份测试并查看结果。
- 当前 ITERMATE_TITLE_REMOTE_URL、ITERMATE_TITLE_REMOTE_MODEL、ITERMATE_TITLE_REMOTE_API_KEY 均未配置；只记录存在性，不记录凭据值。
- 本机 Ollama 服务可达，已安装 0.8B 和 2B，但缺少远程配置时不能取得真实双模型对比结果。
- 本轮显式关闭 live 门执行离线测试；不把跳过的真实比较或模拟网络耗时当作 LLM 测量结果。

## Plan

1. 已完成离线测试执行与 TAP 计数复核；保留源码内容身份和原始输出。
2. 等待显式远程接口、模型及凭据配置具备后，仅继续真实合成会话对比并报告标题、耗时与约束结果。

## Task Summary

没有修改产品或测试代码；仅保存本轮实际测试日志、执行元数据和远程配置缺口观察。

## Block

- Reason: 离线测试通过，但三个远程配置环境变量均缺失，无法执行真实远程LLM与本地2B标题比较；该测试跳过，不作为比较成功。
- Unblock when: 用户在执行环境中安全配置 ITERMATE_TITLE_REMOTE_URL、ITERMATE_TITLE_REMOTE_MODEL、ITERMATE_TITLE_REMOTE_API_KEY，并明确继续真实比较；仅使用固定合成数据，不在聊天或任务记录中提供密钥值。

## Result

- T1: 实际运行tsx --test --test-reporter=tap仅指定新增文件，退出码0；TAP共9项，通过8、失败0、取消0、跳过1。独立解析计数一致，原始输出evidence/offline-tests.log与run.json，复核evidence/verified-counts.json。
- T3: 仅运行新增测试文件，显式live门=0；测试及生产源文件执行前后SHA-256一致，未修改代码/配置或切换模型，无真实LLM调用或历史上传。远程三个变量存在性均false，本机2B列表查询可用，未运行其他测试套件。
