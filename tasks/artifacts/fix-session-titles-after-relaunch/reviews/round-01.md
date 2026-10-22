# 独立复审第 01 轮

任务：fix-session-titles-after-relaunch

模式：fresh 只读子代理；运行：80a19c99-e068-40ae-ab50-54e732b5f4f0。

委派快照：sha256:420c0758b5e155e7def500c6004bc0421124ac640f42d4bb92c2d59e96142fba。

Owner 注记：返回后重算发现 TS 核心源码已被其他会话修改，本轮不能作为当前快照通过依据。TR-1 涉及其他任务引入的旧标题格式限制，需处理交叉目标；TR-2 为本任务配置重选回归。

---

## Review mode
independent subagent；只读单次反馈，未修改文件或任务状态。

## Reviewed scope / snapshot
核对了任务范围内差异、核心生成与恢复路径、直接调用方和新增用例；排除 Commands 分组及紧凑布局等其他会话改动。

入口与结束时读取的 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/fix-session-titles-after-relaunch/evidence/snapshot.json"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/fix-session-titles-after-relaunch/evidence/snapshot.json) 内容一致。所提供身份为 `420c0758b5e155e7def500c6004bc0421124ac640f42d4bb92c2d59e96142fba`，未独立计算哈希。

## Findings

### TR-1
- **Severity**：P1 / Critical Finding。
- **Location**：["/Users/caishilin/Desktop/personal/iTermate/iTermate/PiSessionArchives.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/PiSessionArchives.swift):197–211。
- **Issue**：新增格式限制使此前有效的已有 Pi 标题在重开新版 App 后消失。
- **Evidence**：任务前显示校验接受非空、最多 16384 UTF-16 单元的标题；现在改用最多 80 个 Unicode 标量且禁止换行的校验。例如已有 81 字标题，以前显示，现在直接回退终端原标题。该路径不受补全开关控制；旧集成又不支持 `ensureTitle`。
- **Impact**：违反 T1 的已有标题恢复要求，对旧集成形成可确定的兼容性回归。
- **Suggested next step**：区分既有标题显示兼容校验与新生成结果校验，保留此前合法标题的显示；新增旧标题超过 80 字或含换行、关闭补全时仍恢复的回归用例。

### TR-2
- **Severity**：P2 / Concern。
- **Location**：["/Users/caishilin/Desktop/personal/iTermate/iTermate/LocalModelService.swift"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/LocalModelService.swift):786–810、838–848。
- **Issue**：无效配置的显式模型重选恢复入口失效。
- **Evidence**：初始化和刷新失败仍提示 “Choose a model again”，但 `selectModel` 新增 `try readSelection()` 前置条件；同一个无效配置必然再次抛错，无法写入用户明确选择的模型。任务前该入口直接保存新选择，可以恢复。
- **Impact**：用户按界面指引操作仍无法恢复本地模型功能；补全开关也无法保存，只能外部处理配置。
- **Suggested next step**：保留正常配置的字段保留逻辑，同时提供明确的无效配置恢复路径；不要静默覆盖不可读文件，也不要继续提示一个必然失败的操作。

以上两项均需 owner 核验并修复。

## Unverified risks
- **快照身份**：工具无法计算 SHA256；已对照核心差异与实际相关源码，但不能证明全部十个文件在整个复审期间未漂移。owner 最终重算匹配前，当前快照绑定仍待验证。
- **运行效果**：未验证真实重开 UI、模型调用或 Pi RPC。属于明确禁止执行的覆盖限制，不单独认定为缺陷；旧 Pi 安装态仍需更新并 reload。

## Checks performed
- 静态核对 Codex 缓存身份、生成门、请求所有权、迟到结果及已有标题更新路径。
- 核对 Pi token/Session 认证、独立 `ensureTitle` 分支、状态读取不调用模型、并发与重试限制。
- 核对共享配置保存、默认值、AI Toggle 接线及相关回归用例。
- 对照任务前文件确认上述两项为本次差异引入的回归。
- 未运行测试、构建、App、Bridge 或模型。

## Author evidence examined
代码检查后读取了 ["/Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/fix-session-titles-after-relaunch/evidence/self-check.md"](file:///Users/caishilin/Desktop/personal/iTermate/tasks/artifacts/fix-session-titles-after-relaunch/evidence/self-check.md)。其中 App build、build-for-testing、TS noEmit 和 diff check 为作者报告，本次未重跑。

## Coverage limits
仅审查指定任务及必要上下文；不构成全仓审计。新增用例只做源码检查，不将编译成功视为行为测试通过。