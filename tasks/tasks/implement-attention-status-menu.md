# 实现新版菜单栏会话状态面板

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-28 17:17) |
| Artifacts | [Artifacts](../artifacts/implement-attention-status-menu/) |
| Kind | Task |

## Scope

将已确认单页原型落实为原生 MenuBarExtra 面板，使用现有 Store/Bridge 和 Pi 标题。仅本地源码及工程文件改动；不新增桌面待回复通知，不启动、重启或安装 App，不覆盖其他任务修改的 Bridge、Pi 集成或快捷键；仅在Bridge中增加菜单专用无确认激活及焦点确认保护，保留并发修改。未知生命周期不能猜为空闲；普通 Shell 不进入 Agent 列表。

## Plan

1. 建立菜单状态投影与完成已读语义，准确复用真实会话身份和异步激活确认。
2. 实现紧凑原生菜单、四分类、固定滚动区域、批量已读和像素Canvas动画，保留收藏与设置退出。
3. 生成工程，执行隔离产物路径的 Debug 编译与源码检查，不运行测试、不启动App；维护相关Context并执行R2独立只读审查。

## Decisions

- 最低系统macOS13，保留现有 MenuBarExtra(.window) 原生材质，不把HTML背景硬编码进App。
- 菜单不呈现虚构问题正文，只显示真实会话标题、状态与项目。原生应用现有文案为英文，沿用英文UI。
- 读状态由Store持有，菜单重开不会重置；已读不改变底层生命周期或统计。运行/等待/新完成使旧完成展示失效。
- 初次可用快照选择待回复、失败、未读完成、全部；用户切换后保持所选分类。
- 构建入口已确认iTermate共享scheme；Reviewer工具列表可用且只读，后续使用fresh上下文与运行时模型配置。
- 应用运行及真实菜单视觉需用户自行运行新版验证；本次只做编译和独立源码审查，不声称已验证实时窗口。

## Task Summary

**原生菜单与Store**：在 ["/Users/caishilin/Desktop/personal/iTermate/iTermate/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate/) 新增会话分类列表和Canvas状态图标，收紧状态概览；Store新增非运行Agent投影、按观察身份的已读记录与激活回调校验，保留真实生命周期和统计入口。

**菜单激活Bridge**：在 ["/Users/caishilin/Desktop/personal/iTermate/iTermateBridge/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateBridge/) 新增菜单专用无已读副作用的激活动作及焦点旁路保护，补充旧A/新B时序回归用例源码；保留快捷键等其他任务的既有改动。

**回归用例**：在 ["/Users/caishilin/Desktop/personal/iTermate/iTermateTests/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermateTests/) 新增菜单分类、完成确认、失联恢复和过期选择的用例源码。

**工程引用**：通过现有XcodeGen配置重新生成 ["/Users/caishilin/Desktop/personal/iTermate/iTermate.xcodeproj/"](file:///Users/caishilin/Desktop/personal/iTermate/iTermate.xcodeproj/) 的新增源码和用例引用。

## Target
- [x] T1: 原生菜单栏面板采用已确认原型的紧凑概览、全部/待回复/未读完成/失败分类、固定高度滚动与收藏设置退出入口。
- [x] T2: 以真实Agent会话状态展示分类和数量；全部包含非运行会话，已读完成仍保留；点击准确激活，单条及批量已读不清除待回复或失败，不更改完成统计。
- [x] T3: 保留原生设置和连接反馈，状态图标采用Canvas动画；完成允许的编译验证与独立审查，不启动或替换用户正在运行的App。

## Result

- T1: 源码实现紧凑统计、四分类、248pt固定列表、收藏设置退出；Debug及测试bundle编译成功。原生菜单未启动，真实视觉和输入操作保留人工验证限制。
- T2: TR-1修复：菜单专用无确认Bridge激活与Bridge/Codex焦点保护；Store仅确认捕获身份。Swift用例编译通过，Python语法检查通过，新A/B时序用例已编写未执行；不宣称实时跳转已实测。
- T3: 修复后App和测试bundle编译成功（8.573秒），Python ast.parse、diff检查通过；Canvas和减少动态效果保持。不运行测试或启动App；独立复审待完成。
- Review gate: Passed — 第二轮fresh只读Reviewer无阻断发现，TR-1源码层面resolved；主Agent已check-evidence验证当前十文件快照与报告；运行限制保持披露。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 状态投影和跨进程异步激活确认，修复后需独立复核TR-1及回归。
- Snapshot: snapshot:tasks/artifacts/implement-attention-status-menu/evidence/2755adde25cff78c31d34fd6c2878a04084125cc8d320d6854133e358e7d8363.json#2755adde25cff78c31d34fd6c2878a04084125cc8d320d6854133e358e7d8363
- Evidence: Result T1–T3和build.md记录当前编译、语法检查、源码自查与未运行限制。
- Task fingerprint: b448bf62283a750aedec068f5679327ce84999cc2e8bc7744b6dd798cd4a591a
## Review Reports

- Schema: task-review-reports/v1

| Round | Report | Snapshot | Outcome | SHA256 |
| --- | --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/implement-attention-status-menu/reviews/round-01.md) | snapshot:tasks/artifacts/implement-attention-status-menu/evidence/d5a2b58c3849774a27a8facf772ce1e8ea4301070969b118bd40571c59007ad8.json#d5a2b58c3849774a27a8facf772ce1e8ea4301070969b118bd40571c59007ad8 | findings | 44596d1fc520c782e30c380abf13ca3a0e3f5a5c62ec067fed45d86ae1bd884c |
| 02 | [Round 02](../artifacts/implement-attention-status-menu/reviews/round-02.md) | snapshot:tasks/artifacts/implement-attention-status-menu/evidence/2755adde25cff78c31d34fd6c2878a04084125cc8d320d6854133e358e7d8363.json#2755adde25cff78c31d34fd6c2878a04084125cc8d320d6854133e358e7d8363 | no blocking findings | 8584318eabcec5e2884413768c203928c50c4da6414d8fd4a6548cf7ebd0b8ac |

## Verification

- Passed: 终态重新核对十文件快照及两轮报告，check-evidence verified；git diff --check及Python语法检查通过，当前源码与成功build-for-testing版本一致。TR-1已独立复核解决；未执行测试或启动App，原生视觉及实时焦点仍需用户自行运行验证。
