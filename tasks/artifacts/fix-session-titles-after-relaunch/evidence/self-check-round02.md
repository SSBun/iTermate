# 第二轮自检

## 用户澄清与职责

用户明确：“You just control the automatic generation of title. The other task is to fix the generation issue.” 本任务控制自动补全开关、触发和保存/恢复；不决定或改动标题长度、换行、再摘要或格式校验。另一任务 resummarize-invalid-session-titles 的既有校验保持原样，恢复仅消费其认可的有效标题。这是并行任务职责澄清，不再要求用户在两个任务的格式策略之间选择。

## 首轮反馈处理

- TR-1：首轮报告观察到的80字/单行限制来自另一生成任务。该任务记录、其 before/ 及 file-deltas.patch 可核对所有权；本任务未恢复旧格式规则。请新鲜 Reviewer 根据用户最新原文核验职责重分类，不能仅凭 owner 声明移除该项。
- TR-2：仍保留普通配置写入前读取最新配置、失败不覆盖文件的保护。错误指引不再要求必然失败的模型重选，而显示 Repair Saved Configuration；AI 页提供显式确认入口，告知将保存私有副本、重置为2B和补全关闭，不下载或启动模型。repairConfiguration 先读取原始数据，已有效则只加载；损坏数据保存0600副本后核对原文件未变再原子替换。不可读/备份失败/文件变化均不替换。新增回归断言覆盖普通写入不覆盖损坏文件、显式修复保存原始副本和关闭补全。

## T1

Codex 成功标题和摘录 SHA256 由 UserDefaults 持久化，并绑定 TTY、终端 Session ID、PID、启动时间；在生成门之前恢复，关闭补全与运行中/无摘录均不阻止有效标题恢复。格式合格性调用另一任务的既有共享校验，不在本任务中修改。Pi 已有标题仍由活跃发现信息恢复。旧版内存标题无法追溯，符合条件时补生成。未运行真实重开 UI。

## T2

AI 标签页 Toggle 持久化到共享 LocalLLM 配置，默认开启。Swift 定时缺失补全、Pi 生命周期自动缺失生成及 ensureTitle 端点均读取该偏好；非缺失的原有完成后更新和手动刷新保留。开关保存不下载或调用模型。Pi 仅匹配唯一活跃身份，最多两个并发补全请求且同一实例/Session最多两次、间隔十秒；端点复用自动预算与当前会话/leaf核验。关闭时缺失自动请求的迟到结果不能提交；已有有效标题不会被补缺失操作覆盖。

## 检查与限制

- 本轮最终源代码：Xcode Debug build-for-testing 成功，仅编译 App 和测试目标，没有执行测试；构建记录时间约2026-10-22 16:08，结果 TEST BUILD SUCCEEDED。
- TypeScript 5.9.3 noEmit 同时检查生产集成和 task-summary.test.ts：退出0；git diff --check：通过。
- 新增 Swift 用例只编译，TS 用例只类型检查。未执行单元测试、真实模型、Pi RPC、启动或重启 App/Bridge，未覆盖用户已安装的集成。新 Pi 能力仍需用户通过既有安装入口更新并 reload。
- 构建仅有 AppIntents 元数据跳过及 XCTest 链接部署版本警告，无新增编译错误。
- 第一轮返回时已发现 TS 内容漂移，故没有记录 Passed。本轮 snapshot-02.json 绑定当前文件；owner 在交付前再次重算，任何有关漂移均更新检查并重审。

## 任务实际改动范围

- LocalModelService：LocalLLMSelection 的补全字段、补全偏好读取/保存、配置修复状态与确认备份入口、设置控件。不包括 isValidSessionTitle 或 generateSessionTitle 的生成/再摘要规则。
- ItermBridge：CachedCodexTitle、偏好注入、缓存恢复与持久化、缺失补全状态门、请求所有权清理与测试入口。不包括其他任务加的共享格式校验或 Commands 分组。
- PiSessionArchives：supportsTitleBackfill、受偏好控制的补全调度及停止取消。不包括 isValidTaskTitle 的格式规则。
- Pi 集成：fillsMissingTitles、共享偏好解析、supportsTitleBackfill、ensureTitle动作和生命周期的缺失开关门。不包括模型输出格式、提炼提示词或输出预算。
- SettingsViews 仅 Local Model→AI 标签；iTermateApp 仅 generateCodexTitle 显式标签。标题回归用例与本任务段落文档属于本任务；其他会话用例与布局不属于本任务。
