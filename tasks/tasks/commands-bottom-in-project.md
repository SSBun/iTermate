# 新增普通终端在对应目录末尾显示的模式

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-02 17:07) |
| Artifacts | [Artifacts](../artifacts/commands-bottom-in-project/) |
| Kind | Task |

## Scope

只修改会话展示与对应偏好，不改变终端目录、生命周期或用户安装态。保留工作区已有的会话点击修复。

## Plan

1. 新增三选一普通终端展示偏好，保留已有配置的选择。
2. 在 Project Path 分组中将普通终端放在 Agent 后面，并让渲染和导航消费相同顺序。
3. 编译与静态核查；不运行测试、不启动或重启 App。

## Execution Log

### 001 — 确认分组与配置边界

现有 Commands 分区由布尔偏好控制，面板和快捷导航共享 SessionGrouping。渲染会按 Tab 再聚合，所以新模式还需区分同一 Tab 的 Agent 与普通终端区块。采用三选一枚举，旧配置布尔值仅在没有有效新字段时作为读取来源。新模式只改变 Project Path；Window 保持原有混排。

### 002 — 完成展示偏好与构建

新增 CommandSessionPlacement 三选一枚举，General 与面板菜单共享 AppSettings。Project Path 先分出 Agent 与普通终端，再分别按 Tab 聚类；区块 ID 带类型前缀，面板与快捷导航保持一致。旧布尔字段读取与新枚举字段优先级已人工核对，写入仍复用重新读取磁盘后仅修改目标字段的既有路径。

已用独立 DerivedData 执行 arm64 Debug build，结果 BUILD SUCCEEDED；没有启动、重启 App 或 Bridge。新增分组顺序、Tab 区块、所有模式持久化与旧字段行序兼容用例，并对两个测试文件执行 swiftc -parse；仅语法通过，未运行测试。原有点击修复保持不变。Context 存在既有未索引章节警告，未做无关迁移。

## Task Summary

**会话展示与偏好**：["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 新增普通终端目录末尾模式、三选一设置及配置读取兼容；渲染区块与导航使用同一顺序。

**回归用例**：["/Users/caishilin/Desktop/personal/iTermate/iTermateTests"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests) 更新枚举接口引用，新增目录末尾、跨 Tab 展示顺序和偏好读写用例。

## Self Assessment

| Dimension | Score | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 改动最小性 | 5 | 仅展示模型、两处设置入口、配置及对应回归用例；保留已有点击修复 | 未重构既有设置读写与折叠机制 |
| 稳定性 | 4 | Debug 编译通过；新模式只做稳定筛选和拼接；旧模式分支保持原有逻辑 | 未运行测试及实际 App |
| 目标对齐 | 5 | 代码核对普通终端仍按精确目录分组并在 Agent 后；分块不会重排回前部 | Window 模式按说明保持混排 |
| 验证充分性 | 4 | 全应用 Debug build、测试文件语法解析、调用链及配置优先级人工核对、diff 检查 | 回归用例未执行，无新版运行截图 |
| 完成信心 | 4 | 设置、持久化、分组和渲染/导航链路已闭合；没有终端或安装态副作用 | 用户需自行运行新版确认视觉效果 |

## Target
- [x] T1: 新增可选模式，普通终端保留在对应目录分组并排在该组 Agent 会话之后，保留现有模式

## Result

- T1: 已核对设置与面板菜单共享三选一持久化偏好，Project Path 在每个精确目录内先按 Tab 排 Agent，再按 Tab 排普通终端，类型区块 ID 保证渲染和导航不重新混排；旧混排及 Commands 分区保留，旧布尔配置在无有效新字段时读取。Debug build 成功，回归用例仅语法解析通过，未运行测试和新版界面。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 有界展示偏好与稳定分组分支，不修改终端状态、磁盘目录或外部操作；源码比较和编译支持结果
- Snapshot: snapshot:tasks/artifacts/commands-bottom-in-project/evidence/b56ec29b902e8e0781ce95576548ae8b94eb800b5ee608bd5e01a7e94ac594fc.json#b56ec29b902e8e0781ce95576548ae8b94eb800b5ee608bd5e01a7e94ac594fc
- Evidence: T1 与 Self Assessment；实际两次 Debug build 成功，两个测试文件 swiftc -parse 成功，git diff --check 成功
- Result clarity: 新增目录内末尾模式含义明确；两个原模式继续可选，Window 不改变顺序
- Bounded impact: 直接消费者仅面板与快捷导航，共用 groups 和 blocks；配置读写仍用现有 AppSettings 合并路径
- Low risk: 仅列表顺序和本地展示偏好，可随时切回；无生命周期、归档、关闭或路径变更
- Sufficient verification: 逐项核对筛选互补无丢失、Agent/命令分块不回并、旧配置与新字段行序优先级、两入口及导航参数；全应用编译和 diff 检查通过；未执行测试和真实 UI
- Task fingerprint: 67fb81027bc69a6d6568589f7bead78ef722040479850cbc98f723a7c785a55e

## Verification

- Passed: 最终 Debug 增量构建退出 0，两个测试文件 swiftc -parse 退出 0，git diff --check 退出 0；与 snapshot 六文件保持一致，自评分依据未变化，保留已有点击修复。
