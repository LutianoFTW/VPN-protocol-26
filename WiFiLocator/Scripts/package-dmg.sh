#!/usr/bin/env bash
# Build a Release arm64 .app and package it into an installable .dmg
# Must be run on macOS with Xcode installed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${MARKETING_VERSION:-1.0}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
APP_NAME="WiFiLocator"
DISPLAY_NAME="WiFi Locator"
VOL_NAME="WiFi Locator"
DMG_NAME="WiFiLocator-${VERSION}-arm64.dmg"
CONFIGURATION="${CONFIGURATION:-Release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc; set to "Developer ID Application: …" for distribution

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: DMG packaging requires macOS with Xcode (hdiutil / xcodebuild)." >&2
  echo "On this repo, use GitHub Actions → \"Build DMG\" or run this script on a Mac." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Install Xcode from the App Store." >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "error: hdiutil not found (required to create .dmg)." >&2
  exit 1
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
  echo "warning: host arch is $ARCH; still targeting arm64 for Apple Silicon." >&2
fi

echo "==> Cleaning output directories"
rm -rf "$BUILD_DIR" "$DIST_DIR/dmg-root" "$DIST_DIR/staging"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

echo "==> Building $APP_NAME ($CONFIGURATION, arm64)"
xcodebuild \
  -project WiFiLocator.xcodeproj \
  -scheme WiFiLocator \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$BUILD_DIR" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  EXCLUDED_ARCHS='x86_64 i386' \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=NO \
  build

APP_SRC="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_SRC" ]]; then
  echo "error: expected app not found at $APP_SRC" >&2
  exit 1
fi

echo "==> Preparing DMG staging folder"
STAGE="$DIST_DIR/staging"
mkdir -p "$STAGE"
rm -rf "$STAGE/$APP_NAME.app"
cp -R "$APP_SRC" "$STAGE/$APP_NAME.app"

# Ad-hoc or Developer ID re-sign of the copied bundle
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "==> Ad-hoc codesigning .app"
  codesign --force --deep --sign - --options runtime --entitlements WiFiLocator/WiFiLocator.entitlements "$STAGE/$APP_NAME.app" || \
    codesign --force --deep --sign - "$STAGE/$APP_NAME.app"
else
  echo "==> Codesigning with identity: $SIGN_IDENTITY"
  codesign --force --deep --sign "$SIGN_IDENTITY" --options runtime --entitlements WiFiLocator/WiFiLocator.entitlements "$STAGE/$APP_NAME.app"
fi

codesign --verify --verbose=2 "$STAGE/$APP_NAME.app" || true
file "$STAGE/$APP_NAME.app/Contents/MacOS/$APP_NAME" || true

# DMG root: app + Applications shortcut + short install note
DMG_ROOT="$DIST_DIR/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$STAGE/$APP_NAME.app" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

cat > "$DMG_ROOT/Install.txt" <<EOF
$DISPLAY_NAME $VERSION (Apple Silicon)

Install
1. Drag “$APP_NAME” onto the Applications folder.
2. Open it from Applications (or Launchpad).
3. Allow Location Services when prompted (needed to read Wi‑Fi BSSIDs).

Gatekeeper (unsigned / ad-hoc builds)
If macOS blocks the app: right-click the app → Open → Open.
Or: System Settings → Privacy & Security → Open Anyway.

Requirements: macOS 14+ on Apple Silicon (arm64).
EOF

# Optional window layout via AppleScript (best-effort; skipped in CI headless if it fails)
echo "==> Creating compressed UDZO disk image"
TMP_DMG="$DIST_DIR/.tmp-${DMG_NAME}"
FINAL_DMG="$DIST_DIR/$DMG_NAME"
rm -f "$TMP_DMG" "$FINAL_DMG"

hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$TMP_DMG"

# Mount, set Finder view (icon positions), convert to compressed read-only
MOUNT_DIR="$(mktemp -d /tmp/wifilocator-dmg.XXXXXX)"
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG" | awk '/\/Volumes\//{print $1; exit}')"
VOLUME="$(ls -d /Volumes/"$VOL_NAME"* 2>/dev/null | head -1 || true)"

cleanup() {
  hdiutil detach "$DEVICE" -force >/dev/null 2>&1 || true
  [[ -n "${VOLUME:-}" ]] && hdiutil detach "$VOLUME" -force >/dev/null 2>&1 || true
  rm -rf "$MOUNT_DIR"
  rm -f "$TMP_DMG"
}
trap cleanup EXIT

if [[ -n "${VOLUME:-}" && -d "$VOLUME" ]]; then
  echo "==> Setting Finder icon layout"
  # shellcheck disable=SC2086
  osascript <<APPLESCRIPT || true
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "$APP_NAME.app" of container window to {160, 200}
    set position of item "Applications" of container window to {480, 200}
    set position of item "Install.txt" of container window to {320, 360}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
  sync
  hdiutil detach "$DEVICE" -force
  DEVICE=""
  VOLUME=""
else
  echo "warning: could not mount volume for layout polish; continuing with default layout." >&2
  hdiutil detach "$DEVICE" -force || true
  DEVICE=""
fi

hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
hdiutil verify "$FINAL_DMG" >/dev/null
trap - EXIT
rm -f "$TMP_DMG"
rm -rf "$MOUNT_DIR" "$DMG_ROOT"

# Checksum for distribution
(
  cd "$DIST_DIR"
  shasum -a 256 "$DMG_NAME" | tee "$DMG_NAME.sha256"
)

echo
echo "Installable DMG ready:"
echo "  $FINAL_DMG"
echo
echo "Install: open the DMG and drag $APP_NAME into Applications."
