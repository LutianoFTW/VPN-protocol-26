# WiFi Locator for macOS

Native Apple Silicon macOS app that scans nearby Wi‑Fi access points (BSSID/MAC, signal, channel), reads local and public IP addresses, and estimates the device’s location using public geolocation databases (Apple WPS, BeaconDB, IP geolocation, optional Google).

See [`WiFiLocator/README.md`](WiFiLocator/README.md) for build and usage instructions.

**Installable DMG** (on a Mac, or download the CI artifact from **Actions → Build DMG**):

```bash
cd WiFiLocator && ./Scripts/package-dmg.sh
open dist/WiFiLocator-1.0-arm64.dmg
```

Or open the Xcode project:

```bash
open WiFiLocator/WiFiLocator.xcodeproj
```
