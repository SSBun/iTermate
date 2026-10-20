# 将侧边栏中同一 Tab 的会话排列在一起

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-20 11:40) |
| Kind | Task |

## Scope

仅调整侧边栏同项目内的 Tab 会话编排；保留 Tab 标题开关、折叠、焦点、激活及关闭操作。不改 iTerm2 布局、Bridge 协议或用户安装态。

## Plan

1. 核对现有分组模型、渲染层和实时快照的 Tab 归属。
2. 将同一 Tab 的行放入具有稳定 Tab 身份的独立渲染容器，沿用原有会话操作。
3. 完成 Swift 解析、Debug 构建及改动检查，说明实际 UI 验证边界。

## Decisions

- 现有 `SessionGrouping` 已按 Tab 聚类，但 UI 使用项目级平铺的会话 ForEach。本次只补齐渲染层的 Tab 边界，不重复实现排序规则。
- 读取实时 Bridge 快照及 iTerm2 AppleScript 层级时，截图中三个 Pi 分屏已不在当前布局；无法复现截图瞬间的穿插原因。不将模型结果当作真实窗口验证，不启动或重启 App/Bridge。
- 未获执行测试授权，本次不运行单元测试或项目测试套件。

## Task Summary

**会话列表**，组件目录 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/)，以首次出现顺序提取唯一 Tab ID，每个 Tab 使用独立 VStack 容器承载标题及所有会话；保留原有标题开关、折叠、行身份及动作，移除平铺行的 startsTab 边界判断。

**会话分组验证用例**，组件目录 ["/Users/caishilin/Desktop/personal/iTermate/iTermateTests/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests/)，将原有标题边界断言改为 Tab ID 断言，并新增三条同 Tab 会话与另一 Tab 穿插输入的区块顺序用例；仅更新源码，未执行测试。

## Target
- [x] T1: 左侧会话列表在现有项目分组内，将属于同一个 iTerm2 Tab 的会话连续排列，不再被其他 Tab 的会话穿插。
- [x] T2: 仅调整侧边栏展示顺序，不改变 iTerm2 的实际 Tab、分屏布局或会话归属。

## Result

- T1: 源码自检确认：唯一 tabIDs 按首次出现顺序生成，每个 tabID 的 sessions(inTab:) 全部位于单独 VStack 和内部 ForEach，标题开关不影响区块边界；三同 Tab 与另一 Tab 穿插的回归用例已写入但未运行。swiftc -parse 和隔离目录的 xcodebuild Debug build 通过。未复现截图瞬间，也未验证运行中 UI。
- T2: 对比修改前副本确认只改 SessionListGroup 展示派生值、PanelContent 遍历结构及验证用例；Bridge/Python 和激活/关闭动作未变。检查 App PID 49214、Bridge PID 49365 启动时间保持 11:35:49、11:35:51；未启动、重启或覆盖安装态。git diff --check 与 Context validate 通过。
- Review gate: Skipped — R1 四项依据已记录：稳定 Tab 容器的纯展示调整，源码结构、动作保持及 Debug 编译均已检查；无独立审查义务，未声称运行 UI 或测试通过。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅改变会话展示的分层容器，Tab 归属及操作不变，区块内不会混入其他 Tab 的行。
- Snapshot: sha256:ItermBridge=bb30355598ee2f75d9a639bda81a30728d635966d8ed261a2868dce085b49cba;iTermateApp=03fcbbb5a60261982642c4945eabd2051906fe4a9424812d93ef72cca2773cb9;ItermBridgeTests=216920786cbd340449c95b7dc55371a7d6aa2eb8ca8fccdd62779f462897258d
- Evidence: T1/T2 Result；Swift 解析通过；隔离 Debug 构建 BUILD SUCCEEDED；源码及动作对比；未执行测试或运行 UI。
- Result clarity: 同项目内同 Tab 连续呈现，保留标题开关和现有动作；用户已确认该目标。
- Bounded impact: 仅分组派生属性和 SwiftUI 遍历层级；同一 Tab 的会话按原顺序筛选；不更改数据源、目录归属或布局操作。
- Low risk: 展示层低风险且可恢复；未修改授权、持久化、终端布局或关闭语义，原行标识和焦点字段保留。
- Sufficient verification: 直接对比源码树可确认 Tab VStack 内只遍历该 Tab 的全部会话，唯一 ID 保留首次顺序；Swift 解析与完整 Debug 构建通过；实际 UI 未观察，测试未运行。
- Task fingerprint: 64b5271c49edf5fbdada59c219a7d03c8fe3a846de8e2a26bc85bb3f3cd032a1

## Verification

- Passed: 终验：三个源码 SHA256 与当前 R1 assessment 一致；隔离 Debug build 再次 BUILD SUCCEEDED；swiftc -parse、git diff --check 通过；静态分组结构及原动作自检通过。测试未运行，实际截图场景未验证，用户需自行重新构建并运行 App。
