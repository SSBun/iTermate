# 修复 Ctrl+Tab 问号会话优先跳转

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-19 16:59) |
| Artifacts | [Artifacts](../artifacts/fix-question-session-jump/) |
| Kind | Task |

## Target
- [x] T1: Ctrl+Tab 有其他可跳转的问号会话时优先跳到问号会话，没有时沿用普通会话切换。
- [x] T2: 快捷键在达到重置间隔后从最高优先级重新开始。
- [x] T4: 两次 Ctrl+Tab 间隔满两秒即开始新一轮，低于两秒继续当前轮次。
- [x] T3: 普通点击和应用焦点变化不推进或重置轮次，当前会话仍不作为跳转候选。

## Execution Log

### 001 — 调整候选优先级

快捷键进入 Bridge 时，旧逻辑会过滤本轮已访问的问号会话，从而跳到较低优先级。现在有其他问号会话时，访问记录只用于决定先访问哪个问号会话。同步修改设置说明和内置自检的预期。Python 编译、Swift 语法解析和差异检查通过。未运行自检或进行 GUI 验收。

### 002 — 仅快捷键更新轮次

保留三秒按键间隔。只记录由快捷键成功跳到的会话，焦点监听仅继续处理状态确认及快照。更新说明和自检预期。未运行测试或实测快捷键。

### 003 — 缩短重置间隔

按用户要求将阈值改为两秒，更新设置和边界用例。Python、Swift 语法检查及差异检查通过。未运行自检。

## Self Assessment

- Simplicity: A — 删除焦点事件修改轮次和将当前会话补记为访问的逻辑。
- Stability: A — 当前会话仍由候选过滤排除，状态确认和快照路径保留。运行态未验证。
- Completeness: A — 覆盖问号优先、两秒重置及点击不计入轮次。已安装版本未替换。

## Result

- T1: 静态追踪快捷键到 Bridge，确认已访问问号仍优先，当前问号被排除且无其他问号时沿用原循环。Python 编译、Swift 语法解析及 git diff --check 通过。未运行自检或 GUI 验收。
- T2: 静态核对单调时钟及 >= 3 秒边界，在选取候选前清空访问记录。Python 和 Swift 语法检查通过。
- T3: 源码仅在快捷键激活成功后记录目标，焦点监听无轮次写入，当前会话仍排除。未运行测试或 GUI 验收。
- T4: 阈值改为 2，保留 >= 比较及单调时钟。设置文案和用例同步。源码语法检查通过。
- Review gate: Skipped — 局部常量变更及静态验证
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 两秒阈值调整
- Snapshot: snapshot:tasks/artifacts/fix-question-session-jump/evidence/a48ab61a31d65d742512010b85b60f6d35ab81e7aebde38bcbe80c49823822cb.json#a48ab61a31d65d742512010b85b60f6d35ab81e7aebde38bcbe80c49823822cb
- Evidence: T4 和执行日志
- Result clarity: 满两秒重置
- Bounded impact: 快捷键计时、说明和边界用例
- Low risk: 单一常量和既有比较
- Sufficient verification: 静态核对、语法与差异检查
- Task fingerprint: 4bbcdf366b352f7475b4645e26d70161257b0eec7597f0b1276ced05d9b4de20

## Verification

- Passed: 语法与差异检查通过；未运行测试或 GUI 验收
