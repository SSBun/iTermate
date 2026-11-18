# 提交全部本地改动并发布补丁版本

| Field | Value |
| --- | --- |
| Status | In Progress (2026-11-18 15:49) |
| Artifacts | [Artifacts](../artifacts/release-fix-local-changes/) |
| Kind | Task |

## Target

- [ ] T1: 全部本地项目改动已提交至 Git
- [ ] T2: 新补丁版本已发布且发布产物可核验

## Plan

1. 核对全部本地改动与敏感内容，更新 0.8.1/build16 版本和发布说明。
2. 使用现有脚本构建、校验并签署 DMG，提交全部改动。
3. 先推标签与发布资产，独立下载核验后推 main 更新 feed。
4. 核对公开 Release、标签及 appcast，记录验证与限制。

## Execution Log

### 001 — 发布范围与版本确定

当前稳定版本为 0.8.0/build15；按用户要求发布补丁 0.8.1/build16。远端为公开 SSBun/iTermate，认证账号 SSBun，Pages 来源 main/docs；本地 main 比 origin/main 多三提交，没有落后。全部本地改动含 AI 提供商、模型选择、Keychain 代理修复、文档、记忆及已有任务证据。沿用 ad hoc 未公证限制，不运行测试套件或真实模型请求，不安装或启动 App。

### 002 — 本地产物完成

0.8.1/build16 Release 构建、严格 tsc noEmit、git diff --check、DMG verify、只读挂载、包内版本与资源逐字节对照、deep strict codesign 均通过。首次构建被工具超时中断，改用后台执行现有脚本后成功；首次类型检查配置不符当前编译器，改用 ESNext/Bundler 后通过，未修改产品代码。DMG 4,960,592 字节，SHA256 为 26a12cbd8e44a384b887a0661e55bd2e6dca0f0a3abbd30f322a2ffa317baf58。由既有 Keychain 账号 SSBun.iTermate 生成 appcast，保留全部历史条目，Sparkle 与 App 内公钥 OpenSSL 双重验签通过。敏感模式扫描唯一命中为任务名称中的 task-target 字符串，已确认不是凭据。证据见 evidence/local-release.json、release-build.log 与 typecheck.log。

## Task Summary

**发布版本**（[项目配置](../../project.yml)）：将版本递增为 0.8.1/build16，同步生成 Xcode 工程。

**发布说明与更新源**（[文档](../../docs/)）：补充补丁版更新说明，为已校验 DMG 生成 Sparkle 更新条目；本次提交包含用户要求的全部既有本地修改。
