# 启动iTermate时自动启动本地Ollama服务

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 11:45) |
| Artifacts | [Artifacts](../artifacts/auto-start-ollama-on-launch/) |
| Kind | Task |

## Scope

实现应用启动与手动检查时按需启动已安装的本地 Ollama，复用现有服务，不下载安装运行时或模型，不停止共享服务。不修改现有模型身份校验，不启动或重启当前 iTermate／Bridge，不覆盖用户安装副本。

## Plan

1. 在当前模型检查入口补齐回环探测、按需启动、有界等待与具体错误提示。
2. 同步当前使用文档和相关 Context，构建并直接观察生产服务入口；不运行单元测试或项目测试套件。
3. 自查实际范围，完成独立只读复审和最终校验。

## Task Summary

**本地模型服务**：位于 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/)，模型检查现在会在连接被拒绝时启动已安装的 Ollama，固定回环监听并等待就绪，再验证库存和预热；复用现有服务，取消检查和退出不终止服务，失败显示具体原因，设置说明同步更新。

**本地模型使用文档**：位于 ["/Users/caishilin/Desktop/personal/iTermate/docs/"](file:///Users/caishilin/Desktop/personal/iTermate/docs/)，当前启用方式改为自动启动已安装运行时，并说明查找范围、失败行为及不自动安装下载的边界。

## Target
- [x] T1: iTermate启动时自动确保本地Ollama服务可用，已有服务则直接复用
- [x] T2: 启动失败清楚提示且不阻塞应用，不终止其他客户端共享的Ollama服务

## Result

- T1: 应用启动已有AppDelegate.applicationDidFinishLaunching→localModel.refresh入口。Debug完整构建成功；直接编译当前LocalModelService与CodexTitleDiagnostics调用refresh：起始11434连接失败，首次refresh自动启动Ollama PID28444并预热2B，第二次refresh仍Available。服务仅监听127.0.0.1:11434；/api/tags确认2B digest为支持的dfaf2605…，先前磁盘清单hash不代表API digest。证据：../artifacts/auto-start-ollama-on-launch/evidence/startup-observation.log及debug-build.log；未重启当前GUI。
- T2: 生产入口实际调用service.stop后观察CLI退出，Ollama PID28444仍监听；iTermate PID4801和Bridge PID4831未变。源码只对cannotConnectToHost启动进程，其他错误直接显示；缺少可执行文件、启动失败、提前退出和有界等待分别报错；异步URLSession与Task.sleep不阻塞事件循环，退出路径不terminate/kill共享服务。不运行单元测试；失败分支和多实例抢占路径仅源码检查，未模拟故障；真实GUI启动与设置视觉由用户自行运行新构建验证。
- Review gate: Passed — fresh-context reviewer独立只读一轮，round-01无confirmed finding及Target-blocking risk；owner已读取注册报告并check-evidence确认8文件快照及报告digest未变。故障注入和GUI视觉未做的限制保持披露。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 新增外部常驻服务的自动启动与取消边界，涉及进程生命周期、回环绑定及共享服务复用，需独立复审
- Snapshot: snapshot:tasks/artifacts/auto-start-ollama-on-launch/evidence/415e8178e80d9e7bca90762859cdc629cd32c8442e245e86a1cbd7c39718c570.json#415e8178e80d9e7bca90762859cdc629cd32c8442e245e86a1cbd7c39718c570
- Evidence: T1/T2实际入口启动预热与取消后持续监听观察、完整Debug构建及范围化源码自查；故障分支未注入、未运行单元测试、未启动GUI
- Task fingerprint: 86a7dc5c9353c268f3d623c9f22c5a6f4f500ced751df4f7fca7261e93b90188

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/auto-start-ollama-on-launch/reviews/round-01.md) | snapshot:tasks/artifacts/auto-start-ollama-on-launch/evidence/415e8178e80d9e7bca90762859cdc629cd32c8442e245e86a1cbd7c39718c570.json#415e8178e80d9e7bca90762859cdc629cd32c8442e245e86a1cbd7c39718c570 | no blocking findings | 662e43e959cfc56671a6cab856e4a2ba0df52347fa4efeaf4be6c625f796bbd5 |

## Verification

- Passed: 复审后check-evidence再次确认快照和round-01报告有效，git diff --check通过；实际/api/ps显示qwen3.5:2b已加载，Ollama PID28444仍仅监听127.0.0.1:11434，原iTermate PID4801与Bridge PID4831不变。完整Debug构建及两次生产refresh观测见T1/T2；未运行单元测试、未注入故障、未重启或视觉验收GUI。
