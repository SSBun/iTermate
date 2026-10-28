# 实测Codex独立模式的精准绑定能力

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-27 18:12) |
| Artifacts | [Artifacts](../artifacts/test-codex-no-daemon-binding/) |
| Kind | Task |

## Target
- [x] T1: 用新建受控Codex独立模式会话，验证实际进程与对话归属，并据观察判断是否足以完整解决绑定问题
- [x] T2: 覆盖可执行的新建及切换或重开场景，明确成功、失败与未验证边界，不以静态推断代替实测
- [x] T3: 不操作已打开的用户Codex，不重启iTermate或Bridge、不修改全局配置，测试进程及资源可清理

## Scope

本轮用户明确授权实测codex --no-daemon，仅测试新建受控TUI进程与仓库原版CodexSessionMonitor。不实现产品修复、不修改用户配置或已打开终端、不启动/重启iTermate及Bridge，不使用codex exec承担代理工作。只向受控TUI发送合成canary与/status、/new，不读取项目内容或要求调用工具。模型调用仅为启动真实对话所需的短合成输入。

## Plan

1. 编译仓库原版Monitor与最小类型适配，通过真实PTY读取原生进程及文件描述符，不替换产品实现。
2. 先检查空TUI、首条合成消息后的自有rollout与监测关联，再检查同进程/new前后当前thread身份；能执行时补充同目录重开。记录成功、失败和未执行项。
3. 将终端原生/status与文件首行身份作为ground truth，保存脱敏hash及匹配布尔值，不保存完整thread UUID、对话、隐藏思考或凭据。
4. 检查全局配置及生产Monitor源码哈希未变，清理只由测试创建的进程和私有临时目录；不以这些PTY观察冒充完整iTerm2/面板UI验收。

## Decisions

- 当前请求授权测试，取代此前任务范围中的不运行测试限制，但不扩大为修改配置、发布、重启App或操作现有会话。
- 全局环境的初始受控启动遇到invalid transport，因此后续用私有临时CODEX_HOME及最小配置排除MCP/插件干扰；仅引用现有登录文件路径，不复制、输出或记录凭据。CODEX_HOME只传给本轮测试进程与Monitor，生产App不变。
- 第一次驱动在macOS PTY master上调用ttyname触发ERANGE，已改读实际测试PID的TTY；后续分离粘贴与Enter，避免Codex TUI将连续输入当作未提交粘贴。驱动失败和无效场景不算产品测试通过。
- 首轮原生正向结果已确认/status身份与自有rollout匹配，但清理阶段超时，记录单独保留。最终驱动增加排空PTY及有界进程回收后完成了一整轮：首次消息准确绑定、/new前后错绑及丢失绑定均实测到，当前与此前残留的测试进程/私有目录已核对清理。不将驱动启动/清理失败算作产品反例。

- Current artifacts: 本任务evidence中的Swift原版Monitor适配入口、PTY驱动、逐次脱敏结果与保护文件哈希。
- Next action: 交付有效测试轮次的结论；本任务不实施产品修复，不改变用户启动方式。
- Required input: None

## Observations

- 有效轮次使用原生Codex0.164.0、独立PTY、临时CODEX_HOME，terminal_title=[]，原版CodexSessionMonitor。只读沙盒与never审批用于本轮合成输入，MCP/用户插件未加载；临时目录只引用用户现有登录路径，不复制凭据。终端与Monitor使用相同临时CODEX_HOME，未覆盖生产环境。
- 18:08:10，测试TUI的/status给出thread A（脱敏hash 4e6ea01e2cfdc8cd），尚未首次发送消息时无rollout，Monitor确认进程但没有thread映射。该观察不冒充“未创建对话”结论，只说明磁盘尚无可读记录。
- 18:08:12，首条合成消息产生CLI自有根rollout，Monitor的thread hash与/status一致，status=running，requiresRuntimeStatus=false。证明no-daemon可在这个场景获得准确文件归属。
- 在同一个测试TUI里中止合成回复并执行/new，18:08:19的/status给出不同thread B（hash 98bdfefc27ef7b66），该进程仍持有一个旧rollout FD。Monitor仍返回thread A及interrupted，matchesExpected=false。这是实际误绑，不是仅缺状态。
- 18:08:21，向B发送合成消息后，新rollout已出现，但CLI同时持有两个根rollout FD；Monitor返回hasThread=false，matchesExpected=false，无法选择当前显示thread。源码resolveMatch对多个opened根文件返回nil，与现场一致。
- 有效轮次完整事件保存在 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/test-codex-no-daemon-binding/evidence/live-results.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/test-codex-no-daemon-binding/evidence/live-results.json)。原生/status与FD首行metadata作为ground truth，输出只保留hash和布尔值，没有把时间接近或最新文件当作真实归属。
- 原设想的关闭后同目录重开场景在早期清理超时后没有形成有效测试；最终用同进程/new得到足以否定“完整修复”的直接反例，不把重开场景写成已通过或已失败。审批等待、完整成功/失败、计数、并行多终端与真正iTerm2面板未验收。

