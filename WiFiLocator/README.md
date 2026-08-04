# WiFi Locator

Native **macOS (Apple Silicon)** app that scans nearby Wi‑Fi access points, collects IP addresses, and estimates the Mac’s physical location using public geolocation databases.

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
- **Xcode 15+**
- **Location Services** allowed for the app (required by macOS to reveal SSIDs/BSSIDs)

## Build & run

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
│   └── generate_xcodeproj.py
└── WiFiLocator/
    ├── WiFiLocatorApp.swift
    ├── ContentView.swift
    ├── Models/
    ├── Services/          # CoreWLAN scanner, IP info, geolocation providers
    ├── Views/
    ├── Resources/
    ├── Info.plist
    └── WiFiLocator.entitlements
```

## Architecture target

The Xcode target is locked to **`ARCHS = arm64`** and excludes Intel slices, matching Apple Silicon Macs.
