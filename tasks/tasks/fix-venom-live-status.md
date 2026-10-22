# 修复 venom-cli 执行期间的监控状态刷新

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-13 11:51) |
| Kind | Task |

## Scope

- 修复现有 venom-cli debug build 的动态雷达识别时机，覆盖构建、安装及持续调试阶段；不更改命令执行、Agent 优先级、完成统计或用户安装态。
- 不运行单元测试或测试套件，不启动或重启 App/Bridge；使用源码检查、构建和只读进程观察，真实 UI 留待用户重新运行后确认。

## Plan

1. 对照原生进程观察与状态展示路径确认延迟原因。
2. 移除对构建后日志子进程的依赖，保留真实前台进程与 Session 校验。
3. 进行编译、只读运行观察和变更自检，记录验证限制。

## Decisions

- 原检测要求前台 debug build 同时具有直接日志采集子进程，导致构建、安装和重建期间不匹配。改为匹配仍存活的前台 debug build，参数白名单与进程身份复核保持不变。
- Store 原有 2 秒 common-mode Timer、唯一 TTY、running/command、statusChangedAt 与视图显式身份更新链路均保持不变；非 debug 命令不纳入雷达范围。
- 修改前后只读扫描当前三个真实调试 TTY 均返回匹配；当时三者已进入日志阶段，因此该观察只证明既有调试会话仍可识别，不声称复现了构建阶段或观察到新 App UI。
- 新构建位于独立 DerivedData，未覆盖正在运行的产物；App PID 1230 保持，未安装或重启 App/Bridge。未运行单元测试或测试套件。

## Task Summary

**venom 调试状态识别**：目录 ["/Users/caishilin/Desktop/personal/iTermate/iTermate"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate)，移除雷达识别对构建后日志子进程的依赖及其无用匹配器，从真实前台 debug build 存活期间提供雷达状态，保留原有命令生命周期与刷新机制。

## Target
- [x] T1: venom-cli 命令执行期间及时刷新监控状态并显示对应雷达图标，不再等到命令结束才出现。

## Result

- T1: 对照检测条件与调用链：debug build 存活且为前台进程时直接匹配，不再依赖日志子进程；原 2 秒 Timer、published 状态和行身份刷新不变。swiftc -typecheck 与独立 DerivedData Debug build 通过，真实 ttys023/027/037 前后均匹配。未运行测试；未观察新 App 的构建阶段 UI，需用户重新运行确认。
- Review gate: Skipped — R1 四项依据已记录；限定为展示条件变更，源码路径、构建与现有真实进程观察完成，无显式独立审查要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 展示专用进程判定移除日志阶段前置条件，未改事件、并发、状态生命周期或执行命令。
- Snapshot: VenomDebugMonitor.swift sha256:cb93f222429db1bb06d3c7d33eb76c475691475b1eb1f8aecd006278e59a4a23; unchanged ItermBridge.swift sha256:7de7720b2c61206bab46b4bd90b4abb4ed74b951521622d766b6d6682bd4325c; unchanged iTermateApp.swift sha256:c91b73fde8866e25db4daefba6c496d64029c696b6f0a0370180d7db24dcca85; task-owned unstaged source diff only
- Evidence: 见 T1 Result；Debug BUILD SUCCEEDED，swiftc 类型检查成功，真实进程只读观察成功。
- Result clarity: 用户确认命令执行期间显示雷达，既有 debug build 识别入口无需等待日志子进程。
- Bounded impact: 仅展示细化谓词及其不再调用的日志匹配器；参数识别、TTY/UID/进程身份、Store 与像素动画原样保留。
- Low risk: 误判的后果仅为可恢复图标展示，不启动终端命令，不更改 Agent 生命周期、统计或用户配置。
- Sufficient verification: 直接逐项对照旧/新谓词与唯一调用方，检查刷新 Timer 和视图身份；类型检查与完整 Debug 构建通过，真实已存在调试进程匹配未退化；实际新 UI 未运行，不把该观察当作界面验证。
- Task fingerprint: ed396fc298ea92c690ef5f3a84ec96508545403c8892a16dbde2f9ae8a3ebeba

## Verification

- Passed: 最终重复 swiftc -typecheck 与 git diff --check 成功；三个文件 SHA256 与 assessment 相同。Debug 构建通过、Context validate 通过；未运行测试或新 UI，未启动/重启 App，界面需用户运行新构建后确认。
