# 为 Codex 会话标题失败添加文件诊断日志

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 16:58) |
| Artifacts | [Artifacts](../artifacts/add-codex-title-diagnostic-logs/) |
| Kind | Task |

## Scope

仅为原生 Codex 标题自动生成和手动刷新增加有界、隐私安全的文件诊断，并细分现有响应错误。不改变模型调用参数、成功接纳条件、两次自动尝试预算、会话身份保护、状态或回退逻辑。不运行测试套件，不启动、重启或替换用户的 App、Bridge、Pi、Codex 或 Ollama。

## Plan

1. 在现有 Codex 标题处理边界记录自动、手动及前置条件失败，使用可关联但不含会话内容的安全元数据。
2. 在本地模型服务中保留原有检查，细分错误类别；采用私有目录、跨实例文件锁和有界日志轮转。
3. 执行 Swift 解析、独立日志示例及非启动 Debug 构建，审查本次相对基线的改动与隐私边界，完成必要的独立审查。

## Task Summary

**原生 App**：[iTermate](../../iTermate/) 增加 Codex 自动/手动标题失败的脱敏文件记录器，细分现有模型响应失败，记录主动取消与过期结果丢弃；日志使用私有权限、有界轮转和跨实例文件锁，不改变既有标题生成、身份保护或回退行为。

**工程配置**：[iTermate.xcodeproj](../../iTermate.xcodeproj/) 由既有 XcodeGen 配置重新生成，只为新增诊断 Swift 源文件注册编译引用。

**使用说明**：[docs](../../docs/) 补充 Codex 日志位置、安全字段、轮转、日志不可写时的降级和新版 App 生效边界。

## Target
- [x] T1: Codex 自动生成及手动刷新标题失败时，将可定位原因的诊断记录写入本地日志文件，不依赖界面错误提示。
- [x] T2: 日志不包含对话、模型正文或凭据，记录失败不改变标题生成、会话状态或已有标题回退行为。

## Result

- T1: 自动/手动catch及手动不可用均写文件；已确认TR-1并将超大配置错误改为invalid_configuration。evidence/checks.md和logging-example-round-02.log/file-observations-round-02.json显示九类合成记录；Swift解析及修复后Debug构建5.454秒成功，未运行真实App/测试。
- T2: 最新file-observations-round-02.json：敏感哨兵零出现，0700/0600、轮转完整、跨进程十八条、忙锁10ms返回、symlink目标不变；与基线比较确认参数、接纳、预算和所有权/回退不变；超大配置保持原错误文案与4096拒绝条件。
- Review gate: Passed — fresh只读Reviewer 50037bdf-1315-4815-8414-7a326d4515e4第02轮无Findings并明确TR-1 resolved；报告已保存reviews/round-02.md并索引。主会话实际重算清单全部SHA-256无漂移，覆盖限制保持披露。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 持久化日志的隐私/跨实例文件边界及异步Codex路径仍需fresh复审；TR-1已提供实质修复和新证据。
- Snapshot: sha256:6d7bfc66d9d42875f00a6472c703b37a5bcaa475c0ad7c8df9ae6f485014e885; tasks/artifacts/add-codex-title-diagnostic-logs/evidence/snapshot.json
- Evidence: checks.md更新TR-1、九类日志及轮转/脱敏观察；Swift解析和Debug构建5.454秒通过；未运行真实App或测试。
- Task fingerprint: b1ed145688fe0cfc4d66c00a745061b5a3c846841c753f22f09cd332d8e95751
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/add-codex-title-diagnostic-logs/reviews/round-01.md) | sha256:00e45b14986228b5cdf0335366a2bfdcb5336370797d43c8997376d70ec43f29 | findings: TR-1；主会话复核哈希无漂移 |
| 02 | [第 02 轮](../artifacts/add-codex-title-diagnostic-logs/reviews/round-02.md) | sha256:6d7bfc66d9d42875f00a6472c703b37a5bcaa475c0ad7c8df9ae6f485014e885 | no blocking findings；TR-1 resolved；主会话实际SHA-256复核drift=[] |

## Verification

- Passed: 终验全部快照哈希drift=[]，第02轮报告已保存且TR-1 resolved；Swift parse、diff与Context验证通过，当前内容等于5.454秒成功Debug构建及九类日志观察版本。未运行单元/项目测试或真实App，未安装/启动/重启；真实Codex错误待用户运行新版App采集。
