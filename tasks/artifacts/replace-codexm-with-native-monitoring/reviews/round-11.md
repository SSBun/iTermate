# Task Review — Round 11

- Task: `replace-codexm-with-native-monitoring`
- Round: 11
- Review mode: independent subagent
- Run identity: `/root/nested_codex_status_rereview`
- Reviewed snapshot: `sha256:1751d1f729443687af2ac790572f6141e3eaf079443c4d98525d26ecdcaf4bb5`

## Reviewer feedback

Findings:

- TR-11 — Concern — substantive progress
  - Location: `iTermateTests/CodexSessionMonitorTests.swift:62`
  - Issue: The production two-miss grace behavior was statically correct, but the fixture only called a pure helper and did not cover `observations(in:)`, dictionary replacement, cache state, or rediscovery reset.
  - Required outcome: Exercise `running → transient miss → running`, third-miss cleanup, and rediscovery reset through the stateful monitor API.

- TR-12 — Concern — new finding
  - Location: `iTermate/ItermBridge.swift:464,1239`; `iTermate/CodexSessionMonitor.swift:45,96`
  - Issue: When all TTYs became invisible or the Store stopped, the Store cleared only its overlay dictionary and left the monitor caches intact.
  - Impact: A later ordinary shell reusing the TTY could inherit stale Running for two scans and false Interrupted for one scan.
  - Required outcome: Reset monitor state on empty-TTY and stop paths, and cover reset before TTY reuse with a stateful fixture.

Previous finding status: TR-11 had substantive progress; production retention, dictionary replacement, rediscovery reset, and eventual filtering were statically sound.

Skipped: Tests, builds, App launch, and GUI verification were not run by the Reviewer. Remaining risk includes upstream rollout format changes and process trees beyond the bounded limits.
