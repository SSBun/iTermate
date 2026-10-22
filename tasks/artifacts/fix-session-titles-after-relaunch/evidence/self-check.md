# 自检证据

## 请求与边界

原始请求：重开 iTermate 后摘要标题不显示；没有标题的 Session 应自动生成标题。追加要求：这应是 AI 标签页中的设置。用户两次确认了完整目标，最近确认涵盖可持久化开关、恢复已有标题、开启补全和关闭不补全，以及不覆盖已有有效标题。

本任务不改终端原标题、Agent 状态或无关布局；开关只控制缺失标题补全，原有的任务完成后更新已有标题与手动刷新保留。默认开启。旧版只在内存中的 Codex 标题不能追溯恢复，符合条件时重新生成。

## T1：重开后恢复

- 源码检查：原 CodexTitleState 仅在内存中且 stop 时清空。现在成功结果保存标题及摘录 SHA256，并绑定 TTY、终端 Session ID、PID、进程启动时间；schedule 在生成资格判断前恢复，关闭开关、运行状态或无摘录不阻止恢复。身份不匹配不恢复。
- Pi 既有发现元数据包含 taskSummary，App 读取仍遵循新鲜度、活进程与唯一终端身份；重开 App 不清空该摘要。
- 新增 Swift 回归用例覆盖 App Store 重建、关闭补全、运行中无摘录恢复及 PID 复用启动时间不同的拒绝恢复。仅编译，未执行。
- 限制：未启动、重启 App 或 Bridge，未观察真实窗口的重开效果。

## T2：AI 开关与缺失补全

- 源码检查：原 Local Model tab 已更名 AI；LocalLLMSettingsView 以原生 Toggle 绑定 LocalLLMService，保存到共享 LocalLLM 配置。开关与模型选择分别从最新磁盘配置读出另一字段，原子写回；不可读/无效配置拒绝覆盖，生成读取无效配置时关闭自动补全。
- Codex 缺失补全要求已识别进程、有可见摘录，且状态为 finished/idle/interrupted/awaitingInput；未知与 running 不触发。成功相同摘录去重，保留两次尝试预算；关闭后缺失标题自动请求的迟到结果不能应用。手动刷新不受此开关限制。
- Pi 发现轮询只为支持 supportsTitleBackfill 的唯一活跃实例、空闲且无有效标题时发送独立 ensureTitle，最多两个在途；实例与原生 Session 两次请求且间隔至少十秒。端点重新核验 token/Session、偏好、空闲与 leaf，复用自动生成预算；已出现标题直接返回，status 动作保持只读。
- 新增 Swift 用例覆盖关闭不发起、开启后去重、已有有效标题不被空闲补全覆盖、开关重读及跨设置实例保留模型选择；TS 用例覆盖缺省、开关及无效配置。仅编译/类型检查，未执行。
- 限制：旧 Pi 集成需经 App 安装入口更新并在 Pi reload；本任务未覆盖用户安装态，未调用真实模型或执行端点 RPC。

## 执行的检查

- `xcodebuild -list -project iTermate.xcodeproj`：确认唯一 scheme iTermate；macOS 最低部署目标 13.0。
- `xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug -derivedDataPath .build/title-relaunch build CODE_SIGNING_ALLOWED=NO`：成功。
- 最终修改后 `xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug -derivedDataPath .build/title-relaunch build-for-testing CODE_SIGNING_ALLOWED=NO`：TEST BUILD SUCCEEDED，仅编译 App 与测试目标，不执行测试。
- TypeScript 5.9.3：`node /Users/caishilin/node_modules/typescript/bin/tsc --noEmit --target es2023 --module nodenext --moduleResolution nodenext --skipLibCheck --types node --baseUrl /Users/caishilin/.local/share/mise/installs/node/22.22.2/lib/node_modules integrations/pi/iTermate-integration.ts integrations/pi/task-summary.test.ts`：退出 0。
- PATH 上旧 TypeScript 5.3.2 不支持 es2023；改用已有 5.9.3 后上述检查成功，未安装新依赖。
- `git diff --check`：通过。Context 校验：valid=true。
- 构建仍有非阻塞的 AppIntents 元数据跳过警告，以及测试框架部署版本高于项目的链接警告。新增 trailing closure 警告已通过显式参数标签消除。

## 范围身份

以同目录 snapshot.json 中各文件 SHA256 为本轮身份。四个核心源文件的任务前快照位于 before/；scoped.patch 提供这四个文件的精确任务增量，other-files.patch 提供其他文件增量。

工作区存在其他会话改动。SessionGrouping 的 Commands 分组、AppSettings 的无关配置、面板紧凑布局和原有测试增量均不属于本任务。SettingsViews 只拥有 Local Model→AI 标签变更；iTermateApp 只拥有 generateCodexTitle 参数显式标签；ItermBridgeTests 只拥有标题回归用例与标题缓存隔离。复审应检查相关调用方，但不把外部改动归属本任务。
