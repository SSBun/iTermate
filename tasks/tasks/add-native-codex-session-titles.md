# Add automatic titles for native Codex sessions

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 16:13) |
| Artifacts | [Artifacts](../artifacts/add-native-codex-session-titles/) |
| Kind | Task |

## Target
- [x] T1: A directly launched native Codex session automatically receives a concise session title through the same user-visible title behavior as Pi.
- [x] T2: Automatic Codex titles require no codex wrapper or hooks and do not change existing Pi or shell title behavior.
- [x] T3: Refresh Session Title is always enabled for title-capable Pi and native Codex sessions, and invoking it refreshes the title for the selected Session without cross-writing another Session.

## Scope

- Extend the passive Codex rollout observation with a bounded excerpt of visible user and assistant messages plus the native Codex process identity.
- Generate titles only after a completed Codex turn, using the existing saved local Ollama model selection and the same title prompt as Pi.
- Bind every asynchronous title result to the Codex process, TTY, and terminal Session ID before displaying it in the iTermate panel.
- Preserve the existing Pi title overlay and ordinary terminal names; do not rename the underlying terminal Session.
- Update the native Codex monitoring documentation to describe title generation and its local-data boundary.
- Keep manual title refresh available for identified Pi and native Codex Sessions; ordinary Shell Sessions remain unchanged.

## Plan

1. Parse a bounded recent conversation excerpt while reading the already-mapped rollout tail.
2. Add local title generation to `LocalLLMService` and inject it into `ItermStore`.
3. Cache and display titles with process/TTY/Session validation and bounded automatic retries.
4. Add focused parser and overlay coverage, update documentation, and run non-test build/static checks.
5. Route the always-enabled title menu to Pi or native Codex and preserve per-request Session ownership during manual refresh.

## Task Summary

**Native macOS app** ([iTermate](../../iTermate/)) now derives bounded visible Codex conversation excerpts from mapped native rollouts, generates titles with the selected local Ollama model, keeps manual refresh available for identified Pi and Codex Sessions, and overlays results only after process, TTY, terminal Session, excerpt, and request ownership validation.

**Focused test coverage** ([iTermateTests](../../iTermateTests/)) covers visible-message filtering, Codex title overlay behavior, and running-state manual refresh where a late superseded result cannot replace or detach the newer request.

**User documentation** ([Codex monitoring](../../docs/codex-monitoring.md), [English README](../../README.md), [Chinese README](../../README.zh-CN.md)) documents automatic local title generation, bounded data use, retry behavior, and the panel-only title boundary.

## Result

- [x] T1: Native Codex rollout observation now supplies a bounded recent conversation excerpt, and iTermate generates a concise title after each completed turn with the selected local Ollama model before overlaying it in the Session list.
- [x] T2: Title requests remain passive and local, require no wrapper or hooks, validate process/TTY/terminal Session identity before writeback, and leave Pi plus ordinary shell title behavior unchanged.
- T1: CodexSessionMonitor parses a bounded recent visible user/assistant excerpt from the mapped rollout; ItermStore schedules local title generation after task_complete and overlays the returned title in the corresponding session name. Debug build and build-for-testing succeeded.
- T2: Implementation reuses passive native rollout/process observation and selected loopback Ollama model, performs process+TTY+terminal Session+excerpt+request ownership checks before writeback, and changes only the Codex overlay path; no wrapper/hooks or Pi/shell title logic were added.
- T3: Context-menu routing keeps Refresh Session Title enabled for identified native Codex and live title-capable Pi sessions while ordinary shells remain disabled; the controlled async Store test compiles under build-for-testing and covers running-state refresh plus superseded-request ownership; git diff --check and build-for-testing passed without executing tests.
- Review gate: Passed — Fresh independent Round 04 matched all 11 scoped hashes, found no Critical Findings or Concerns, and explicitly resolved TR-2 using the controlled running-state replacement-request test and implementation ownership guards.
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: Always-available manual refresh adds an asynchronous title request path that can replace active requests and accept running Codex state, requiring independent review of session ownership and preserved Pi/shell behavior.
- Snapshot: sha256-manifest:ca3283a3,86d6845b,c07868cb,8fd511cd,560c1920,26c2958f,0a3fd6ab,dd92e7bc,32317950,e3878875,4a2f2614
- Evidence: Self-check traced native Codex and Pi menu capability routing, ordinary-shell disabling, running-state completion validation, process/TTY/terminal Session/excerpt/request ownership, and replacement cleanup. A focused controlled async Store test now covers a late superseded result while the replacement remains owner; git diff --check and build-for-testing passed. Tests and live app/Ollama execution were not run.
- Task fingerprint: 21b4a74d11e98e308231adfcf7bdace28bd9dc2f6c7ebf6c83bfbe969178b83d
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/add-native-codex-session-titles/reviews/round-01.md) | `sha256-manifest:ca3283a3,a30d4b1d,c07868cb,e2858022,26c2958f,299f9338,7fdbff10,e3878875,4a2f2614` | findings: TR-1 |
| 02 | [Round 02](../artifacts/add-native-codex-session-titles/reviews/round-02.md) | `sha256-manifest:ca3283a3,1168fa82,c07868cb,e2858022,26c2958f,299f9338,7fdbff10,e3878875,4a2f2614` | no blocking findings; TR-1 resolved |
| 03 | [Round 03](../artifacts/add-native-codex-session-titles/reviews/round-03.md) | `sha256-manifest:ca3283a3,18c8b404,c07868cb,8fd511cd,560c1920,26c2958f,a5b14edf,dd92e7bc,32317950,e3878875,4a2f2614` | findings: TR-2 |
| 04 | [Round 04](../artifacts/add-native-codex-session-titles/reviews/round-04.md) | `sha256-manifest:ca3283a3,86d6845b,c07868cb,8fd511cd,560c1920,26c2958f,0a3fd6ab,dd92e7bc,32317950,e3878875,4a2f2614` | no blocking findings; TR-2 resolved |

## Verification

- Passed: Final scoped hashes still match independently reviewed Round 04; git diff --check passes; the post-remediation Debug build-for-testing succeeded and compiled the focused async test. Unit tests and live app/Ollama execution were not run.
