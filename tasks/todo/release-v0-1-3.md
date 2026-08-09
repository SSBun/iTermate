# 发布 iTermate v0.1.3 并清理旧 Bridge helper

Status: In Progress (2026-08-09 10:20)

## Scope

- 包含：提交除 Pi 会话运行态文件外的当前全部本地修改，将版本更新为 0.1.3、build number 更新为 4，生成并验证 DMG、GitHub Release 与 Sparkle appcast。
- 包含：停止所有旧 iTermate Bridge helper 进程并删除旧 AutoLaunch helper 与残留 socket，不启动或重启 iTermate App。
- 不包含：Developer ID 签名、Apple notarization、Mac App Store 发布或安装新 App；若当前机器仍无相应身份或凭据，远端发布前必须由用户明确接受限制。

## Target

- [ ] T1：除 `.pi-glla/` 会话运行态外，当前全部本地修改进入一个无敏感文件的发布提交，工作区在发布后干净。
- [x] T2：App、CHANGELOG、Xcode 工程、DMG 与 Sparkle appcast 的版本为 0.1.3，build number 为 4。
- [x] T3：完整测试、Release 构建、DMG 可读性、SHA-256、Sparkle EdDSA 签名与 codesign 检查通过，签名和 notarization 状态被准确记录。
- [x] T4：旧 Bridge helper 进程、AutoLaunch helper 文件与残留 socket 均已清理，iTermate App 与 iTerm 未被 Agent 重启。
- [ ] T5：经用户确认完整远端动作后，`v0.1.3`、公开 GitHub Release、`origin/main` 与公开 Sparkle appcast 指向并描述同一已验证发布版本。

## Plan

1. 检查 staged diff 与敏感文件，创建发布提交并提交完整远端动作确认门。
2. 用户确认后按 tag、Release 资产验证、main/appcast 的安全顺序发布并复核公开结果。

## Result

- T2：`project.yml` 已更新为 0.1.3（build 4）并通过 XcodeGen 同步工程；Release App、挂载后的 DMG App、CHANGELOG 与 `docs/appcast.xml` 均与该版本一致。
- T3：Bridge compile/self-test 和完整 Xcode 测试通过，40/40 tests、0 failures；Release arm64 构建与 DMG 只读挂载、`hdiutil verify`、资源哈希及深度 codesign 检查通过。最终 DMG 为 3,640,656 bytes，SHA-256 为 `a1e54a4d9948a3b6672908f5fb3187d042ac9eb9e5df6163479bcd0a3dc677e2`；Sparkle Keychain 公钥与 App 一致，EdDSA 归档签名和 appcast metadata 验证通过。App 为 ad hoc 签名、无 Team ID，未 notarized；本机 Gatekeeper 安全策略已关闭，因此 `spctl` 接受结果不能证明公开分发信任。
- T4：已停止唯一运行中的旧 Bridge Python 进程及其 iTerm wrapper，删除 AutoLaunch `iTermateBridge.py` 和 `bridge.sock`；等待后复核 helper 进程为 0，iTermate App PID 82801 与 iTerm PID 57881 保持不变。
- Review gate: Skipped — no explicit user request.
