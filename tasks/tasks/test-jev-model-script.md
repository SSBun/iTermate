# 编写 Jev 模型调用验证脚本

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-22 14:10) |
| Kind | Task |

## Target
- [x] T1: 提供可运行的 Jev API 验证脚本，使用现有凭据提交示例选择题并显示响应或明确错误，不将密钥写入代码或输出。

## Result

- T1: 已新增 scripts/test-jev.py：环境变量优先、钥匙串回退，固定 HTTPS 官方端点且拒绝重定向；提供 choice 示例、响应与耗时输出及 HTTP/网络错误处理。AST、--help、--dry-run 与官方 OpenAPI 必填字段核对通过；未读取真实密钥或发起推理，未运行项目测试，账户权限和真实响应尚未验证。
- Review gate: Skipped — R1 独立示例脚本，影响与凭据发送范围固定；完成离线检查和官方格式核对，无独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 独立手动运行的标准库 API 示例，不接入应用；按用户确认范围仅离线交付。
- Snapshot: scripts/test-jev.py sha256:a3122dd8d4af7cdd270bc526feb26d4c59bdd2e21991b9c84a738d1213008c39
- Evidence: AST、帮助与 dry-run 成功；请求结构对照官方 OpenAPI；手工检查凭据仅用于固定端点 Authorization、禁止重定向、响应脱敏、不自动重试。
- Result clarity: 目标为可运行的选择题调用示例，不宣称账户或模型在线验证成功。
- Bounded impact: 单个独立脚本，无应用调用方，无配置写入，无额外依赖。
- Low risk: 仅用户主动运行时向固定官方 HTTPS 地址发送合成示例；不接受自定义地址，不转发重定向，不保存密钥，不自动重试；本次没有远程推理或费用。
- Sufficient verification: 已运行语法与离线 CLI 检查并核对官方请求字段；认证、错误与脱敏路径已静态检查；真实推理按已确认边界不执行。
- Task fingerprint: 7bc65a234e1d5013bfc0c56349bb35fe5962cab11a34990d9b796eb8a98eda3d

## Verification

- Passed: 最终文件 SHA256 与评估一致；AST、--help、--dry-run、OpenAPI 字段核对及 git diff --check 通过。按确认范围未发起真实推理，未运行项目测试；既有 integration 改动未触及。
