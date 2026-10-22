# Codex 标题文件日志自检

## 要求与边界

用户纠正：“These sessions are type of codex”；随后明确要求：“I cannot see the error message, you should record it to log files”。主会话展示自动生成和手动刷新均记录具体错误、不记录对话/模型正文/凭据、不改变标题及会话行为、不自动重启应用、不运行测试的 Target，用户回复 yes。

## T1：可读取的文件诊断

- 比较 evidence/before/ItermBridge.swift 与当前源码：自动和手动共用的模型调用 catch 在界面反馈之前调用文件记录器，不再受 reportsFailure 控制；手动刷新前置条件不足也写 session_unavailable。记录请求 UUID、来源、Codex PID 与尝试次数，足以关联同一请求，不写终端 ID、TTY 或路径。
- 模型调用及其库存读取保留原成功条件，拆分既有 guard 为 typed reasons：未完成、模型不符、length 截断、其他结束原因、message 缺失、thinking、content 类型、空标题、模型变化、HTTP 状态、重定向、大小、JSON。未知错误仅记数值码，不直接存 localizedDescription 或 userInfo。
- 成功响应未通过原会话身份/状态检查时记录信息级 result_discarded；主动取消独立为 cancellation/info，不算模型故障。没有更改原检查条件。
- 独立编译并运行 logging-example.swift，直接调用生产记录器，以临时目录接收合成错误。logging-example-round-02.log 和 file-observations-round-02.json 为最新修复后观察；无后缀文件保留首次检查。九条记录可 JSON 解析，区分自动/手动及失败/取消/结果丢弃。真实默认位置为用户 Library/Logs/iTermate/codex-titles.log，可由既有 About 入口打开。

## T2：隐私、文件与行为保护

- 示例给网络及未知 NSError 注入 PRIVATE_PROMPT_SENTINEL、PRIVATE_TITLE_SENTINEL、PRIVATE_DOMAIN_SENTINEL、PRIVATE_URL_SENTINEL；实际日志无这些原始字符串。生产写入参数只来自闭合原因枚举、固定事件/等级和数值/随机 UUID。
- file-observations-round-02.json：目录 0700、当前文件 0600；预置超过阈值的合成 JSONL 后原文件完整成为 previous，当前文件只含本轮九条记录。第二个进程追加后当前共十八条，保留一对日志和零字节稳定锁。该示例没有改动用户真实日志目录。
- 文件锁被占用时记录器放弃该条写入，最新示例在约十毫秒返回且文件未变；不会等待另一 App 实例阻塞主线程。日志路径是符号链接时目标内容未变、链接保留。源码还拒绝非普通文件、非当前用户文件和硬链接；用 NOFOLLOW 和受限权限创建文件。I/O 或序列化错误被局部捕获，不能改变模型请求/会话处理结果。
- 对比基线确认提示词、num_predict/超时/模型参数、原有 HTTP/响应/库存检查条件、自动两次预算、手动覆盖、终端/进程/摘录/请求所有权保护和失败标题回退均未改动。只细化错误类型并添加日志副作用。共享 request 的 warmup 仍用原有统一 catch 设置状态。

## 检查命令与结果

- xcodegen generate：成功；相对本任务基线工程文件仅新增新 Swift 文件的四处引用。project.yml 的整个 iTermate 目录源配置未变。
- swiftc -parse iTermate/CodexTitleDiagnostics.swift iTermate/ItermBridge.swift iTermate/LocalModelService.swift：成功。
- swiftc -parse-as-library iTermate/CodexTitleDiagnostics.swift evidence/logging-example.swift：成功；重新编译后的示例无弃用警告。没有使用 XCTest、测试 runner 或项目测试套件。
- xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/itermate-codex-diagnostics-build build：修复后重新构建 BUILD SUCCEEDED，5.454 秒；最新日志 build-round-02.log，首次日志 build.log 保留。仅有工具提示未依赖 AppIntents.framework，非源码编译警告。
- git diff --check：成功。Context 仅更新选中 Pack，待最终验证 CLI 验收。

## 第 01 轮发现修复

独立 Reviewer 指出 TR-1：readSelection 对超过 4096 字节的配置抛出私有 ServiceError，会被记录为 unknown。主会话核实该分支后，只将该错误换为固定 typed reason invalid_configuration，原 4096 大小限制、错误文案 Invalid model selection、传播与回退保持不变。最新日志示例明确出现 invalid_configuration，记录器、权限、轮转、忙锁和符号链接观察均重做；Swift 解析和 Debug 构建重新通过。没有为读取配置而触发真实模型请求。

## 覆盖限制

未运行单元测试或项目测试套件，未执行真实 Codex 会话/UI 刷新，也未向 Ollama发送新请求。App 没有被本会话启动、重启或覆盖；日志示例只能证明文件记录器的合成路径，真实会话覆盖通过调用点静态追踪与 App 编译建立，用户自行运行新构建后才能采集真实错误。不能补写旧版运行期的错误，不能据此宣布原始标题故障已修复。

工作区有其他任务的未提交修改；本任务比较以 evidence/before 下的直接基线为准，不将全仓库 HEAD diff 归于本任务。审查内容身份以 snapshot.json 绑定。
