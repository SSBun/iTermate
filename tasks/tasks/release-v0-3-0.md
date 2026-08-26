# 发布 iTermate v0.3.0

Status: Cancelled (2026-08-25 15:54)
Kind: Task
Parent: commit-and-release-v0-3-0

## Scope

- 包含 v0.3.0 的版本与构建号更新、发布说明、macOS 分发产物、Git tag、GitHub Release 与 Sparkle appcast。
- 不启动或重启 iTermate、Bridge 或用户终端；安装验证在隔离位置完成。
- 远端 tag、Release、资产与 appcast 的变更须在本地准备完成后再次取得具体操作确认。

## Target

- [ ] T1: iTermate 项目版本提升至 0.3.0，并生成准确覆盖本次 Ghostty 功能的发布说明。
- [ ] T2: macOS 发布产物按项目既有流程完成构建、签名、公证能力检查和安装验证。
- [ ] T3: GitHub Release 与 Sparkle appcast 成功发布并通过公开 HTTPS 复核。
- [ ] T4: 发布后的版本、Git tag、远端资产、更新元数据和本地 Git 状态保持一致。

## Plan

1. 核对版本来源、既有发布入口、远端状态、签名、公证和 Sparkle 凭据能力。
2. 更新版本、构建号和发布说明，并重新生成派生工程。
3. 运行已授权测试，构建并验证 Release 产物、分发镜像、签名、公证准备度、隔离安装与 appcast。
4. 准备本地发布提交与 tag，展示全部远端变更及其顺序并等待明确确认。
5. 按安全顺序发布 tag、Release 资产和 appcast，再从公开 HTTPS 独立复核并收敛本地 Git 状态。