## Cleanup and Scope Checks

- 最终测试PID81588正常回收，临时CODEX_HOME已删除；首次清理超时遗留的一个私有目录也在检查所有者、0700权限、受控配置及auth符号链接目标后删除。未匹配目录不删除，本次未匹配为零。编译产物和脱敏证据保留供复查，不属于运行进程残留。
- 最终ps确认81588及早期测试PID均不存在，现有App PID70525仍为原进程；没有按进程名批量kill，没有向用户既有Codex输入。
- 生产Monitor、全局config.toml与hooks.json的SHA256与测试前完全相同，保护检查三项均true。cleanup-summary.json及before-sha256.json保留核对依据；不声称认证刷新等程序内部行为已经完整审计。
- Python驱动AST语法检查及真实Swift Monitor独立编译均通过。实际执行的是原生TUI与生产Monitor的集成实测，不是CodexSessionMonitorTests单元测试或完整项目测试套件；没有启动App作UI验收。
- Context已维护受影响的终端监控Pack：no-daemon仍可能保留旧thread FD，因此文件持有不构成当前显示身份的充分证明；Core及无关Pack未变。该事实对未来接入路线有直接影响。

## Task Summary

本任务新增受控测试驱动与脱敏实测证据，并维护终端监控Context事实；没有修改产品源码、用户安装态或全局配置。

## Conclusion

codex --no-daemon不能单独完整解决精准绑定。它在首次合成消息后提供了可用的自有文件归属，但实际/new切换后先误绑旧thread，再因多个FD失去绑定。后续修复仍需TUI当前显示thread的准确身份信号；不能把no-daemon、最新FD或目录/时间猜测作为替代。

## Result

- T1: 已用真实Codex0.164.0 --no-daemon及仓库原版Monitor完成有效独立PTY实测：首次消息产生自有rollout后thread hash与原生/status一致且running；因此该首轮场景可绑定，但不构成完整解决。见live-results.json与Observations。
- T2: 实测/new后原生/status给出新thread，但Monitor先错误保留旧thread；新消息落盘后进程持有两个rollout FD，Monitor无法唯一匹配。已取得足以否定完整解决的直接反例。关闭同目录重开、并行、审批、完成计数及完整面板未验证，未冒称通过。
- T3: 最终测试进程及先前已知PID均退出；本轮与清理超时遗留的受控临时目录均已核对删除。生产Monitor、全局config.toml及hooks.json哈希保持不变；App70525未重启，不向既有Codex发送输入。仅保留测试证据和编译产物。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 交付为受控实测结论，无产品源码或运行配置变更；测试驱动与脱敏日志是验证证据，Context仅维护已确认边界。
- Snapshot: snapshot:tasks/artifacts/test-codex-no-daemon-binding/evidence/8ad4576f200b5815a93119d85688d2daea40e7098fa3bc9c125b34a5dfc73179.json#8ad4576f200b5815a93119d85688d2daea40e7098fa3bc9c125b34a5dfc73179
- Evidence: Observations与Cleanup and Scope Checks；原生/status、CLI自有FD metadata及Monitor三个关键样本交叉核对。verified-summary.json以断言核对实际记录，不把驱动准备失败算产品反例。
- Task fingerprint: 5ba93843060acd3066eefad4223e228c1c7ddf91fa0547d65f93ab41bd4ed595

## Verification

- Passed: 最终重新断言首轮匹配成功、/new旧thread误绑、多FD丢失匹配及清理事件；保护文件SHA256未变，Python AST和Context校验通过，git diff --check通过，快照9文件已锁定。实际执行原生集成实测，未执行完整项目测试或UI验收。
