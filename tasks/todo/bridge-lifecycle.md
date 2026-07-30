# 绑定 Bridge 与 iTermate 生命周期

Status (2026-07-30 11:09): Completed

## Scope

- 包含：iTermate 启动或重启时停止旧 Bridge，并用当前 App bundle 中的 Bridge 资源启动新实例。
- 包含：保持现有 iTerm2 终端会话不受影响，并让 App 重新连接新 Bridge。
- 不包含：重启 iTerm2 主进程或改变 iTerm2 AutoLaunch 的其他脚本。

## Target

- [x] T1：重启 iTermate 后，旧 Bridge 不再继续持有 socket 和内存状态，新 Bridge 能被启动并连接。
- [x] T2：重启 Bridge 不会关闭或重建 iTerm2 的终端会话。
- [x] T3：Bridge 生命周期控制经过单元测试、构建和真实 Socket 握手验证。

## Plan

1. 在 App 启动连接前终止当前 socket 所属的 Bridge，并启动已安装的 Bridge 资源。
2. 保持断线重连只负责恢复连接，不重复重启 Bridge。
3. 增加最小生命周期控制检查，重建并验证 App、Bridge 与 iTerm2 会话。

## Result

- T1：`ItermBridgeClient.start()` 安装 bundle 内 Bridge 后，先终止 socket 所属旧进程，再通过 iTerm2 `it2run` 启动新实例；App 退出时调用 `stop()`。实测 App 重启后旧 Bridge PID 结束，新 Bridge PID 为 72385，Socket 握手返回协议/Bridge v6。
- T2：重启过程中 iTerm2 主进程未被终止，Bridge 重启前后终端 Session 仍可读取；现场快照包含 15 个 Session。
- T3：`swiftc -parse`、`python3 -m py_compile`、Bridge `--self-test`、`git diff --check` 和 Xcode 测试 32/32 通过；安装 Bridge 与源码一致。
- Review gate: Skipped — no explicit user request.
