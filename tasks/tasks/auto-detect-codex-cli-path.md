# 补齐 Codex 自动路径与模型设置

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-13 11:46) |
| Artifacts | [Artifacts](../artifacts/auto-detect-codex-cli-path/) |
| Kind | Task |

## Plan

1. 核对当前 Codex 安装与 macOS GUI 环境的可执行路径。
2. 在设置、Swift 调用与 Pi 调用中补充一致的自动检测，并保留手动路径优先。
3. 为当前用户填写已验证的路径，并提供基于本机目录的模型 ID 与思考等级选项，将所选值传入 Swift/Pi 调用。
4. 完成编译、类型检查及设置界面核验；不执行真实模型请求。

## Execution Log

### 001 — 安装核验与当前设置填充

截图确认 Codex CLI 路径为空。终端可定位到 mise 管理的 Codex，稳定 shim 位于用户 .local/share/mise/shims/codex；在 PATH 仅包含系统目录时执行该入口 --version 成功，输出 codex-cli 0.167.0。已通过 agent-desktop 将空字段设置为该路径，并只读取共享配置的 codexExecutable 字段确认实际落盘，不只是界面文本变化。未改其他设置或读取密钥，没有执行登录或模型生成。

### 002 — 自动检测实现

Swift 与 Pi 均在未配置路径时按相同顺序检查 mise shim、进程 PATH、常用本地/Homebrew 目录和 Codex 应用资源目录。仅接受绝对路径下的可执行普通文件，排除目录和相对 PATH 项，不启动 shell。已有显式路径优先，失效时也不静默替换。设置显示自动发现的路径与检测说明，允许手动覆盖，清空后恢复自动检测。运行前解析路径，因此不要求先在 UI 保存检测结果。

Debug 构建通过，严格 TypeScript noEmit 检查通过。当前安装态仅填充配置，没有替换应用或 Pi 集成。未运行测试套件、登录或真实模型调用；新界面的自动检测文案尚未在安装态验证。

### 003 — 模型与思考等级修订

用户进一步询问临时 Codex 会话，并要求模型 ID 与 thinking level 选项。已说明当前每次调用启动独立 ephemeral CLI 会话，不复用用户交互会话。本机 Codex 模型目录列出 gpt-6.1-sol、gpt-6-astra、gpt-6.1-terra、gpt-6-sol、gpt-6-luna 及 5.6 系列；思考等级能力因模型而异，常见 low/medium/high/xhigh/max，部分模型提供 ultra。该目录不是当前账号可用性的实测。

设置现从本机模型目录生成 Choose Model 菜单，保留手动输入和 Codex Default；thinking picker 按所选模型显示，切换模型恢复默认。新增可选配置字段，旧配置保持可读，Swift 与 Pi 均显式传递 --model 和 model_reasoning_effort。尚未对本阶段修改执行构建或界面核验。

### 004 — 构建与菜单观察

本阶段 Debug 构建、TypeScript 严格 noEmit 与 git diff --check 通过。隔离预览中已实际观察到 Model ID 输入、Choose Model 菜单列出的八个可见模型、Thinking level 默认项与当前 CLI 路径，未选择模型/等级，也未点击真实模型测试。用户提供的截图显示旧版标题测试产生了标题及 17.05s 耗时，仅作为用户现场背景，不当作本次新增参数的验证。

预览第二次启动后观察到模型字段从空值变为输入片段 t to，可能为窗口抢焦点所致。已关闭预览，只在当前字段仍等于该片段时加锁重读配置，将该字段恢复空值，其他配置保留。预览进程及临时文件已清理。后续不再启动前台预览。

## Task Summary

**AI 模型服务与设置**：[应用组件](../../iTermate/)新增 Codex 可执行文件检测、本机模型目录菜单和模型能力对应的 Thinking level 选择；保留手动 Model ID 与路径、默认等级和旧配置兼容，并在执行时传递模型与推理参数。

