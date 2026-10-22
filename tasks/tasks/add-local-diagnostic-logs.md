# Add local diagnostic logs

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 14:49) |
| Artifacts | [Artifacts](../artifacts/add-local-diagnostic-logs/) |
| Kind | Task |

## Target
- [x] T1: Handled session-title generation failures are recorded in privacy-safe local log files with enough context to diagnose the failure category.
- [x] T2: The About page provides a visible action that lets the user access those local log files.
- [x] T3: Existing iTermate behavior remains unchanged apart from diagnostic recording and log access.

## Scope

Include the Pi live-session title generation failure path and the macOS About settings page. Exclude conversation content, generated model output, credentials, remote reporting, analytics, and unrelated error paths.

## Plan

1. Add a bounded local diagnostic writer at the handled session-title failure boundary.
2. Add a native About action that reveals the diagnostic log directory.
3. Verify TypeScript, Swift parsing, a non-launching Debug build, and the final diff without running tests or replacing the user's running app.

## Task Summary

**Pi integration**: [integrations/pi](../../integrations/pi/) now appends sanitized session-title generation failure records to a private, size-bounded JSON-lines pair uniquely owned by each live Pi process; writers prune pairs whose owning PID has exited, preventing cross-process rotation races and lifetime accumulation while preserving cancellation, retry, fallback, and manual-refresh behavior.

**macOS app**: [iTermate](../../iTermate/) adds a Diagnostics section to About with a native action that creates the private log directory when needed and opens it in Finder, reporting any access failure inline.

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/add-local-diagnostic-logs/reviews/round-01.md) | `sha256:pi=1d7ad262d6f10e9d69517d950b03e4b0f0bb82a2a9915ad1c2ff6bef64030f94;settings=8ed13c98122de9b3b848c5f8007300207877709d254b5cafbb4074283bc57e7e` | findings: TR-1 |
| 02 | [Round 02](../artifacts/add-local-diagnostic-logs/reviews/round-02.md) | `sha256:pi=55a0f99447183c0f5da559e57e7dd0e599827c0089213e6e539b8207f69401d9;settings=8ed13c98122de9b3b848c5f8007300207877709d254b5cafbb4074283bc57e7e` | findings: TR-2; TR-1 resolved |
| 03 | [Round 03](../artifacts/add-local-diagnostic-logs/reviews/round-03.md) | `sha256:pi=657c77b5909cfe1533f89d1209024a04ae1f0c7564e2a33c8a7f21addd3d4b10;settings=8ed13c98122de9b3b848c5f8007300207877709d254b5cafbb4074283bc57e7e` | findings: TR-1; TR-2 resolved |
| 04 | [Round 04](../artifacts/add-local-diagnostic-logs/reviews/round-04.md) | `sha256:pi=f608e9df5dc9f1ce8dc456e77dd092517adc5e4b4c0910be9238168b1cde249c;settings=8ed13c98122de9b3b848c5f8007300207877709d254b5cafbb4074283bc57e7e` | no blocking findings; TR-1 and TR-2 resolved |

## Result

- T1: Inspected the current Pi failure path: each live Pi process writes only sanitized fixed metadata to a unique UUID/PID current/previous JSONL pair under ~/Library/Logs/iTermate; each file rotates at 1 MiB with 0700/0600 modes. Before each write it removes matching pairs only when their owning PID has exited, avoiding shared rotation and repeated-lifetime accumulation. Strict TypeScript and Debug build passed.
- T2: Inspected AboutSettingsView: the Diagnostics button creates/locks the shared directory, opens it with NSWorkspace, and shows an inline error on failure. swiftc parse and Debug build passed; live Finder interaction was not launched.
- T3: Compared updateTaskSummary before/after: cancellations/supersession remain unlogged, manual failures rethrow, automatic failures retain notification/retry/fallback, and diagnostic cleanup/write failures are contained. TypeScript, Swift parse, Debug build, and diff check passed; tests/live UI not run.
- Review gate: Passed — Independent round 04 reviewed the exact current snapshot, found no blocking findings, and verified TR-1/TR-2 resolved; report saved and indexed at reviews/round-04.md.
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: Persistent multi-process diagnostic metadata and filesystem access remain privacy/retention sensitive, so the existing independent review obligation must verify unique ownership, exited-owner pruning, permissions, and preserved behavior.
- Snapshot: sha256:pi=f608e9df5dc9f1ce8dc456e77dd092517adc5e4b4c0910be9238168b1cde249c;settings=8ed13c98122de9b3b848c5f8007300207877709d254b5cafbb4074283bc57e7e
- Evidence: T1-T3 Result; TR-1/TR-2 addressed with unique per-process pairs and exited-PID pruning; strict TypeScript, Swift parse, Debug build, diff check passed; tests/live UI not run.
- Task fingerprint: 84c457b368dce09f73395e360486b865c7339142dfc4e8edbdcf7812753575f6

## Verification

- Passed: Final reviewed snapshot: sha256:pi=f608e9df5dc9f1ce8dc456e77dd092517adc5e4b4c0910be9238168b1cde249c;settings=8ed13c98122de9b3b848c5f8007300207877709d254b5cafbb4074283bc57e7e. TypeScript compilation passed; Swift parse passed; unsigned macOS Debug build passed; git diff --check passed; task context validation passed. Independent R2 review round 04 reported no findings and resolved TR-1/TR-2. Tests and live UI/Finder validation were not run.
