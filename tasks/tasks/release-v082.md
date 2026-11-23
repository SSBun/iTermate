# 提交全部本地改动并发布 iTermate 补丁版

| Field | Value |
| --- | --- |
| Status | In Progress (2026-11-23 10:52) |
| Kind | Task |

## Target

- [ ] T1: 全部本地改动纳入 Git 提交
- [ ] T2: 新补丁版的 GitHub Release 和 Sparkle 更新源公开并核验

## Execution Log

### 001 — 本地发布准备

0.8.2（build 17）包含会话快捷切换、项目新标签页和面板提示改动。全部原本地工作区改动纳入 455c596，已有本地提交 2dbe4f8 同属发布范围。Release 构建、DMG 完整性、只读挂载、arm64、嵌套代码签名、SHA-256、App 公钥 EdDSA 验签及 Sparkle XML 核对通过，保留原有 14 个条目。DMG 4,987,791 字节，SHA-256 为 `2c25f656f6312226313ff18862c123a02f5173552936c110c8531f93683676a6`。ad hoc 签名，未经公证，未运行测试套件或实际客户端升级。待确认对公开仓库 SSBun/iTermate 的具体发布动作，之后先推标签，再发布并独立下载校验资产，最后推 main 并验证公开 feed。
