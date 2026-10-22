# Task Review — Round 12

- Task: `replace-codexm-with-native-monitoring`
- Round: 12
- Review mode: independent subagent
- Run identity: `/root/nested_codex_status_final_review`
- Reviewed snapshot: `sha256:2663034b0d52ea349b3aee5534a4997a041743250db46d837ee186121ebe2eab`

## Reviewer feedback

Findings:

- TR-12 — Concern — substantive progress, unresolved
  - Location: `iTermate/ItermBridge.swift:464-470,1232-1257`; `iTermate/CodexSessionMonitor.swift:65-67,127-136`; `iTermateTests/CodexSessionMonitorTests.swift:91-112`
  - Issue: Reset was lock-safe but not ordered against a background scan dispatched before reset.
  - Evidence: If reset acquired the lock first, the older closure could later enter `observations(in:)` and repopulate cache; completion checked only scan UUID, not whether the terminal/session snapshot changed while scanning.
  - Impact: Stop/start, empty-terminal transitions, or rapid same-TTY reuse could still inherit stale Codex state.
  - Required outcome: Add reset generation/cancellation ordering and reject results whose captured visible terminal/session identity is no longer current.

Previous findings:

- TR-11 — resolved: the stateful production-path fixture covers two retained misses, rediscovery reset, third-miss interruption, and fourth-miss overlay removal.
- TR-12 — substantive progress: direct reset and locking were present, but mutual exclusion did not yet provide reset ordering.

Skipped: Tests, builds, App launch, live process probing, and GUI verification were not run by the Reviewer. Remaining risk includes upstream rollout format changes and process trees beyond configured bounds.
