# 调查等待确认时未显示问号的原因

| Field | Value |
| --- | --- |
| Status | Pending (2026-10-09 16:36) |
| Kind | Plan |

## Target

- [ ] T1: 审计当前代码中状态符号的完整判定与显示链路，说明各状态的触发、切换、清除及显示条件。
- [ ] T2: 明确生命周期事件、Laya、正则、子代理活动和 Shell 信号的职责、优先级与回退关系，列出有代码依据的问题及证据边界。
- [ ] T3: 结合截图解释问号缺失的可能路径，区分确定的代码行为与未验证的运行时原因；仅调查，不修改产品代码。

## Scope

仅只读调查等待识别和问号显示链路；不修改产品、用户安装态或配置，不重启应用，不运行测试。

## Decisions

- 源码与已安装的 `/Users/caishilin/.pi/agent/extensions/iTermate-integration.ts` 使用相同的 `needsReply` 规则：剔除代码和引用，取最后两段，拒绝超过 1200 字符的尾部；排除示例、否定等待及可选建议后，要求短批准门句式或 request 与 waiting 同时成立。
- 截图尾句“确认后我写入并校验。”不匹配 request，且 waiting 的后续动作词仅覆盖开始、继续、执行、进行，不覆盖写入、校验。因此文本 fallback 会漏识别；此为静态代码可确认的缺陷，不等于截图运行时唯一根因。
- `agent_end` 缓存最后一条正常结束的 assistant 文本，`agent_settled` 在空闲时调用可选本地模型。模型明确结果优先于正则，包括否定结果；不可用或不确定才回退正则。模型状态概率须至少 0.85，待回复概率至少 0.6 才判为等待，idle 且待回复概率至多 0.4 判为非等待；调用截止时间 800ms。
- 调查时本地 analysis-enabled 标记存在且 Laya 服务进程存在，但未取得截图时的模型响应、超时记录或 Session 上报，不能据此断言当时模型开启、成功或判定为何。
- Swift 行渲染要求 agent + awaitingInput；子代理图标独立显示，集成 visibleStatus 也优先保留 awaitingInput。因此当前源码没有“子代理图标必然覆盖问号”的规则。等待样式可配置，awaitingInput 不必然使用问号造型。

### 扩展审计结论

- Pi 主状态优先级：promptOpen 或 baseStatus=awaitingInput 优先，其次活跃子代理维持 running，否则使用主 Agent 状态。子代理标志来自 Fleet totalActive，不读屏幕；2 秒轮询，6 秒新鲜度，未知时停止仅靠子代理支撑的续租。
- Pi session_start=idle、agent_start=running；agent_end 取最后 assistant，只有 stopReason=error 设置失败，非 stop 正常文本不参与待回复；agent_settled 且 ctx.isIdle 后才决定 awaitingInput/finished。显式 UI prompt 不调用文本分类，custom 被排除；session_tree 清理旧推断，shutdown 上报 detached。
- Laya 存在两条职责不同的路径。Pi 末条 assistant 尾部 1500 字符分类可以生成正式状态；Bridge 仅在无正式状态时读取屏幕尾部 1500 字符，轮询生成 8 秒有效的 modelState，界面仅显示 Reply?/Running?/Idle? 辅助标签，不能覆盖 finished/idle/running。
- Laya /v1/session 固定询问四选一 state 与 needs_reply；服务单次推理锁忙返回 429，超模型 token 预算返回 413，推理异常返回 500。Pi 对所有非 200、错误和超时统一回退，没有记录具体原因，也不会在同一 settled 后定期重新推理。服务启用不保证每轮成功使用模型。
- Codex hooks 只映射 SessionStart→idle、UserPromptSubmit→running、Stop→finished、SessionEnd→detached；report_agent 丢弃 hook stdin，finished 固定 exitStatus=0，不进行回复文本分类。因此正式问号及业务失败识别能力与 Pi 不等价。
- Pi 同样不等同业务成功：error 以外的 stopReason 未被单独编码为失败/取消；若最终 settled，将走 finished/0。此为静态路径风险，未动态复现取消事件。
- iTerm2 Bridge Agent 管理状态优先于 Shell Prompt；等待/心跳状态 8 秒失效，状态删除不伪造完成。Ghostty 按 TTY 匹配，有 reporter/sequence 去重，Agent 通道优先于 Shell；无正式模型辅助路径。激活只清理 finished：Agent→idle，Shell→无状态；awaitingInput 不因聚焦清除。
- 显示由 status+activityKind+exitStatus 决定，样式另行选择：Agent running/success/failure 默认 Alien，Shell 默认 Robot，等待默认问号但可改 Alien/Robot/Classic；Agent idle 是低透明度静态 Agent；finished 且 exitStatus 缺失映射中性 Shell Finished，即便 activityKind=agent。子代理分支符号独立叠加，不覆盖主符号。
- 正则已确认存在“确认后我写入并校验”漏判；不能由此推定截图模型调用失败。模型/正则来源与回退原因未保留到 UI 或上报，历史根因证据不足。此次未调用模型或运行测试，不声称复现。
- 审计基于当前未提交工作区，已有并发改动；不能等同截图时二进制或 Pi 内存中加载版本。任务只修改自身生命周期记录。

## Plan

1. 交付按来源、优先级、接收端和显示端组织的状态判定说明，并给出代码位置。
2. 列出已确认的识别能力缺口、静默降级、一次性推理和错误语义风险；不把风险描述为截图根因。
3. 若后续授权修复，再对选定问题对齐目标；当前不执行修复。
