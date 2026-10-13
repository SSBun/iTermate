#!/usr/bin/env bash
set -euo pipefail

# 从任务证据目录定位仓库；仅构建，不启动 App 或 Bridge。
EVIDENCE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$EVIDENCE/../../../.." && pwd)"
cd "$ROOT"
BUILD="$ROOT/.build/live-pi-task-summary"
SDK_ROOT="$(npm root -g)"
PLATFORM="$(xcrun --sdk macosx --show-sdk-platform-path)"
PRODUCTS="$BUILD/Build/Products/Debug"

tsc --noEmit --target ESNext --module ESNext --moduleResolution Bundler --skipLibCheck \
  --baseUrl "$SDK_ROOT" --typeRoots "$SDK_ROOT/@earendil-works/pi-coding-agent/node_modules/@types" \
  integrations/pi/iTermate-integration.ts integrations/pi/task-summary.test.ts integrations/pi/archive-summary.test.ts \
  > "$EVIDENCE/typecheck.log" 2>&1
tsx --test integrations/pi/*.test.ts > "$EVIDENCE/typescript-tests.log" 2>&1
node --experimental-vm-modules --test integrations/pi/*.test.mjs > "$EVIDENCE/lifecycle-tests.log" 2>&1
xcodebuild -project iTermate.xcodeproj -scheme iTermate -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$BUILD" build-for-testing \
  > "$EVIDENCE/build.log" 2>&1

# 链接工程实际构建的 debug dylib，不调用 App 的 main，不使用会启动 App 的 XCTest 宿主。
xcrun swiftc -swift-version 5 -I "$PRODUCTS" -F "$PRODUCTS" \
  -F "$PLATFORM/Developer/Library/Frameworks" -I "$PLATFORM/Developer/usr/lib" -L "$PLATFORM/Developer/usr/lib" \
  -Xlinker -rpath -Xlinker "$PRODUCTS/iTermate.app/Contents/MacOS" \
  -Xlinker -rpath -Xlinker "$PRODUCTS" \
  -Xlinker -rpath -Xlinker "$PLATFORM/Developer/Library/Frameworks" \
  -Xlinker -rpath -Xlinker "$PLATFORM/Developer/usr/lib" \
  "$PRODUCTS/iTermate.app/Contents/MacOS/iTermate.debug.dylib" \
  iTermateTests/PiSessionArchiveTests.swift iTermateTests/PiStatusRecoveryTests.swift "$EVIDENCE/main.swift" \
  -o "$BUILD/summary-tests" > "$EVIDENCE/native-test-build.log" 2>&1
LLVM_PROFILE_FILE="$BUILD/test-%p.profraw" \
  DYLD_FRAMEWORK_PATH="$PLATFORM/Developer/Library/PrivateFrameworks:$PLATFORM/Developer/Library/Frameworks" \
  "$BUILD/summary-tests" > "$EVIDENCE/swift-tests.log" 2>&1

git diff --check > "$EVIDENCE/diff-check.log" 2>&1
printf 'TypeScript、Pi lifecycle、Swift 测试及工程构建完成。\n'
tail -8 "$EVIDENCE/typescript-tests.log"
tail -8 "$EVIDENCE/lifecycle-tests.log"
tail -3 "$EVIDENCE/swift-tests.log"
