#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-Debug}"
DEST="${1:-build}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Open WiFiLocator.xcodeproj in Xcode on a Mac." >&2
  exit 1
fi

mkdir -p "$DEST"

echo "Building WiFiLocator ($CONFIGURATION, arm64)…"
xcodebuild \
  -project WiFiLocator.xcodeproj \
  -scheme WiFiLocator \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DEST" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  build

APP="$DEST/Build/Products/$CONFIGURATION/WiFiLocator.app"
echo "Built: $APP"
file "$APP/Contents/MacOS/WiFiLocator" || true
