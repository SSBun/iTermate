# Task Review — Round 13

- Task: `replace-codexm-with-native-monitoring`
- Round: 13
- Review mode: independent subagent
- Run identity: `/root/nested_codex_status_gate_review`
- Reviewed snapshot: `sha256:3758243e0feeab3abc81429ae5b910301059b2510581a2464f11e624e19238f6`

## Reviewer feedback

Findings:

- TR-12 — Concern — substantive progress, unresolved
  - Location: `iTermate/ItermBridge.swift:708-731,983-1018,1201-1207,1232-1266`; `iTermateTests/ItermBridgeTests.swift:5-37`
  - Issue: Session-identity validation protected in-flight results, but an already accepted observation remained keyed only by TTY and could merge into a replacement Session before the next scan.
  - Impact: Same-TTY reuse could show an ordinary shell as Codex Running through retained misses and briefly as Interrupted.
  - Required outcome: Bind accepted observations to their captured Session ID or invalidate them on an incoming identity-map change before merging; cover accepted observation to replacement Session with immediate absence of stale overlay.

Previous findings:

- TR-11 — resolved.
- TR-12 generation ordering — resolved: reset generation and scan UUID/snapshot checks correctly reject pre-reset mutations and stale completions. Accepted-overlay binding remained unresolved in this round.

Skipped: Tests, builds, App launch, live probing, and GUI verification were not run by the Reviewer. No deadlock or synchronous reentrancy was found.
