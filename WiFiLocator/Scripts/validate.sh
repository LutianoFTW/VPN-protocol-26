#!/usr/bin/env bash
# Lightweight structural validation that can run on Linux CI / cloud agents.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

echo "==> Checking required Swift sources"
while IFS= read -r rel; do
  if [[ ! -f "WiFiLocator/$rel" ]]; then
    echo "missing: WiFiLocator/$rel" >&2
    fail=1
  fi
done <<'EOF'
WiFiLocatorApp.swift
ContentView.swift
Theme.swift
Models/AccessPoint.swift
Models/LocationEstimate.swift
Models/ScanExport.swift
Services/AppModel.swift
Services/WiFiScanner.swift
Services/NetworkInfoService.swift
Services/Geolocation/GeolocationService.swift
Services/Geolocation/AppleWPSProvider.swift
Services/Geolocation/BeaconDBProvider.swift
Services/Geolocation/GoogleGeolocationProvider.swift
Services/Geolocation/IPGeolocationProvider.swift
Services/Geolocation/ReverseGeocoder.swift
Views/MapLocationView.swift
Views/SettingsView.swift
Info.plist
WiFiLocator.entitlements
EOF

echo "==> Checking Xcode project references"
PBX="WiFiLocator.xcodeproj/project.pbxproj"
for name in ScanExport.swift WiFiScanner.swift AppleWPSProvider.swift package-dmg.sh; do
  if [[ "$name" == package-dmg.sh ]]; then
    [[ -x Scripts/package-dmg.sh || -f Scripts/package-dmg.sh ]] || { echo "missing Scripts/package-dmg.sh"; fail=1; }
  else
    grep -q "$name" "$PBX" || { echo "pbxproj missing $name"; fail=1; }
  fi
done

echo "==> Checking app icon assets"
ICON_DIR="WiFiLocator/Resources/Assets.xcassets/AppIcon.appiconset"
for f in icon_16x16.png icon_512x512.png walt.e@example.net Contents.json; do
  [[ -f "$ICON_DIR/$f" ]] || { echo "missing icon $f"; fail=1; }
done

echo "==> Checking workflows"
[[ -f ../.github/workflows/build-dmg.yml ]] || { echo "missing build-dmg.yml"; fail=1; }
[[ -f ../.github/workflows/release-dmg.yml ]] || { echo "missing release-dmg.yml"; fail=1; }

if [[ $fail -ne 0 ]]; then
  echo "Validation FAILED" >&2
  exit 1
fi

echo "Validation OK (structure). Full compile requires macOS + Xcode."
