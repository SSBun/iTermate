# Replace codexm with native Codex monitoring

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-21 15:09) |
| Artifacts | [Artifacts](../artifacts/replace-codexm-with-native-monitoring/) |
| Kind | Task |

## Scope

Replace both the Codex launch wrapper and the unreliable hook-based Codex status path with passive monitoring of directly launched Codex sessions. Preserve the shared status transport, Pi integration, shell integrations, and unrelated working-tree changes.

## Target
- [x] T1: Enabling the Codex integration no longer installs, exposes, or documents the codexm launch wrapper.
- [x] T2: Sessions started with the original codex command report Codex lifecycle states to iTermate through native Codex integration points.
- [x] T3: Pi and shell monitoring behavior remain unchanged, and the project passes authorized non-test verification.
- [x] T4: Codex monitoring works without installing, trusting, or receiving Codex hooks.
- [x] T5: Existing iTermate-owned Codex hooks are removed during migration, while unrelated third-party hooks remain untouched.
- [x] T6: A directly running native Codex session keeps its Codex identity and Running overlay through nested terminal PTYs and bounded-tail lifecycle gaps instead of falling back to ordinary command status.
- [x] T7: A native Codex session still maps to its rollout and displays status when the filesystem creation time is delayed beyond the process-start matching window but the rollout's own Session timestamp is correct.

## Plan

1. Remove Codex wrapper and hook installation/reporting paths while retaining Pi and Shell transports.
2. Observe direct Codex processes by TTY and map native rollout lifecycle events conservatively onto visible sessions.
3. Migrate existing iTermate-owned hooks, update focused coverage and documentation, then run syntax, generation, build, launch, and diff checks without executing tests.
4. Map confirmed native Codex descendants back to the visible terminal TTY, and use rollout growth to bridge lifecycle events outside the bounded tail so shell fallback cannot replace its identity or Running state.
5. Match rollout candidates using Codex-owned Session timestamps instead of filesystem creation timestamps, then compile a focused delayed-creation regression fixture.

## Task Summary

- [Codex session monitor](../../iTermate/CodexSessionMonitor.swift) and [session store](../../iTermate/ItermBridge.swift): identify original Codex CLI processes by foreground TTY, map root rollouts with first-line Session timestamp and `cwd/source` metadata instead of filesystem creation time, discard partial UTF-8 lines before bounded-tail decoding, and use the same confirmed-state overlay for panel display and menu-bar running counts without displaying or uploading conversation content.
- [Integration manager](../../iTermate/AgentIntegrations.swift): presents Codex monitoring as automatic and migrates only iTermate-owned legacy hooks and wrapper artifacts while preserving unrelated hooks.
- [Bridge](../../iTermateBridge/iTermateBridge.py) and [status reporter](../../integrations/status/iTermate-status.py): remove the obsolete Codex hook ownership/retry state machine; Pi and Shell retain their existing transports.
- [Focused coverage](../../iTermateTests/CodexSessionMonitorTests.swift), [store coverage](../../iTermateTests/ItermBridgeTests.swift), and [migration coverage](../../iTermateTests/AgentIntegrationManagerTests.swift): compile lifecycle parsing, delayed filesystem-creation mapping, UTF-8 boundaries, state preservation, interruption, menu-count overlay, and selective cleanup fixtures.
- [Codex monitoring guide](../../docs/codex-monitoring.md), [English README](../../README.md), [Chinese README](../../README.zh-CN.md), and [Chinese product guide](../../docs/product-introduction.zh-CN.md): document direct command use, passive data sources, migration, and conservative limitations.

## Result

