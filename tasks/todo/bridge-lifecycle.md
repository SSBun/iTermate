# 绑定 Bridge 与 iTermate 生命周期

Status: Completed (2026-07-31 17:16)

## Scope

- 包含：iTermate 启动或重启时停止旧 Bridge，并用当前 App bundle 中的 Bridge 资源启动新实例。
- 包含：保持现有 iTerm2 终端会话不受影响，并让 App 重新连接新 Bridge。
- 包含：iTermate 保持运行时，iTerm2 重启后替换失效 Bridge 并丢弃旧 Session 快照。
- 不包含：由 iTermate 主动重启 iTerm2 主进程或改变 iTerm2 AutoLaunch 的其他脚本。

## Target

- [x] T1：重启 iTermate 后，旧 Bridge 不再继续持有 socket 和内存状态，新 Bridge 能被启动并连接。
- [x] T2：重启 Bridge 不会关闭或重建 iTerm2 的终端会话。
- [x] T3：Bridge 生命周期控制经过单元测试、构建和真实 Socket 握手验证。
- [x] T4：iTermate 保持运行并重启 iTerm2 后，旧 Session 自动消失，面板恢复展示新实例的当前 Session。
- [x] T5：Bridge 不可用或尚未返回当前快照时，面板不继续展示上一次连接的 Session。

## Plan

1. 让 App 识别已无法发布当前快照的 Bridge，并在 iTerm2 可用时替换它。
2. 在连接失效或新连接尚未提供当前快照时移除旧 Session 展示。
3. 增加最小回归检查，并验证 iTerm2 重启后的真实恢复路径。

## Result

- T1：`ItermBridgeClient.start()` 安装 bundle 内 Bridge 后，先终止 socket 所属旧进程，再通过 iTerm2 `it2run` 启动新实例；App 退出时调用 `stop()`。实测 App 重启后旧 Bridge PID 结束，新 Bridge PID 为 72385，Socket 握手返回协议/Bridge v6。
- T2：重启过程中 iTerm2 主进程未被终止，Bridge 重启前后终端 Session 仍可读取；现场快照包含 15 个 Session。
- T3：`swiftc -parse`、`python3 -m py_compile`、Bridge `--self-test`、`git diff --check` 和 Xcode 测试 32/32 通过；安装 Bridge 与源码一致。
- T4：Bridge 现在监听 iTerm2 WebSocket 关闭并立即退出，释放旧 socket 与进程锁，让既有 iTermate 重连路径启动新 Bridge；Bridge self-test 覆盖断连退出，构建产物内资源哈希与源码一致。
- T5：Store 在 Bridge 进入 connecting/disconnected 时清空窗口快照；新增回归测试验证旧窗口被清除，重连后可接受从序号 1 开始的新快照。
- 验证：Python 编译与 self-test、Swift 解析、`git diff --check` 通过；聚焦 Xcode 测试 8/8、完整测试 35/35 通过。
- Review gate: Skipped — no explicit user request.
