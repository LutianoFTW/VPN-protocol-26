import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = QRScannerController()

    var body: some View {
        ZStack {
            CameraPreviewView(session: scanner.session)
                .ignoresSafeArea()

            ScanOverlay(
                isScanning: scanner.isRunning && scanner.lastPayload == nil,
                hasResult: scanner.lastPayload != nil
            )

            VStack(spacing: 0) {
                topBar
                Spacer()
                if let payload = scanner.lastPayload {
                    ResultBanner(
                        payload: payload,
                        onCopy: { scanner.copyLastPayload() },
                        onOpen: { scanner.openLastPayloadIfURL() },
                        onScanAgain: { scanner.resumeScanning() }
                    )
                    .padding(24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    instructionBar
                        .padding(24)
                }
            }
        }
        .background(Color.black)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: scanner.lastPayload)
        .onAppear { scanner.start() }
        .onDisappear { scanner.stop() }
        .alert("Camera access needed", isPresented: $scanner.showPermissionAlert) {
            Button("Open System Settings") { scanner.openPrivacySettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow camera access in System Settings → Privacy & Security → Camera so QR Scanner can use Continuity Camera or your Mac camera.")
        }
        .alert("No camera found", isPresented: $scanner.showNoCameraAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Connect an iPhone with Continuity Camera over USB‑C (or use a built‑in/webcam), unlock it, and keep the Mac unlocked.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("QR Scanner")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            if !scanner.availableCameras.isEmpty {
                Picker("Camera", selection: $scanner.selectedCameraID) {
                    ForEach(scanner.availableCameras) { camera in
                        Text(camera.localizedName).tag(Optional(camera.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                .onChange(of: scanner.selectedCameraID) { _, _ in
                    scanner.switchToSelectedCamera()
                }
            }

            statusChip
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(scanner.isRunning ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(scanner.isRunning ? "Live" : "Idle")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12), in: Capsule())
    }

    private var instructionBar: some View {
        Text(scanner.statusMessage)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ScanOverlay: View {
    let isScanning: Bool
    let hasResult: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.48
            ZStack {
                Color.black.opacity(hasResult ? 0.45 : 0.28)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .frame(width: side, height: side)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)

                if isScanning {
                    ScanningLine(width: side - 24)
                        .frame(height: side - 24)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}

private struct ScanningLine: View {
    let width: CGFloat
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0),
                            Color.cyan.opacity(0.85),
                            Color.cyan.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 2)
                .offset(y: offset)
                .onAppear {
                    offset = 8
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        offset = geo.size.height - 10
                    }
                }
        }
    }
}

private struct ResultBanner: View {
    let payload: String
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onScanAgain: () -> Void

    private var looksLikeURL: Bool {
        guard let url = URL(string: payload), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "mailto", "tel", "sms"].contains(scheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Scanned")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(payload)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(6)

            HStack(spacing: 10) {
                Button("Copy", action: onCopy)
                    .keyboardShortcut("c", modifiers: [.command])
                if looksLikeURL {
                    Button("Open", action: onOpen)
                }
                Spacer()
                Button("Scan Again", action: onScanAgain)
                    .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(18)
        .frame(maxWidth: 640)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
    }
}

#Preview {
    ContentView()
}
