# Codex 输出预算与再次提炼检查

## 当前要求

用户要求："yes, please provide more output context and if the output is too long, you can invoke model to summarize it again, then output the final result without requiring the word limit."

主会话展示的完整Target是扩大Codex输出预算、首轮过长最多再提炼一次、最终不固定字数、不按长度拒绝或截断，保留有效性和身份保护、有限资源、不修改Pi、不重启应用、不运行测试。用户回复yes。

## T1：预算与有界二次调用

- 相对 evidence/before/LocalModelService.swift 的任务局部差异：只修改 LocalLLMService.generateSessionTitle。num_predict 从64改为1024，num_ctx仍16384，temperature/seed/think=false/keep_alive及HTTP超时不变。
- 首轮调用 completeTitle(allowsTruncation:true)，返回的text只在完整stop且非冗长时直接返回；超过80字符、多行或length结束都会执行唯一一次completeTitle(allowsTruncation:false)。只有这两处显式调用，没有循环、递归或第二轮再次判断长度。去除首尾空白只用于是否提炼的判断，不改写返回字符串。
- length只允许第一轮生成草稿；其余模型/done/message/content/thinking检查仍执行。第二轮必须stop，length仍抛tokenLimit；从未把截断响应作为最终标题。再次提炼同时参考原对话与非公开草稿，指令要求将资料作为数据、不续写草稿解释。
- 每轮调用前核对取消和原配置identity；每轮后核对配置与原库存digest并检查取消。Store仍负责终端Session/进程/摘录/requestID最终所有权判断；外层至多两次自动尝试保持原样。二次失败仍抛给原catch，保留原标题并写现有诊断。

## T2：最终不按字数拒绝

- 首轮提示词去掉六至十/最多十六元素及计数规则，改为准确概括、不设字数/元素上限；保留其他任务刚更新的目标概括规则与示例。
- 第二轮提示词同样没有数字字数限制。最终直接return result.text，未做长度判断、裁剪或格式清洗；80字符仅决定是否再概括一次，不是有效性检查。正常单轮结果也原样返回draft.text。
- 固定预算仍存在以约束资源，token cutoff不等于字数限制；最终响应必须完整有效。没有取消HTTP/大小/模型身份保护，没有改变Pi、问题判断或归档路径。

## 已执行的非测试检查

- swiftc -parse iTermate/LocalModelService.swift：通过。
- xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/itermate-codex-title-budget-build build：BUILD SUCCEEDED，11.890秒；build.log。唯一warning为AppIntents未依赖的工具提示。
- 直接编译 title-example.swift，链接本次Debug模块和dylib，在独立命令行进程调用实际LocalLLMService.generateSessionTitle，未执行App入口、NSApplication或真实Session/UI。这不是XCTest/测试runner。使用合成标题故障对话和已保存本地模型选择，qwen3.5:2b在约0.699秒返回“调整终端会话标题生成策略”；title-example.json保存观察。
- 示例调用生产完整路径及固定回环Ollama，没有写入用户配置、真实对话或安装目录。processes-before-example.txt与processes-after-example.txt完全相同，用户iTermate进程未被替换或重启。
- unchanged.sha256核对成功：Pi集成、Codex日志记录器、ItermStore及Xcode工程没有被本任务修改。输入/输出示例为公开合成内容，没有记录真实对话。
- git diff --check、Context validate：通过。

## 限制

未运行单元测试、项目测试套件或自动化mock；没有构造/动态执行第二轮、多行、token截断、第二轮仍冗长、配置切换或取消竞态。上述二次路径通过源码逐条件追踪、类型编译与直接调用点建立，不能把它们说成运行验证已通过。一次本地合成调用只验证实际单轮成功，不代表原始失败会话已经恢复。

没有启动、重启或替换用户App/Bridge/Pi/Codex/Ollama，没有操作用户真实会话，也未将新构建安装到用户运行位置。最终生效需要用户自行运行新版App；不能把已完成构建说成运行实例已更新。工作区有其他任务未提交内容，本任务范围以before基线、task.patch和snapshot.json为准。
