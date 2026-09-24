# 记录发布签名限制的长期接受规则

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-24 15:26) |
| Kind | Task |

## Target
- [x] T1: 项目规则记录用户长期接受 ad hoc 签名及未经 Apple 公证的限制，不再仅为此重复询问，仍如实披露并保留远端发布确认。

## Result

- T1: .agents/agent-rules.md 已新增长期接受 ad hoc/未公证限制、不再重复询问的英文规则，保留准确披露及具体远端发布确认。原图标规则完整保留，hook active，实际注入输出包含两条规则。
- Review gate: Skipped — R1，直接规则文本及加载链检查足够，无独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 直接记录用户明确长期偏好，不更改签名机制或免除远端发布确认。
- Snapshot: sha256:55a855d6e9c5875becb63328dfd05a7d2767fc0020701f41064279934d011148 .agents/agent-rules.md
- Evidence: 逐字核对、hook 注入及 diff --check 通过。
- Result clarity: 仅取消已明确接受的签名限制重复询问。
- Bounded impact: 仅 iTermate 项目发布规则。
- Low risk: 保留事实披露与远端发布门禁，不修改代码或凭据。
- Sufficient verification: 实际读取器输出含新规则，原规则未变。
- Task fingerprint: 4c751f740eac94777ac5de9c8fbd61e82a7942c50c57f43f0a30ee9e36d479d1

## Verification

- Passed: 文件摘要与 assessment 一致，实际 hook 输出包含新规则；未运行测试。
