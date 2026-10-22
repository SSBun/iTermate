# 保存全部本地改动并实现紧凑项目面板布局

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-22 14:45) |
| Artifacts | [Artifacts](../artifacts/implement-compact-project-panel/) |
| Kind | Task |

## Scope

仅提交当前工作区既有改动并实现紧凑列表展示；不推送远程、不修改状态判定和终端操作协议、不启动或重启应用、不运行测试。

## Target
- [x] T1: 新布局改动开始前，当前全部本地改动已保存在本地 Git 提交中。
- [x] T2: 面板采用方案一的紧凑项目列表：突出单个选中会话、弱化项目分组、减少重复终端文字并使标题与状态更易对应。
- [x] T3: 保留现有项目与会话操作、真实状态来源及像素动画，不加入待处理聚合区或双栏布局。

## Plan

1. 将全部既有本地改动提交为可恢复基线，记录提交身份。
2. 保留原分组与交互结构，调整分组标题、会话行密度、终端名称和状态布局。
3. 进行源码自检与 Debug 构建，记录视觉验证边界；按实际风险完成独立只读审查和最终验证。

## Decisions

- 既有本地改动已整体提交为 `1a377ecff29d1a024b0d7991b9898ead97e741af`，提交后工作区为空；新布局与该基线独立。
- 内容宽度不足 240pt 时隐藏可见数量、不足 300pt 时隐藏时间文字；状态图标与完整辅助功能名称保留，不改变用户的持久化显示偏好。
- 移除整组焦点背景后，同步删除失效的 Focused Section Opacity 配置、控件及对应测试；不迁移或覆盖用户当前运行配置。
- 离屏预览使用真实 PanelContent 与合成快照，独立可执行入口不创建 AppDelegate、不调用 Store.start，不启动或重启用户应用及 Bridge；不替代真实运行中的交互验证。

## Task Summary

**面板与设置**：[iTermate](../../iTermate/) 改为仅突出选中会话、淡化连接线、紧凑行距与系统分组字体，状态动画紧邻标题；增加明确计数与窄宽度降噪，只简写可确认的默认 shell 标题。移除整组背景及失效的透明度设置，原操作路径和状态来源不变。

**设置测试**：[iTermateTests](../../iTermateTests/) 删除对应已移除设置的过期测试，不运行测试；其余用例未修改。

## Result

- T1: 布局修改前 git add -A 与 commit 成功生成 1a377ecff29d1a024b0d7991b9898ead97e741af，保存全部 525 个变动文件；随后 git status --short 为空。仅保存既有内容，未声称其历史功能全部验证，未推送远程。
- T2: 对照 scope.patch 与原生离屏 preview-dark/light/narrow/wide/tabs/window.png：仅选中行着色，明确会话计数，默认 shell 标题简写而自定义与 Agent 标题保留，状态紧邻标题、行距收紧。180pt 初版时间挤压已修复；最窄长标题仍省略。最终 build-final.log BUILD SUCCEEDED，Swift parse 与 diff --check 通过；未运行测试。
- T3: 对照基线 scope.patch：激活/关闭/折叠/固定收藏/颜色/归档恢复/刷新 action 与状态来源未变，像素动画实现未改；窄宽隐藏时间时保留图标辅助功能标签，无待处理区或双栏。离屏入口不创建 AppDelegate 或启动 Store；processes-before/after.txt 相同、用户 App PID60550 未变。未在真实用户 App 中验证点击悬停、动画时间行为；需用户自行重建运行。首轮旧 Sparkle 缓存绝对路径失效，更换独立缓存后构建成功，未改工程依赖。
- Review gate: Passed — fresh 只读 Reviewer run 0d0bc350-d200-49ee-b958-acaaa7a6d927 完成，第01轮报告已保存并索引，无确认finding或阻塞证据缺口；主会话接收后重算 snapshot.json 所有SHA-256与scope.patch，一致无漂移。真实用户App交互与测试仍未执行。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 会话列表的密度、文字呈现、状态排列与窄宽度响应式条件共同变化，并移除已失效配置；需要独立检查交互保留与布局遗漏。
- Snapshot: sha256:86a7cf5322dc97adc36a45bd2004cf98820bf0f2164c4359151cfc43b6880b88 (tasks/artifacts/implement-compact-project-panel/evidence/snapshot.json)
- Evidence: 任务 Result T1–T3；evidence/scope.patch、六份原生离屏预览、build-final.log、preview-build/render.log、processes-before/after.txt；Swift parse、diff --check、Context validate 通过；未运行测试或真实用户 App 交互。
- Task fingerprint: 5418a64a21e30ebe9fb8f935ee3ee718ebd306dd90bf832424a4409f2ed13753

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/implement-compact-project-panel/reviews/round-01.md) | sha256:86a7cf5322dc97adc36a45bd2004cf98820bf0f2164c4359151cfc43b6880b88 | no blocking findings；主会话重算哈希与差异一致 |

## Verification

- Passed: 审查通过后再次重算全部清单SHA-256与scope.patch，均与86a7cf53…快照一致；第01轮报告链接、快照与none结论一致。最终Debug构建日志成功且源码未漂移，git diff --check、Context validate通过。未运行测试、未启动或重启App/Bridge；真实交互需用户自行重建运行。
