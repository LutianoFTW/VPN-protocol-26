import AppKit
import AVFoundation
import Combine

struct CameraDevice: Identifiable, Hashable {
    let id: String
    let localizedName: String
    let device: AVCaptureDevice
}

@MainActor
final class QRScannerController: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var lastPayload: String?
    @Published var statusMessage = "Point a QR code at the camera"
    @Published var showPermissionAlert = false
    @Published var showNoCameraAlert = false
    @Published var availableCameras: [CameraDevice] = []
    @Published var selectedCameraID: String?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.qrscanner.session")
    private let metadataOutput = AVCaptureMetadataOutput()
    private var isConfigured = false
    private var pauseDetection = false

    func start() {
        refreshCameras()
        Task {
            let granted = await requestCameraAccess()
            guard granted else {
                showPermissionAlert = true
                statusMessage = "Camera permission denied"
                return
            }
            refreshCameras()
            guard !availableCameras.isEmpty else {
                showNoCameraAlert = true
                statusMessage = "No camera available — connect iPhone via USB‑C for Continuity Camera"
                return
            }
            if selectedCameraID == nil {
                selectedCameraID = preferredCameraID()
            }
            configureAndStart()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func resumeScanning() {
        lastPayload = nil
        pauseDetection = false
        statusMessage = "Point a QR code at the camera"
        if !isRunning {
            configureAndStart()
        }
    }

    func copyLastPayload() {
        guard let lastPayload else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastPayload, forType: .string)
        statusMessage = "Copied to clipboard"
    }

    func openLastPayloadIfURL() {
        guard let lastPayload, let url = URL(string: lastPayload),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto", "tel", "sms"].contains(scheme) else { return }
        NSWorkspace.shared.open(url)
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    func switchToSelectedCamera() {
        configureAndStart(forceReconfigure: true)
    }

    private func preferredCameraID() -> String? {
        // Prefer Continuity Camera (iPhone) when present, else first device.
        if let continuity = availableCameras.first(where: {
            $0.localizedName.localizedCaseInsensitiveContains("iphone")
                || $0.localizedName.localizedCaseInsensitiveContains("continuity")
        }) {
            return continuity.id
        }
        return availableCameras.first?.id
    }

    private func refreshCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices.map {
            CameraDevice(id: $0.uniqueID, localizedName: $0.localizedName, device: $0)
        }
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureAndStart(forceReconfigure: Bool = false) {
        let cameraID = selectedCameraID
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if forceReconfigure || !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }

                let device: AVCaptureDevice?
                if let cameraID {
                    device = AVCaptureDevice(uniqueID: cameraID)
                } else {
                    device = AVCaptureDevice.default(for: .video)
                }

                guard let device,
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.showNoCameraAlert = true
                        self.statusMessage = "Could not open the selected camera"
                    }
                    return
                }

                self.session.addInput(input)

                if self.session.canAddOutput(self.metadataOutput) {
                    self.session.addOutput(self.metadataOutput)
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    if self.metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                        self.metadataOutput.metadataObjectTypes = [.qr]
                    }
                }

                self.session.commitConfiguration()
                self.isConfigured = true
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
                if self.session.isRunning {
                    self.statusMessage = "Point a QR code at the camera"
                }
            }
        }
    }
}

extension QRScannerController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        Task { @MainActor in
            guard !pauseDetection else { return }
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue,
                  !value.isEmpty else { return }

            pauseDetection = true
            lastPayload = value
            statusMessage = "QR code detected"
            NSSound.beep()
        }
    }
}
