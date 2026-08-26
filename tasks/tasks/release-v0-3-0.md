# 发布 iTermate v0.3.0

Status: In Progress (2026-08-26 11:22)
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

## Progress

- 用户已确认真实运行验收：Ghostty Session 操作不再误报未运行，`sleep 5` 状态从运行变为成功，Pi 在 `/reload` 后依次显示空闲、运行和完成。
- 已授权测试通过：XCTest 53/53；Bridge self-test、Python 编译及 zsh/Bash 语法检查通过。当前环境无 fish CLI，因此未执行 fish 解析检查。
- 最终 arm64 Release DMG 已重建：`dist/iTermate-0.3.0_20260826-112540/iTermate-0.3.0.dmg`，3,857,020 bytes，SHA-256 `39fe79ae52fc19d9cdf6b2559c45d275d6beeaa48e69d5e9b9ac14e9a2bb862c`。
- App 与隔离安装验证通过：版本 0.3.0、build 9、arm64、资源与 Sparkle.framework 齐全，深度 codesign 验证通过，无 `get-task-allow`；未启动或重启 iTermate、Bridge 或终端，既有进程 PID 保持不变。
- 当前产物为 ad hoc 签名；本机没有 Developer ID Application identity 与 notarytool profile，因此未进行 Apple notarization。
- Sparkle v0.3.0/build 9 appcast 条目已生成；归档长度、下载 URL、EdDSA 签名及 bundle 公钥匹配验证通过。Sparkle 依赖仍为 2.9.4。
- 待完成：提交本地发布准备，并在展示具体 tag、资产、校验和、签名限制和远端命令后取得发布确认。