- T1: Settings source presents Codex as Automatic; repository search found no active codexm or launcher installation path, and the previously launched rebuilt app used the original codex command.
- T2: Latest Debug build-for-testing compiled direct TTY/root-rollout mapping, conservative lifecycle state and interruption handling, UTF-8 tail boundaries, and reuse of the Codex overlay for iTerm2 panel/menu-bar running state; tests were not executed.
- T3: Pi remains on its existing transport and the status reporter remains Shell-only; current Python syntax, git diff, and latest Debug build-for-testing checks passed, with test sources compiled but tests not executed.
- T4: Implementation and all documentation consistently describe passive TTY/process observation, first-line cwd/source mapping, bounded local-tail lifecycle use, and no display/upload of conversation content; no Codex hook event/report path remains.
- T5: Prior rebuilt-app launch left 0 iTermate-owned hook entries, preserved 20 third-party entries, and removed the legacy wrapper, marker, and hook files; migration implementation and compiled fixtures remain unchanged.
- T6: Live process ancestry confirmed Codex on inner `/dev/ttys003` and `/dev/ttys056` descends from visible `/dev/ttys002` and `/dev/ttys055`; the compiled monitor probe mapped both outer TTYs and changed `/dev/ttys002` from unknown to running after its already-mapped rollout grew, without reading beyond the 1 MiB tail.
- T6 remediation: TR-11 now retains every confirmed Codex identity/status for two missed scans and only emits interrupted on the third consecutive miss; the focused state-transition fixture compiles and the latest Debug build-for-testing passed without executing tests.
- T6 reset remediation: TR-12 now clears the locked monitor cache when no visible TTY remains and when the Store stops, preventing a reused TTY from inheriting stale Codex state; the stateful fixtures compile the full miss/rediscovery/clear and reset/reuse paths.
- T6 ordering remediation: every dispatched scan now captures a monitor generation and the visible `TTY → Session ID` map; reset invalidates pre-reset scans before cache mutation, and Store completion rejects terminal snapshots that changed while the scan ran.
- T6 accepted-overlay remediation: accepted observations are now bound to their Session ID; incoming iTerm2/Ghostty snapshots invalidate the affected TTY before merging when that ID changes, while preserving unrelated Codex states.
- T6 scoped-drift remediation: an in-flight snapshot mismatch now resets only added, removed, or replacement TTYs, so unrelated terminal churn cannot erase another Codex session's two-miss grace.
- T7: Live diagnosis found /dev/ttys060 and /dev/ttys014 Codex rollouts whose first-line Session timestamps were within 5 seconds of process start while filesystem creation times lagged by 35 and 63 seconds; production matching now uses the Session timestamp, the delayed-creation fixture compiles, and Debug build-for-testing plus git diff --check passed without executing tests.
- Review gate: Passed — Independent Round 17 found no findings on assessment snapshot sha256:305520c1e43694a29602237f72058e0c8cbe2383e71b08668a51877661d0afda, supported T7, and confirmed TR-1 through TR-12 remain resolved; report saved at reviews/round-17.md.
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: The reopened task retains an existing Required review obligation, and rollout selection controls live Codex identity/status across multiple simultaneous sessions where an incorrect timestamp choice can bind the wrong conversation.
- Snapshot: sha256:305520c1e43694a29602237f72058e0c8cbe2383e71b08668a51877661d0afda; monitor=ddbaadf03bfffec52f167aa6be6681739b8d3740f661e74adeb22e5044db2fef; fixture=61b3dadd557ace45393a2667d326cb6467342307c21e20557d00a840697b565f; guide=a77e897cd5c48cf4692f49cbf8f85137cfc3da326c2bc91e449ec2dcaa7f013c
- Evidence: Owner traced the two blank MyTwitter rows to confirmed Codex descendants and rollouts whose Session metadata timestamps were within 5 seconds of process start while APFS creation times lagged 35 and 63 seconds; the three-file fix compiled with Debug build-for-testing and git diff --check passed, with tests not executed.
- Task fingerprint: b305a3e2ee1b1a1b16c5096ea7f6b82ed2da4e784cab0a8bb2ca05068aae785b
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [Round 01](../artifacts/replace-codexm-with-native-monitoring/reviews/round-01.md) | `sha256:AgentIntegrations=6f472a6a;status=e9523405;manager-tests=c8429244;status-tests=a1120e92;docs=f9445083;project=2d026f29;pbx=e7a688a3` | findings: TR-1 |
| 02 | [Round 02](../artifacts/replace-codexm-with-native-monitoring/reviews/round-02.md) | `sha256:AgentIntegrations=6f472a6a;status=e9523405;manager-tests=c8429244;status-tests=a1120e92;docs=f9445083;project=2d026f29;pbx=e7a688a3;aliases=351a3c6c;live-hooks=828b46c9` | findings: TR-3; blocking risk: TR-2 |
| 03 | [Round 03](../artifacts/replace-codexm-with-native-monitoring/reviews/round-03.md) | `sha256:AgentIntegrations=66245ba0;manager-tests=ba392dbc;status=e9523405;status-tests=a1120e92;docs=f9445083;project=2d026f29;pbx=e7a688a3;aliases=351a3c6c;live-hooks=828b46c9` | no blocking findings; TR-1, TR-2, TR-3 resolved |
| 04 | [Round 04](../artifacts/replace-codexm-with-native-monitoring/reviews/round-04.md) | `sha256:f31c0a663c4c02ac68ea656fef944dc97895108192a207ce674079e317b450c3` | findings: TR-4, TR-5, TR-6, TR-7 |
| 05 | [Round 05](../artifacts/replace-codexm-with-native-monitoring/reviews/round-05.md) | `sha256:b7262d0d6b082aab65da56165fa004e8d9f6764126104b5d52cddc0d59e42203` | findings: TR-8; TR-4, TR-5, TR-6, TR-7 resolved |
| 06 | [Round 06](../artifacts/replace-codexm-with-native-monitoring/reviews/round-06.md) | `sha256:e364c91f0cd727a983ae842018d5247f5e689d31ad494c27e4e83ba66fe020a8` | findings: TR-8, TR-9; TR-4, TR-5, TR-6, TR-7 remain resolved |
| 07 | [Round 07](../artifacts/replace-codexm-with-native-monitoring/reviews/round-07.md) | `sha256:1267998ed685507cb352e575cd1cfd5039bf4356ad922707fd3a60f5934673c1` | finding: TR-8; TR-9 resolved; TR-4, TR-5, TR-6, TR-7 remain resolved |
| 08 | [Round 08](../artifacts/replace-codexm-with-native-monitoring/reviews/round-08.md) | `sha256:4ee52ebacd2992e65c254f56b555e44afcb6710a9c77b8967bce761fc572aa2d` | finding: TR-10; TR-4, TR-5, TR-6, TR-7, TR-8, TR-9 resolved |
| 09 | [Round 09](../artifacts/replace-codexm-with-native-monitoring/reviews/round-09.md) | `sha256:0b2f9cf484a674552d9b54584c128c798a576ed43dada10fb248afc133bec3e6` | no findings; TR-4 through TR-10 resolved |
| 10 | [Round 10](../artifacts/replace-codexm-with-native-monitoring/reviews/round-10.md) | `sha256:45f9e7f956f1d36d32d66bc25988654f262a2aed491d7afa5c43ca4e694cb9ae` | finding: TR-11 |
| 11 | [Round 11](../artifacts/replace-codexm-with-native-monitoring/reviews/round-11.md) | `sha256:1751d1f729443687af2ac790572f6141e3eaf079443c4d98525d26ecdcaf4bb5` | findings: TR-11, TR-12; TR-11 substantive progress |
| 12 | [Round 12](../artifacts/replace-codexm-with-native-monitoring/reviews/round-12.md) | `sha256:2663034b0d52ea349b3aee5534a4997a041743250db46d837ee186121ebe2eab` | finding: TR-12; TR-11 resolved, TR-12 substantive progress |
| 13 | [Round 13](../artifacts/replace-codexm-with-native-monitoring/reviews/round-13.md) | `sha256:3758243e0feeab3abc81429ae5b910301059b2510581a2464f11e624e19238f6` | finding: TR-12; generation ordering resolved, accepted-overlay binding missing |
| 14 | [Round 14](../artifacts/replace-codexm-with-native-monitoring/reviews/round-14.md) | `sha256:dd462fc54afa229ad7462c761e6920c72aa3b29a1b9f6ca61d4d91bbb48b212f` | finding: TR-12; accepted binding resolved, generic drift reset over-broad |
| 15 | [Round 15](../artifacts/replace-codexm-with-native-monitoring/reviews/round-15.md) | `sha256:708e89a81672c0d0dd0af4e3a22b084ccc22c1367db710d48ab8e7319a0df269` | invalidated by concurrent Store/Bridge drift; no semantic finding before drift |
| 16 | [Round 16](../artifacts/replace-codexm-with-native-monitoring/reviews/round-16.md) | `sha256:319c57e6c851535c636974f56032c4ef907166acf00aa83c629b73ce50b20120` | no findings; TR-11 and TR-12 resolved |
| 17 | [Round 17](../artifacts/replace-codexm-with-native-monitoring/reviews/round-17.md) | `sha256:305520c1e43694a29602237f72058e0c8cbe2383e71b08668a51877661d0afda` | no findings; T7 supported and TR-1 through TR-12 remain resolved |

## Verification

- Passed: Final scoped hash remained sha256:305520c1e43694a29602237f72058e0c8cbe2383e71b08668a51877661d0afda after independent review; git diff --check passed, and the current production plus fixture sources had already completed Debug xcodebuild build-for-testing successfully without executing tests.
