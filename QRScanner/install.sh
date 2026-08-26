#!/usr/bin/env bash
# Build and install QR Scanner on this Mac (requires Xcode).
# Continuity Camera: connect iPhone via USB-C, unlock both devices, then pick your iPhone in the Camera menu.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT/QRScanner.xcodeproj"
SCHEME="QRScanner"
CONFIG="${1:-Release}"
DERIVED="$ROOT/.build"
APP_NAME="QRScanner.app"
INSTALL_DIR="${HOME}/Applications"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Install Xcode from the Mac App Store, then re-run."
  exit 1
fi

echo "==> Building $SCHEME ($CONFIG)…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

BUILT_APP="$(find "$DERIVED/Build/Products" -name "$APP_NAME" -type d | head -n 1)"
if [[ -z "$BUILT_APP" ]]; then
  echo "error: built app not found under $DERIVED"
  exit 1
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$BUILT_APP" "$INSTALL_DIR/$APP_NAME"

echo "==> Installed to $INSTALL_DIR/$APP_NAME"
echo "==> Launching…"
open "$INSTALL_DIR/$APP_NAME"

cat <<EOF

Done.
If Continuity Camera does not appear:
  1. Connect iPhone to Mac with USB-C
  2. Unlock iPhone and Mac; trust the computer if prompted
  3. On iPhone: Settings → General → AirPlay & Continuity → Continuity Camera (on)
  4. In QR Scanner, choose your iPhone from the Camera picker
  5. Allow Camera access when macOS asks

EOF
