# WiFi Locator

Native **macOS (Apple Silicon)** app that scans nearby Wi‑Fi access points, collects IP addresses, and estimates the Mac’s physical location using public geolocation databases.

## Install from DMG

On a Mac (or via GitHub Actions), build the installable disk image:

```bash
cd WiFiLocator
./Scripts/package-dmg.sh
open dist/WiFiLocator-1.0-arm64.dmg
```

Then drag **WiFiLocator** into **Applications**.

| Output | Path |
|--------|------|
| Disk image | `dist/WiFiLocator-1.0-arm64.dmg` |
| Checksum | `dist/WiFiLocator-1.0-arm64.dmg.sha256` |

CI also builds the DMG on every relevant push: **Actions → Build DMG → artifact `WiFiLocator-1.0-arm64-dmg`**.

### First launch (ad-hoc / unsigned builds)

If Gatekeeper blocks the app: right-click → **Open** → **Open**, or use **System Settings → Privacy & Security → Open Anyway**.

For Developer ID distribution:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/package-dmg.sh
```

## What it does

1. **Scans Wi‑Fi** via `CoreWLAN` (SSID, BSSID/MAC, RSSI, channel, band, security).
2. **Reads network addresses**: public IP, local IPv4, default gateway, connected SSID/BSSID.
3. **Estimates location** by querying:
   - **Apple WPS** (`gs-loc.apple.com`) — Wi‑Fi BSSID database
   - **BeaconDB** — open Ichnaea-compatible Wi‑Fi geolocation API
   - **Public IP** — `ip-api.com` / `ipwho.is` (coarse city-level)
   - **Google Geolocation** — optional, needs your API key in Settings
4. **Shows the result** on a MapKit map with accuracy radius and reverse-geocoded address.

> Note: Wi‑Fi geolocation uses **BSSIDs** (access-point MAC addresses), not the access points’ LAN IPs. Consumer APs rarely expose a public IP per radio; the app therefore uses BSSIDs for precise fixes and your Mac’s **public IP** for a coarse fallback.

## Requirements

- Mac with **Apple Silicon** (arm64)
- **macOS 14 Sonoma** or later
- **Xcode 15+** (to build the DMG)
- **Location Services** allowed for the app (required by macOS to reveal SSIDs/BSSIDs)

## Build & run (without DMG)

```bash
cd WiFiLocator
open WiFiLocator.xcodeproj
```

In Xcode:

1. Select the **WiFi Locator** scheme and **My Mac (Apple Silicon)**.
2. Set your Team under Signing & Capabilities if prompted.
3. Press **Run** (⌘R).
4. When asked, allow **Location Services**.

Or from the terminal on a Mac:

```bash
cd WiFiLocator
./Scripts/build.sh
open build/Build/Products/Debug/WiFiLocator.app

# Release build:
CONFIGURATION=Release ./Scripts/build.sh
```

## Usage

1. Click **Scan & Locate**.
2. Review nearby APs in the right column (BSSID + signal).
3. Compare provider results (Apple / BeaconDB / IP) in the center map pane.
4. Toggle providers in the left sidebar or **Settings**.

Keyboard:

- `⌘R` — Scan & Locate
- `⇧⌘R` — Wi‑Fi scan only

## Privacy

- Networks whose SSID ends with `_nomap` are ignored (Ichnaea convention).
- BSSIDs can pinpoint a place; only enable the providers you trust.
- Google Geolocation is off by default and never called without an API key you supply.

## Project layout

```
WiFiLocator/
├── WiFiLocator.xcodeproj
├── Scripts/
│   ├── build.sh
│   ├── package-dmg.sh      # Release .app → installable .dmg
│   └── generate_xcodeproj.py
├── dist/                   # Created by package-dmg.sh
└── WiFiLocator/
    ├── WiFiLocatorApp.swift
    ├── ContentView.swift
    ├── Models/
    ├── Services/
    ├── Views/
    ├── Resources/
    ├── Info.plist
    └── WiFiLocator.entitlements
```

## Architecture target

The Xcode target is locked to **`ARCHS = arm64`** and excludes Intel slices, matching Apple Silicon Macs.
