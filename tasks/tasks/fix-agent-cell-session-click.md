# 修复 Agent 单元格点击切换不稳定

| Field | Value |
| --- | --- |
| Status | Blocked (2026-11-02 16:56) |
| Kind | Task |

## Plan

1. 用户自行重新构建并运行，核对 Agent 行右侧空白区域的上、中、下部点击，以及运行、等待和完成等状态下的图标点击。
2. 实际交互确认后完成结果风险评估与任务验收；若仍漏点击，再检查动态视图身份与首击行为，不预先修改未证实的原因。

## Execution Log

### 001 — 点击链路初查

单元格名称和右侧空白分别由两个激活 Button 处理，内部间距为 8pt；状态图标在 finished/awaitingInput 时只调用 markSessionIdle，其他状态不是按钮。整行显式身份包含名称、焦点和状态等动态字段，存在按下与松开之间重建的风险，但尚未实际复现。Store.activate 的 Bridge 错误未显示。以上为源码观察，不足以确认用户当前症状的根因；未修改产品代码。

### 002 — 修正空白标签命中范围

用户确认点击的是空白区域。原激活按钮的 maxWidth frame 位于 Button 外部；内部标签仅含 Spacer 时高度来自 12pt/8pt 的垂直 padding，未覆盖 32pt/28pt 的行高。将宽度 frame 移至标签内部，并设置与关闭按钮一致的最低高度，在 frame 后应用 contentShape。没有修改状态图标、关闭动作、动态行身份或 Bridge。

独立 DerivedData 的 Debug 构建通过（xcodebuild build，11.107 秒）；git diff --check 通过。没有启动或重启 App/Bridge，也没有运行测试。构建不证明真实点击行为，T1 保持未完成，等待用户实际运行验证。

### 003 — 状态图标统一激活会话

用户新增要求：状态图标也应切换 Session。所有可见状态图标改为调用既有 store.activate 的 plain Button，不再区分可清除状态与只读状态。保留 Canvas 动画、状态辅助功能值及关闭按钮，更新图标提示和辅助功能名称为激活操作。独立 Debug 构建通过（4.912 秒），git diff --check 通过；未运行测试、未启动 App。已更新 Context 中的旧点击规则。markSessionIdle 仍有现有测试调用且其持久化机制不属于本次清理范围，未扩展删除。

## Task Summary

**浮动面板**：[/Users/caishilin/Desktop/personal/iTermate/iTermate](file:///Users/caishilin/Desktop/personal/iTermate/iTermate) 将空白激活按钮的扩展布局移入标签，使矩形点击范围至少覆盖原有行高；状态图标统一使用会话激活按钮，保留动画并更新操作提示。

## Self Assessment

- 目标覆盖：3/5，源码针对用户确认的空白区域修正，实际交互待核对。
- 正确性：3/5，Debug 构建通过，未证明真实环境不再漏点击。
- 范围控制：5/5，仅调整空白按钮命中范围、状态按钮动作及相应 Context。
- 可维护性：5/5，使用原生 frame/contentShape，无新增手势或重试机制。
- 验证充分性：2/5，构建和 diff 检查通过；未运行测试，未进行真实 UI 验证。

## Target

- [ ] T1: Agent 单元格点击切换 Session 偶发不响应的问题得到定位并修复，保留动画与关闭操作
- [ ] T2: 所有可见状态图标点击均切换对应 Session，沿用现有激活语义而非单独清除状态

## Block

- Reason: 源码及 Debug 构建已更新，但空白区域与状态图标的真实点击效果尚未经用户运行确认。
- Unblock when: 用户自行重新构建并运行后反馈点击结果；不由 Agent 主动重启 App 或 Bridge。
