# WiFi Locator for macOS (Apple Silicon)

Native macOS app that scans nearby Wi‑Fi access points and uses that fingerprint (plus network/IP data) to estimate **where the Mac is**.

## Download the installable DMG

1. Open **[Releases](../../releases)** (or **Actions → Build DMG / Release DMG**) after CI finishes.
2. Download `WiFiLocator-*-arm64.dmg`.
3. Open the DMG and drag **WiFiLocator** into **Applications**.

Build locally on a Mac:

```bash
cd WiFiLocator && ./Scripts/package-dmg.sh
open dist/WiFiLocator-1.0.0-arm64.dmg
```

Or open the Xcode project:

```bash
open WiFiLocator/WiFiLocator.xcodeproj
```

Full docs: [`WiFiLocator/README.md`](WiFiLocator/README.md).

## How location works

| Signal | Role |
|--------|------|
| Wi‑Fi BSSID + RSSI + channel | Precise multilateration via Apple WPS / BeaconDB / optional Google |
| Public IP | Coarse city-level fallback |
| Local IP / gateway | Network context shown in the UI |

A **fused Wi‑Fi fix** blends independent database results (inverse-accuracy weighted) when more than one provider succeeds.

## Requirements

- Apple Silicon Mac (arm64)
- macOS 14+
- Location Services permission (macOS requires this to reveal SSIDs/BSSIDs)
