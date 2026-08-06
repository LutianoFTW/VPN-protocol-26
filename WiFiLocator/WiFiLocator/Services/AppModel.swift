import Foundation
import Combine
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var accessPoints: [AccessPoint] = []
    @Published var networkInfo: NetworkAddressInfo = .empty
    @Published var estimates: [LocationEstimate] = []
    @Published var selectedEstimateID: LocationEstimate.ID?
    @Published var providerErrors: [String] = []
    @Published var statusMessage: String = "Ready to scan nearby Wi‑Fi and estimate location."
    @Published var lastError: String?
    @Published var isBusy = false
    @Published var lastScanAt: Date?
    @Published var settings: GeolocationSettings {
        didSet { persistSettings() }
    }

    private let scanner = WiFiScanner()
    private let geolocation = GeolocationService()

    var selectedEstimate: LocationEstimate? {
        estimates.first { $0.id == selectedEstimateID } ?? estimates.first
    }

    var bestEstimate: LocationEstimate? {
        estimates.first
    }

    init() {
        self.settings = Self.loadSettings()
    }

    func scanAndLocate() async {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        providerErrors = []
        statusMessage = "Requesting Location Services permission…"

        defer { isBusy = false }

        do {
            statusMessage = "Scanning nearby Wi‑Fi access points…"
            let points = try await scanner.scan()
            accessPoints = points
            lastScanAt = Date()

            let current = scanner.currentNetwork()
            statusMessage = "Resolving local & public IP addresses…"
            networkInfo = await NetworkInfoService.collect(
                connectedSSID: current.ssid,
                connectedBSSID: current.bssid,
                interfaceName: current.interface
            )

            guard !points.isEmpty else {
                throw AppError.noAccessPoints
            }

            statusMessage = "Querying geolocation databases…"
            let result = await geolocation.locate(
                accessPoints: points,
                publicIP: networkInfo.publicIP,
                settings: settings
            )
            estimates = result.estimates
            providerErrors = result.errors
            selectedEstimateID = result.estimates.first?.id

            if let best = result.estimates.first {
                let place = best.address ?? String(format: "%.5f, %.5f", best.latitude, best.longitude)
                statusMessage = "Likely near \(place) via \(best.source.rawValue) (±\(Int(best.accuracyMeters)) m)."
            } else {
                statusMessage = "Scan complete, but no provider returned a location."
                lastError = result.errors.first ?? AppError.geolocationFailed("No results").localizedDescription
            }
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Scan failed."
        }
    }

    func scanNetworksOnly() async {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        do {
            statusMessage = "Scanning nearby Wi‑Fi access points…"
            let points = try await scanner.scan()
            accessPoints = points
            lastScanAt = Date()

            let current = scanner.currentNetwork()
            networkInfo = await NetworkInfoService.collect(
                connectedSSID: current.ssid,
                connectedBSSID: current.bssid,
                interfaceName: current.interface
            )
            statusMessage = "Found \(points.count) access point\(points.count == 1 ? "" : "s")."
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Scan failed."
        }
    }

    func copySelectedCoordinates() {
        guard let estimate = selectedEstimate else { return }
        let text = String(format: "%.8f, %.8f", estimate.latitude, estimate.longitude)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Copied coordinates \(text)"
    }

    func exportScanReport() -> URL? {
        let report = ScanExportReport(
            exportedAt: Date(),
            network: networkInfo,
            accessPoints: accessPoints,
            estimates: estimates.map { ExportEstimate(from: $0) },
            selectedEstimateID: selectedEstimateID?.uuidString,
            providerErrors: providerErrors
        )

        guard let data = try? JSONEncoder.pretty.encode(report) else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WiFiLocator-scan-\(stamp).json")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            lastError = "Could not write export: \(error.localizedDescription)"
            return nil
        }
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: GeolocationSettings.storageKey)
        }
    }

    private static func loadSettings() -> GeolocationSettings {
        guard let data = UserDefaults.standard.data(forKey: GeolocationSettings.storageKey),
              let decoded = try? JSONDecoder().decode(GeolocationSettings.self, from: data) else {
            return GeolocationSettings()
        }
        return decoded
    }
}

extension GeolocationSettings: Codable {}
