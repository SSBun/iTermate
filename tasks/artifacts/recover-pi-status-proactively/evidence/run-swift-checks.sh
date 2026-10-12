#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
WORK="$(mktemp -d /tmp/itermate-recovery-checks.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
s = (root/'iTermate/ItermBridge.swift').read_text()
(out/'SnapshotTypes.swift').write_text(s[:s.index('final class ItermStore:')])
s = (root/'iTermate/PiSessionArchives.swift').read_text()
(out/'PiStatusSnapshot.swift').write_text('import Foundation\n'+s[s.index('struct PiStatusSnapshot:'):s.index('struct PiResumeLocation:')])
s = (root/'iTermate/SessionNotifications.swift').read_text()
(out/'CompletionTracker.swift').write_text(s[:s.index('final class SessionNotificationController:')])
s = (root/'iTermateTests/PiStatusRecoveryTests.swift').read_text()
(out/'PiStatusRecoveryTests.swift').write_text(s.replace('@testable import iTermate\n',''))
(out/'main.swift').write_text('import XCTest\nimport Darwin\nlet suite = XCTestSuite(forTestCaseClass: PiStatusRecoveryTests.self)\nsuite.run()\nguard let result = suite.testRun, result.executionCount == 6, result.totalFailureCount == 0 else { exit(1) }\nprint("Standalone recovery XCTest: 6 passed, 0 failures; no App host launched.")\n')
PY
PLATFORM="$(xcrun --show-sdk-platform-path)"
swiftc -I "$PLATFORM/Developer/usr/lib" -L "$PLATFORM/Developer/usr/lib" -lXCTestSwiftSupport \
  -F "$PLATFORM/Developer/Library/Frameworks" -framework XCTest \
  -Xlinker -rpath -Xlinker "$PLATFORM/Developer/Library/Frameworks" \
  -Xlinker -rpath -Xlinker "$PLATFORM/Developer/usr/lib" \
  "$WORK/SnapshotTypes.swift" "$WORK/PiStatusSnapshot.swift" "$WORK/CompletionTracker.swift" \
  "$ROOT/iTermate/TerminalStatusServer.swift" "$WORK/PiStatusRecoveryTests.swift" "$WORK/main.swift" \
  -o "$WORK/run"
"$WORK/run"
