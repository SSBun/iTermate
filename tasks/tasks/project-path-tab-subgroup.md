# Project Path group mode shows Tab subgroups

Status: Completed (2026-08-19 11:56)
Kind: Task

## Target
- [x] T1: In Project Path session list style, sessions of the same project path that live in the same terminal tab are rendered as a labeled, indented subgroup under the project path section
- [x] T2: Existing Window style Tab subsection behavior and settings remain unchanged
- [x] T3: Project Path tab subgroup title shows Tab N (position in its window) instead of the dynamic tab title
- [x] T4: Project Path group header shows a selection effect (accent tint) when a focused session belongs to that group

## Result

- T1: SessionGrouping.projectPath clusters same-tab sessions via clusteredByTab (ItermBridge.swift); iTermateApp sessionList renders tabHeader + 12pt indent for tabs contributing >=2 sessions to a project path group, gated by settings.showsTabHeaders for both styles; new test testProjectPathClustersSplitPaneSessionsOfSameTab added
- T2: Window style path unchanged: tabHeaderSessions returns sessions for every tab in window mode, existing test testGroupsSessionsByWindowOrExactPath untouched and still compiles
- T3: tabSubgroupTitle(for:) in iTermateApp.swift returns 'Tab N' from window.tabs index in projectPath style; Window style still uses dynamic tabTitle; header text and accessibility label updated
- T4: groupHeader in iTermateApp.swift tints folder icon and title with accentColor when a focused session (isFocused from Bridge global current session) belongs to the group in projectPath style; custom color and Window style unchanged otherwise
- Review gate: Skipped — User did not request adversarial review

## Verification

- Passed: xcodebuild build (macOS arm64) SUCCEEDED after change
