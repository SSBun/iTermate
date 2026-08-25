# 升级 Ghostty 至官方 tip

Status: Completed (2026-08-25 13:38)
Kind: Task

## Scope

- 包含：验证官方 Ghostty tip、终止当前 Ghostty、保留 1.3.1 App 备份、安装并重新启动 tip，以及验证签名、公证、版本与实时 AppleScript `tty` 能力。
- 排除：修改 Ghostty 用户配置、修改或自行构建 Ghostty 源码。

## Target
- [x] T1: /Applications/Ghostty.app 被升级为官方签名并公证、且公开 AppleScript tty 的 Ghostty tip 构建。
- [x] T2: 原 Ghostty 1.3.1 App 保留可回滚备份，现有 Ghostty 用户配置不被修改。
- [x] T3: 经用户授权，当前 Ghostty 被终止并在升级后重新启动；新的运行实例能返回每个 Terminal 的 `tty`，且用户接受原终端会话可能被关闭。

## Plan

1. 验证下载的官方 tip 产物、发布摘要、签名、公证和 AppleScript `tty` 能力。
2. 在替换前准备好可回滚备份与已验证安装源，再终止当前 Ghostty。
3. 原子替换为 tip App，不接触用户配置，然后重新启动 Ghostty。
4. 对安装位置和运行实例重新验证版本、签名、公证与每个 Terminal 的 `tty`。

## Result

- T1: 已安装官方 tip main 8867c37c5（build 17505）；发布 SHA-256 匹配，codesign --deep --strict 与 spctl notarized Developer ID 验证通过，安装包 SDEF 含 tty。
- T2: 1.3.1 build 15212 已备份为 ZIP（SHA-256 82ba8d2e82c8ffebac2720f1a6b93cf7a3d09617f874d1b717e59c575c8aef65），解压后版本与签名验证通过；~/.config/ghostty 在升级前后均不存在，未修改用户配置。
- T3: 按用户明确授权终止旧 PID 40830 并启动新 PID 89990；运行中 AppleScript 返回 Terminal 1557E24E-DA12-48B4-8D0D-18D9CC0A41E7 的 /dev/ttys018。
- Review gate: Skipped — 用户未要求独立 Reviewer 或对抗式审查。

## Verification

- Passed: 重新验证备份可解压回 1.3.1 build 15212、旧版与新版签名有效、新版 Gatekeeper 接受、无 staging 残留，且运行实例返回真实 tty。
