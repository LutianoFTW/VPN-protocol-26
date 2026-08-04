#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Open WiFiLocator.xcodeproj in Xcode on a Mac." >&2
  exit 1
fi

DEST="${1:-build}"
mkdir -p "$DEST"

echo "Building WiFiLocator (arm64, macOS)…"
xcodebuild \
  -project WiFiLocator.xcodeproj \
  -scheme WiFiLocator \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DEST" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  build

APP="$DEST/Build/Products/Debug/WiFiLocator.app"
echo "Built: $APP"
file "$APP/Contents/MacOS/WiFiLocator" || true
