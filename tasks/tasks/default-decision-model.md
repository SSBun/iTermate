# 固定默认 Decision 模型并移除名称输入

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-13 11:25) |
| Artifacts | [Artifacts](../artifacts/default-decision-model/) |
| Kind | Task |

## Target
- [x] T1: Decision 调用默认使用 gpt-6-luna，用户无需填写模型名称
- [x] T2: 设置页不再提供 Decision 模型名称输入，保留密钥和测试入口

## Plan

1. 将 App 与 Pi 的 Decision 请求统一为内置模型，并保留旧配置结构。
2. 移除模型输入，更新说明并完成静态验证。

## Execution Log

### 001 — 内置模型与界面调整

按前文将用户输入的 gtt-6-luna 解释为 gpt-6-luna。App 固定示例请求和 Pi 实际判断均使用内置常量，旧配置的空值或自定义名称不再参与请求；保留序列化字段以兼容已有读写结构。设置页以只读模型行替代输入框，密钥和测试入口保留。现有工作区有其他任务改动，本任务未提交或替换安装态。

### 002 — 静态验证

swiftc -frontend -parse 对两个修改的 Swift 文件成功；使用已有 tsconfig 的 tsc --project 严格 noEmit 检查成功；git diff --check 成功。静态核对两处请求模型、调用方、只读显示与文档一致。未运行测试套件、GUI 或真实 API 请求。

## Task Summary

**AI 设置与请求服务**（[iTermate](../../iTermate/)）：内置 gpt-6-luna，设置页只读显示模型，移除名称输入与空名称阻断。

**Pi 集成**（[integrations/pi](../../integrations/pi/)）：实际 Decision 判断固定使用同一模型，并保留旧配置结构。

**使用文档**（[docs](../../docs/)）：说明无需填写模型，以及旧模型字段不再影响请求。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | S | 两端各使用常量，复用已有请求和原生只读控件，无新依赖 | 保留已有序列化字段维持兼容 |
| 稳定性 | A | Swift 语法、TypeScript 严格检查通过；请求端点、认证、解析与取消逻辑未变 | 未做 GUI、完整构建或真实 API 验证 |
| 完整性 | S | 两端请求与设置入口均核对，文档同步；旧空值不阻断请求 | 安装态未更新，属于源码交付 |

## Result

- T1: App 与 Pi Decision 请求均直接使用 gpt-6-luna 常量；旧配置空值及自定义名称不参与请求。Swift parse 和 tsc strict noEmit 均通过。
- T2: 设置页以 LabeledContent 只读显示内置模型，原密钥保存及两类测试菜单保留；源码对照与 Swift parse 通过。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 范围限于内置模型常量与设置展示，保留请求协议及旧配置结构。
- Snapshot: snapshot:tasks/artifacts/default-decision-model/evidence/28f62c39a00a1b007c527695d232e6136c7a275412470898b957e4bedf496b58.json#28f62c39a00a1b007c527695d232e6136c7a275412470898b957e4bedf496b58
- Evidence: Execution Log 002；两端请求和调用方静态核对。
- Result clarity: 模型确定为前文 gpt-6-luna，用户无需模型输入。
- Bounded impact: 仅改变 Decision 模型选择与对应界面，不改变路由、认证和响应处理。
- Low risk: 可逆配置默认值及界面调整，无新增外发或密钥访问；保留旧字段。
- Sufficient verification: swiftc parse、tsc strict noEmit、git diff --check 成功；未运行套件、真实API或GUI。
- Task fingerprint: a16bb9277bb336c11e53bc77dd680d8240b82cf67cbe91b4c1bf866be32481fd

## Verification

- Passed: 最终四文件快照与当前内容一致；静态核对请求常量、只读展示及调用方一致，语法与严格类型检查成功。
