# 移除标题格式强过滤的检查证据

## 当前有效要求

用户纠正原文：“标题约束只是提示词约束，不会返回结果做强过滤处理”。主会话据此展示新版 Target：移除返回标题格式强过滤，长度/空格/标点等只在提示词中要求；生成、显示和手动刷新均接受非空标题，不按格式拒绝，不删空格、不截断；保留通信、空结果、身份与取消保护，不重启 App/Bridge，不运行测试套件。用户回复 `confirm`。

早期 diagnosis.md 中要求原始格式强校验的方案已经作废，不是当前验收标准。

## T1

Pi 的 `isValidTaskTitle` 现仅检查字符串和非空白，不修改返回值；提示词保持原样。删除了因此不再使用的生产元素计数 helper。

实际手工调用当前源码导出的 summarizeTask，使用与失败诊断相同的公开合成 Control-Tab/Codex 输入，533ms 返回 `控制 Tab 切换会话跳过 Codex 故障`，其中空格保留。见 [manual-title-after.json](manual-title-after.json)。命令为 tsx 单次直接调用，不是测试 runner；未触发默认扩展入口或写入真实会话。

补充但未执行的回归源码覆盖空格、标点、数字、换行、英文、状态词、超出建议长度的原样返回，以及空/非字符串、取消及供应商失败的拒绝。模型对比诊断仍可报告格式质量，不再把长标题误算为生成失败；原有凭据回显保护不变。

## T2

自动发布和 refreshTitle 使用同一 summarizeTask 返回值，没有新增格式或清洗路径。Swift 的 sessionTitle 和 refreshTitle 共用非空白检查，并保留既有16384传输界限，不再校验汉字、元素数、字符或状态词。私有发现文件大小、RPC大小、模型库存/选择身份、响应结束状态、请求取消、实例/Session/leaf匹配等保护未修改。

补充但未执行的 Swift 展示及自动发布/手动刷新回归用例，检查含空白、标点和数字标题保持原样。

## 已执行检查

- `tsc --project tasks/artifacts/local-llm-only-question-and-title/evidence/tsconfig.json`：严格 noEmit 成功，涵盖生产集成、任务标题及模型对比 TypeScript 源码。
- `node --check integrations/pi/archive-lifecycle.test.mjs`：语法通过，未执行测试。
- `swiftc -parse iTermate/PiSessionArchives.swift iTermateTests/PiSessionArchiveTests.swift`：退出码0。
- `xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/itermate-title-filter-build build`：`BUILD SUCCEEDED`，19.024秒；产物未启动。日志保留于 `/tmp/itermate-title-filter-build.log`。
- `git diff --check`：通过。
- Context CLI validate：valid=true，无错误或警告。
- 搜索所有生产标题过滤入口：仅剩 Pi 与 Swift 的非空白检查，文档旧强过滤描述已更新。

## 限制

没有执行单元测试、全套测试或真实 UI 刷新；Swift 回归源码只作语法检查。未安装、覆盖或 reload Pi 集成，未主动重启 App/Bridge。排查期间其他操作者更新了安装副本和运行进程，不将那些变化归因于本会话，也不据此声称当前运行实例已加载本次代码。

工作区存在多个任务的既有未提交修改；[task.patch](task.patch) 仅记录本任务相对修改前基线的变化，[snapshot.json](snapshot.json) 标识当前文件内容，其他修改不属于本任务。没有修改归档摘要、问题分类或模型配置。
