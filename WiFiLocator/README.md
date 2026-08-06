# WiFi Locator

Native **macOS (Apple Silicon)** app that scans nearby Wi‑Fi access points, collects IP addresses, and estimates the Mac’s physical location using public geolocation databases.

## Install from DMG

### From GitHub

1. Go to **Releases** on this repository and download `WiFiLocator-*-arm64.dmg`, **or**
2. Open **Actions → Build DMG** (or **Release DMG**), download the artifact.

Then open the DMG and drag **WiFiLocator** into **Applications**.

### Build the DMG yourself (Mac + Xcode)

```bash
cd WiFiLocator
./Scripts/package-dmg.sh
open dist/WiFiLocator-1.0-arm64.dmg
```

| Output | Path |
|--------|------|
| Disk image | `dist/WiFiLocator-<version>-arm64.dmg` |
| Checksum | `dist/WiFiLocator-<version>-arm64.dmg.sha256` |

Publish a release (creates a GitHub Release with the DMG):

- Push a tag: `git tag v1.0.0 && git push origin v1.0.0`
- Or run **Actions → Release DMG** (workflow_dispatch)

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
4. **Fuses** multiple successful Wi‑Fi provider results into a best fix (inverse-accuracy weighted).
5. **Shows the result** on a MapKit map with accuracy radius and reverse-geocoded address.
6. **Export** scan + estimates as JSON; copy coordinates to the clipboard.

> Note: Wi‑Fi geolocation uses **BSSIDs** (access-point MAC addresses), not the access points’ LAN IPs. Consumer APs rarely expose a public IP per radio; the app therefore uses BSSIDs for precise fixes and your Mac’s **public IP** for a coarse fallback. Urban accuracy is often tens of meters when several known APs are visible; rural coverage depends on database density.

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
3. Compare provider results (Fused / Apple / BeaconDB / IP) in the center map pane.
4. Toggle providers in the left sidebar or **Settings**.
5. Use **Copy coordinates** or **Export JSON** as needed.

Keyboard:

- `⌘R` — Scan & Locate
- `⇧⌘R` — Wi‑Fi scan only
- `⇧⌘C` — Copy selected coordinates
- `⇧⌘E` — Export scan JSON

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
