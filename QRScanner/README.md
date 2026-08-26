# QR Scanner (macOS)

Native macOS app that opens the camera and scans QR codes. Works with **Continuity Camera** so a USB‑C connected iPhone can act as the camera.

## Requirements

- Mac with macOS 14+
- [Xcode](https://developer.apple.com/xcode/) (App Store)
- Optional: iPhone on iOS 16+ connected by USB‑C for Continuity Camera

## Install on your Mac

This cloud environment is Linux and cannot compile or install onto your Mac over USB. Run these steps **on the Mac**:

```bash
git clone https://github.com/LutianoFTW/VPN-protocol-26.git
cd VPN-protocol-26/QRScanner
chmod +x install.sh
./install.sh
```

Or open `QRScanner.xcodeproj` in Xcode → select the **QRScanner** scheme → Product → Run.

The install script places the app in `~/Applications/QRScanner.app` and launches it.

## Continuity Camera (iPhone over USB‑C)

1. Connect iPhone to Mac with USB‑C and unlock both devices.
2. Trust the computer on the iPhone if prompted.
3. Confirm Continuity Camera is enabled on the iPhone (Settings → General → AirPlay & Continuity).
4. Launch **QR Scanner**, allow Camera access, and pick your iPhone in the camera menu if needed.
5. Point a QR code at the iPhone camera; the payload appears for Copy / Open / Scan Again.

## What it does

- Live camera preview (built‑in, USB, or Continuity Camera)
- Detects QR codes via `AVCaptureMetadataOutput`
- Copy result to clipboard or open `http`/`https`/`mailto`/`tel`/`sms` links
