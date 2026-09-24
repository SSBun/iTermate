# 集成 Laya-MLX Session 状态判断与设置页

| Field | Value |
| --- | --- |
| Status | In Progress (2026-09-22 16:55) |
| Artifacts | [Artifacts](../artifacts/integrate-laya-session-decisions/) |
| Kind | Task |

## Target
- [x] T1: iTermate 集成本地 Laya-MLX；启用且模型可用时，由模型优先分类最后一条助手消息是否需要用户回复，不先由正则决定；模型关闭、异常或无法可靠判断时回退既有识别，明确的Agent生命周期事件仍优先，结果接入Session显示。
- [x] T2: 新增独立设置标签页，提供模型下载、进度与错误提示、服务启停及状态查看；App 不分发模型权重。
- [x] T3: 提供仅监听本机的公共 HTTP API、文档与示例，供其他 Agent 和客户端调用。
- [x] T4: 未下载、关闭或服务异常时保留现有状态识别；消息不离开本机，模型不覆盖明确生命周期事件，不擅自重启运行中的 App。

## Plan

1. 核对状态来源和最后消息来源，保留已有生命周期权威及未提交修改。
2. 增加隔离运行时准备、按需下载及本机服务管理，补充公共 API 文档。
3. 接入 Session 辅助判断与独立设置页，明确不支持获取正文的数据源边界。
4. 编译、静态检查与隔离服务验证，不运行项目测试或现有 App；记录未能观察的 UI 行为。
5. 对实际变更执行 R2 独立只读审查，修复发现后复核。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [基础设施失败](../artifacts/integrate-laya-session-decisions/reviews/round-01.md) | evidence/snapshot-01.json | incomplete：后台 runner 缺失，没有审查结果 |
| 02 | [独立审查](../artifacts/integrate-laya-session-decisions/reviews/round-02.md) | evidence/snapshot-01.json | findings：TR-1；阻断验收的 UI/Session 证据缺口登记为 TR-2 |

## Review
- Schema: task-review-ledger/v1
- Pass: 1
- Next finding: 3
- `TR-1` | no-progress=0 | LocalModelService.swift 与 iTermate-laya.py | 已补充独占锁下的启动清理并完成SIGKILL/双实例隔离观测，见snapshot-02及recovery-observations.json；修复待下一轮独立复核。
- `TR-2` | no-progress=0 | T1/T2 端到端验收 | 补充设置操作、取消与重试、真实 Session 显示的用户验收证据；不可擅自启动或重启 App。

## Result

- T4: TR-1已由主Agent修复：helper取得独占锁后、模型加载前清理遗留许可/endpoint；App启动即便服务关闭也仅在获得相同锁后清理废弃许可。隔离真实服务验证SIGKILL遗留、替换服务ready前清理、第二实例不能清理活跃所有者标记，见recovery-observations.json；新Debug构建与diff检查通过，快照snapshot-02。修复尚待独立复核，未运行项目测试或用户App。
- T2: 依用户补充，安装状态已与Service状态独立：Not installed/Installing/Installed/Installation failed；显示准备Python、安装依赖、下载阶段、取消与错误。启动及页面打开检查安装记录、模型ID、关键非空模型文件、Python与Laya包文件，不仅检查model.json存在。服务停止不改变安装状态。snapshot-03为当前版本，Debug构建及diff检查通过。此前真实设置AX与文件校验证明下载已成功；新状态布局、取消/重试及启停仍待用户新构建验收；未重启App或运行项目测试。
- T3: 公共API文档和标准库调用示例已提供；依用户最新要求添加Copy Agent Connection Prompt按钮，在用户点击且服务ready时读取真实Token并填入当前真实loopback地址，明确显示含凭据警告和复制成功反馈；地址变化重置反馈。真实凭据只写入用户剪贴板，不写源码/文件/日志。XcodeGen生成与Debug构建通过；bundle内模板与源码一致，用虚拟Token验证占位符替换和Python AST通过，未读取真实Token或操作用户剪贴板。当前快照snapshot-04；真实按钮点击仍待用户验收及独立复核。
- T1: 维持模型优先三态判定、生命周期代次保护及关闭回退。用户截图的简短确认句已向实际本机API复现：全文与末段均为unknown，故按设计回退；旧正则缺少简短行动确认句导致漏检，已新增按这个范围实现可以吗/这样修改可以吗等受限兜底，保留代码/引用/示例/否定过滤。磁盘已安装扩展仍旧版，未覆盖用户安装态。当前snapshot-06；两份TS语法、Debug构建与diff检查通过；新增回归用例未运行。完整端到端问号显示仍需用户构建运行App并重载Pi后观察，证据见short-confirmation-observations.json。
- Review gate: Required — 第一轮基础设施失败不算审查；重载后新建fresh只读Reviewer。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 新增本机服务、下载和异步状态判定；工具重载后通过原协议重试独立审查。
- Snapshot: evidence/snapshot-01.json sha256:0e06ab7620a33182d0ef62321d11d74a0bff7d2d534c416ccd95685ce0cf025e；10个交付文件无漂移。
- Evidence: Result T1–T4 与 service-observations.json；重载后逐文件核对 SHA256 与上次成功构建/隔离验证版本一致；未运行项目测试或真实App。
- Task fingerprint: 4644558a73266fb541535b4ab753acc1353b689d51d6167d2a1a653c0c606a01
