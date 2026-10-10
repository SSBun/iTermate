# 为 venom-cli 调试监控显示专属状态图标

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 15:18) |
| Artifacts | [Artifacts](../artifacts/distinguish-venom-debug-monitor/) |
| Kind | Task |

## Target
- [x] T1: venom-cli 构建成功并实际进入调试监控阶段后，iTermate 才使用像素 Canvas 显示青绿色雷达图标：中心亮点、简化圆形轮廓及沿轮廓循环移动的扫描光点。
- [x] T2: 构建期间保留普通运行状态；构建失败或未进入监控时不显示雷达，其他命令不被误标，监控结束后恢复正常状态。

## Plan

1. 核实 venom-cli 调试入口及图标生效阶段，沿现有真实命令状态链路识别，不依赖标题或模型猜测。
2. 增加专属状态展示并保留普通命令与 Agent 的既有生命周期、优先级和辅助功能行为。
3. 进行非测试语法检查与构建，按实际改动评估审查；不主动启动或重启 App、Bridge，不覆盖用户安装态。

## Decisions

- 用户已接受完整目标，并确认青绿色像素雷达方案。
- 本机 venom-cli 2.3.0 的 `build --help` 显示 `build --run --debug` 为 Xcode 控制台日志入口；Android 支持 `build --debug` 和独立 `monitor` 仪表盘。
- 用户已确认完整修订目标：构建成功且进入监控阶段后才显示雷达；仅凭命令包含调试参数不能视为已进入监控。
- 已读取 venom-cli 的 Xcode `monitorDebugProcess` 和 Android `monitorLogcat` 调用链：仅成功构建、启动后创建专用日志采集子进程。使用 macOS 原生进程信息、真实 argv 和直接父子关系识别该阶段，不读终端历史输出、不修改 venom-cli 或安装目录。
- 状态识别放在共享 Swift Store，按唯一 TTY 对应的普通运行命令启用，覆盖 iTerm2 与已有 Shell 状态接入的 Ghostty；Agent 优先级和完成统计不变。每次重新观察都重新确认进程，退出、重新构建或读取失败不延续雷达。
- 已发现 iTerm2 Bridge 可以读取 Prompt command 和动态 commandLine；Ghostty 普通 Shell 状态目前没有命令文本字段，不能从标题推断。
- 工作区已有其他任务的未提交修改，必须保留；本任务增量单独记录在 evidence/task.patch。
- 第01轮审查确认缺失iTerm2快照TTY字段，必须修复真实快照到候选筛选的入口；审查前后逐文件hash一致。首次现场观察为4个正例与3个反例，后续持久化再次采集为3个正例与4个反例，后续Result以持久化记录为准，不将不同采样混为同一次证据。
- 修复时只读连接真实iTerm2 API，发现终端包装器kiro-cli-term创建嵌套PTY；外层Session TTY不等于venom进程TTY。现沿当前前台进程的真实父子关系限深、限量追踪，仍要求venom自身为前台且直接日志子进程存活，不按相邻TTY编号匹配。
- 只读诊断调用仓库Bridge的build_snapshot、用原Swift快照类型解码并应用Store同一候选条件，再调用生产detector；临时Bridge对象不启动任何服务或后台监控，不触碰运行中的Bridge。

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/distinguish-venom-debug-monitor/reviews/round-01.md) | sha256:516bcec728d6f92cd00e517c8cf7aa8569416e34601314aa98accc474124235e | findings: TR-1 |
| 02 | [Round 02](../artifacts/distinguish-venom-debug-monitor/reviews/round-02.md) | sha256:287cdd2ef88e66f44d69052dbc6a3b0dd468430840fc86fe12917f93905352f3 | no blocking findings；TR-1 resolved；主Agent已逐文件重算hash，无漂移 |

## Result

- T1: 第02轮Debug build通过，Python语法检查通过，bundle内Bridge与源码字节一致。只读真实iTerm2 API调用仓库build_snapshot，原Swift类型解码17个Session均有真实TTY；Store同一候选条件得到3个普通运行命令，生产detector识别2个监控候选与1个非监控候选，包含终端包装器嵌套PTY映射。证据evidence/live-snapshot-observation-02.txt及对应两端诊断源码。Canvas浅/深/减少动态效果PNG已检查；未启动新App，真实面板和模拟器未操作验证。
- T2: 第02轮持久化真实快照诊断中1个普通运行命令未被标记；静态核对前台进程树、venom build/debug参数与仍存活的直接采集子进程缺一不可，读取失败返回无标记。Store每2秒替换观察，非running/Agent/重复TTY不显示，切换终端/停止/唤醒清空，原命令生命周期与统计未改。未运行测试、未主动停止用户监控验证转换；退出与重新构建路径为源代码检查证据。第一轮现场与再次采样数量不同，已以各自持久化采样为准更正记录。
- Review gate: Passed — 第02轮fresh只读Reviewer（964047d1-65c7-4f51-baeb-e502d5c7ed5e）无已确认问题，TR-1 resolved；报告reviews/round-02.md已持久化并索引。主Agent逐文件SHA256重算与snapshot-02完全一致，解除快照身份条件性阻断；其他运行覆盖限制保留披露。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 原生进程树识别、嵌套PTY映射、Bridge快照字段和异步Store/UI联动；修复TR-1后仍需独立复核。
- Snapshot: sha256:287cdd2ef88e66f44d69052dbc6a3b0dd468430840fc86fe12917f93905352f3; tasks/artifacts/distinguish-venom-debug-monitor/evidence/snapshot-02.json
- Evidence: 当前T1/T2 Result；第02轮Debug构建、Python语法和打包资源一致性检查通过；真实iTerm2快照经Swift解码/候选条件/生产detector贯通，17个TTY、3个候选、2个monitoring。未运行测试或启动App。
- Task fingerprint: bad55fb9c04b16bfb6b1783980f487e04ae0d5d9defd2fe59faa7ee7108af4a3

## Verification

- Passed: 终审后再次重算snapshot-02全部内容hash，无漂移；git diff --check通过，Python重新编译语法通过，构建bundle Bridge与当前源码相同，round-02报告路径和快照身份一致。当前内容此前Debug build通过及真实快照→Swift→识别观测有效。未运行测试，未启动/重启App、Bridge或监控；真实面板交互及模拟器现场验证仍未进行，需用户自行运行新构建观察。
