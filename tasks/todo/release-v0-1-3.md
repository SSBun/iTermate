# 发布 iTermate v0.1.3 并清理旧 Bridge helper

Status: Completed (2026-08-09 10:36)

## Scope

- 包含：提交除 Pi 会话运行态文件外的当前全部本地修改，将版本更新为 0.1.3、build number 更新为 4，生成并验证 DMG、GitHub Release 与 Sparkle appcast。
- 包含：停止所有旧 iTermate Bridge helper 进程并删除旧 AutoLaunch helper 与残留 socket，不启动或重启 iTermate App。
- 不包含：Developer ID 签名、Apple notarization、Mac App Store 发布或安装新 App；若当前机器仍无相应身份或凭据，远端发布前必须由用户明确接受限制。

## Target

- [x] T1：除 `.pi-glla/` 会话运行态外，当前全部本地修改进入一个无敏感文件的发布提交，工作区在发布后干净。
- [x] T2：App、CHANGELOG、Xcode 工程、DMG 与 Sparkle appcast 的版本为 0.1.3，build number 为 4。
- [x] T3：完整测试、Release 构建、DMG 可读性、SHA-256、Sparkle EdDSA 签名与 codesign 检查通过，签名和 notarization 状态被准确记录。
- [x] T4：旧 Bridge helper 进程、AutoLaunch helper 文件与残留 socket 均已清理，iTermate App 与 iTerm 未被 Agent 重启。
- [x] T5：经用户确认完整远端动作后，`v0.1.3`、公开 GitHub Release、`origin/main` 与公开 Sparkle appcast 指向并描述同一已验证发布版本。

## Result

- T1：发布提交 `b32479453a4dc304aa24b5be2aefb5eb49c50cd7` 包含 21 个本地变更文件；`.pi-glla/` 会话运行态已加入忽略规则，staged diff check 与敏感内容扫描通过，发布提交后工作区干净。
- T2：`project.yml` 已更新为 0.1.3（build 4）并通过 XcodeGen 同步工程；Release App、挂载后的 DMG App、CHANGELOG 与 `docs/appcast.xml` 均与该版本一致。
- T3：Bridge compile/self-test 和完整 Xcode 测试通过，40/40 tests、0 failures；Release arm64 构建与 DMG 只读挂载、`hdiutil verify`、资源哈希及深度 codesign 检查通过。最终 DMG 为 3,640,656 bytes，SHA-256 为 `a1e54a4d9948a3b6672908f5fb3187d042ac9eb9e5df6163479bcd0a3dc677e2`；Sparkle Keychain 公钥与 App 一致，EdDSA 归档签名和 appcast metadata 验证通过。App 为 ad hoc 签名、无 Team ID，未 notarized；本机 Gatekeeper 安全策略已关闭，因此 `spctl` 接受结果不能证明公开分发信任。
- T4：最终清理已停止旧 Bridge Python 进程及其 iTerm wrapper，删除 AutoLaunch `iTermateBridge.py` 和 `bridge.sock`；等待 5 秒后复核 helper 进程为 0，当前 iTermate App PID 95246 与 iTerm PID 57881 在清理期间保持不变，Agent 未启动或重启二者。
- T5：用户明确确认并接受 ad hoc、未 notarized 限制后，annotated `v0.1.3` 与稳定公开 GitHub Release 均指向 `b32479453a4dc304aa24b5be2aefb5eb49c50cd7`。隔离下载的 DMG 与 checksum 逐字节匹配本地产物，SHA-256、`hdiutil verify`、HTTP 200 与 EdDSA 签名复核通过；资产验证后才推送 `main`。公开 appcast 已返回 0.1.3（build 4）、macOS 13.0、arm64、3,640,656 bytes、最终 Release URL，仓库与公开文件 SHA-256 均为 `c2219450d993dca913592f6a40d34d91ec5849ff44be0b0de5cf5f01096bbf62`。
- Review gate: Skipped — no explicit user request.
