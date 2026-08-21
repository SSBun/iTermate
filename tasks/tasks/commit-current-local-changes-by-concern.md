# 按关注点拆分提交当前本地改动

Status: Completed (2026-08-21 12:02)
Kind: Task

## Scope

- 将现有改动拆为 Project Path Tab 子组、焦点项目背景、逐状态动画设置、工作区 Context 迁移，以及本次任务记录五个关注点。
- 对同一 Swift 文件使用局部暂存拆分功能边界；不修改既有功能内容，不运行测试。

## Target
- [x] T1: 当前所有本地改动均被归入且仅归入一个逻辑清晰的 conventional-style Git 提交。
- [x] T2: 不同功能或关注点保持独立提交，完成后工作区无未提交改动。
- [x] T3: 除本次规范任务记录外，不为提交操作改写既有功能内容。

## Plan

1. 分别提交 Project Path Tab 子组与焦点项目背景的局部 Swift 改动及各自任务记录。
2. 提交逐状态动画设置的源码、编译型检查与任务记录。
3. 单独提交 Context schema 迁移和当前项目模型。
4. 提交本次任务记录，验证提交历史与干净工作区后补全完成状态并 amend。

## Result

- T1: 五个 conventional-style 提交分别覆盖 Project Path Tab 子组、焦点项目背景、逐状态动画设置、Context 迁移和任务记录；git diff-tree 显示每项改动只出现在对应提交。
- T2: git log 与逐提交文件清单确认五个关注点独立；初始任务记录提交后 git status --porcelain 无输出。
- T3: 源码内容均直接取自请求开始时的 working-tree diff；执行期间仅通过局部暂存划分边界，并更新本任务记录。
- Review gate: Skipped — 用户未要求独立 Reviewer 审批。

## Verification

- Passed: git diff --check HEAD~5..HEAD 无输出，git status --porcelain 无输出，任务 check 与 workspace validate 均返回 valid。