**Pi 集成**：[集成组件](../../integrations/pi/)按相同候选顺序发现 Codex，拒绝目录和非绝对路径；读取并验证可选思考等级，临时调用传递对应 model_reasoning_effort。

**使用说明**：[文档](../../docs/)说明自动检测、手动覆盖、本机模型目录、思考等级与 ephemeral 会话行为。当前用户路径已填入验证过的本机入口。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | A | 两端使用小型文件属性检查和本地目录解析，不引入 shell、依赖、扫描索引或配置迁移。 | 两种运行时需各保留候选顺序和思考等级枚举。 |
| 稳定性 | A | Debug 构建、TypeScript 类型检查及精简 PATH 下 CLI --version 成功；选项来自本机目录，配置可选字段兼容旧值；显式路径优先。 | 未执行真实模型或测试套件；目录可能过期，账号能力需用户验证。预览焦点导致的输入片段已按精确值恢复。 |
| 完整性 | A | 当前路径已填写并落盘；Swift/Pi 接入自动解析及参数传递，设置有模型菜单、等级与默认值；预览确认控件与模型目录显示。 | 尚未在真实模型上验证选定参数；新源码尚未替换安装态。 |

## Target
- [x] T1: Codex integration 自动发现本机 Codex CLI 路径，无需用户手动填写。
- [x] T2: 保留明确手动配置，未找到时显示清楚说明，不执行登录或真实会话调用。
- [x] T3: Codex integration 提供模型 ID 与 thinking level 选项，所选值实际传入 Swift 与 Pi 的临时 Codex 调用。

## Result

- T1: 当前空白路径已填为用户mise稳定shim并核对落盘；CLI在系统精简PATH下--version成功。新源码在Swift/Pi未配置时自动检测相同候选，UI展示检测结果。
- T2: 显式路径优先，失效也不替换；仅绝对可执行普通文件有效，不启动shell；没有执行登录或模型请求。预览中模型输入意外变化已按精确值恢复，其他设置保留。
- T3: 本机目录模型菜单、Thinking level与Codex Default在隔离预览可见；Swift/Pi均传递--model和model_reasoning_effort，可选枚举字段保持旧配置可读。Debug build与严格tsc通过；未真实调用模型验证参数。
- Review gate: Passed — 独立只读复查round-01无发现；owner check-evidence核验六文件快照一致；运行态能力与GUI完整覆盖限制保留。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 跨Swift与Pi新增可执行路径发现、模型目录和思考参数配置，需要独立检查默认、显式覆盖与两端一致性。
- Snapshot: snapshot:tasks/artifacts/auto-detect-codex-cli-path/evidence/2a94dc8f81df0c7d31d1931bc22eb7a5c860fb9421b946d33065daad88ccf425.json#2a94dc8f81df0c7d31d1931bc22eb7a5c860fb9421b946d33065daad88ccf425
- Evidence: Result T1-T3，Debug构建、tsc及GUI菜单观察；未调用真实模型或测试套件。
- Task fingerprint: 389937d5b6b2d5ed5127e916c2df1bff532dadc98818c5726069355587eaddff

## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/auto-detect-codex-cli-path/reviews/round-01.md) | snapshot:tasks/artifacts/auto-detect-codex-cli-path/evidence/2a94dc8f81df0c7d31d1931bc22eb7a5c860fb9421b946d33065daad88ccf425.json#2a94dc8f81df0c7d31d1931bc22eb7a5c860fb9421b946d33065daad88ccf425 | no blocking findings | a0cdf9d52178aa9f292f139bc4a5ab54e41178961ae6f3a1b44a5d2fe9ba3813 |

## Verification

- Passed: 最终严格tsc与git diff --check分别exit0；check-evidence核验六文件快照及独立报告。当前源码与Debug构建/GUI观察后未变，审查无发现。未真实生成、未运行测试套件或替换安装态；已填当前路径并恢复预览中的输入片段。
