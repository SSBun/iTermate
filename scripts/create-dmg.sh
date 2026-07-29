#!/bin/bash
set -euo pipefail

VERSION=${1:-}
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: $0 <version>" >&2
    exit 2
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DERIVED_DATA="$ROOT/.build/release"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="$ROOT/dist/iTermate-${VERSION}_${TIMESTAMP}"
DMG="$OUTPUT_DIR/iTermate-${VERSION}.dmg"
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

BUILD_ARGS=(
    -project "$ROOT/iTermate.xcodeproj"
    -scheme iTermate
    -configuration Release
    -derivedDataPath "$DERIVED_DATA"
    clean build
)
if [[ ${NO_SIGN:-0} == 1 ]]; then
    BUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi
xcodebuild "${BUILD_ARGS[@]}"

APP="$DERIVED_DATA/Build/Products/Release/iTermate.app"
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
if [[ "$BUILT_VERSION" != "$VERSION" ]]; then
    echo "Built version $BUILT_VERSION does not match requested version $VERSION" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
ditto "$APP" "$STAGING/iTermate.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "iTermate $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
(
    cd "$OUTPUT_DIR"
    shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
)
printf 'DMG: %s\nSHA256: %s\n' "$DMG" "$DMG.sha256"
