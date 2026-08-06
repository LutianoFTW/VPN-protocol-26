import Foundation
import CoreWLAN
import CoreLocation

/// Scans nearby Wi‑Fi networks via CoreWLAN.
/// On macOS Sonoma+, BSSID/SSID require Location Services permission.
@MainActor
final class WiFiScanner: NSObject {
    private let locationManager = CLLocationManager()
    private var permissionContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    func ensureLocationPermission() async -> Bool {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            locationManager.delegate = self
            return await withCheckedContinuation { continuation in
                permissionContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }.isAuthorized
        @unknown default:
            return false
        }
    }

    func scan() async throws -> [AccessPoint] {
        let permitted = await ensureLocationPermission()
        guard permitted else { throw AppError.locationPermissionDenied }

        return try await Task.detached(priority: .userInitiated) {
            try Self.performScan()
        }.value
    }

    func currentNetwork() -> (ssid: String?, bssid: String?, interface: String?) {
        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            return (nil, nil, nil)
        }
        return (interface.ssid(), interface.bssid(), interface.interfaceName)
    }

    nonisolated private static func performScan() throws -> [AccessPoint] {
        let client = CWWiFiClient.shared()
        guard let interface = client.interface() else {
            throw AppError.wifiUnavailable
        }

        let currentBSSID = interface.bssid()?.uppercased()

        let networks: Set<CWNetwork>
        do {
            networks = try interface.scanForNetworks(withName: nil)
        } catch {
            throw AppError.scanFailed(error.localizedDescription)
        }

        let points: [AccessPoint] = networks.compactMap { network in
            let bssid = (network.bssid ?? "").uppercased()
            guard !bssid.isEmpty, bssid != "00:00:00:00:00:00" else { return nil }

            let ssid = network.ssid ?? ""
            // Privacy: skip intentionally opted-out networks
            if ssid.hasSuffix("_nomap") { return nil }

            let channel = Int(network.wlanChannel?.channelNumber ?? 0)
            let rssi = network.rssiValue
            let security = describeSecurity(network)

            return AccessPoint(
                ssid: ssid,
                bssid: bssid,
                rssi: rssi,
                channel: channel,
                band: .from(channel: channel),
                security: security,
                isCurrent: currentBSSID == bssid
            )
        }

        return points.sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent { return lhs.isCurrent && !rhs.isCurrent }
            return lhs.rssi > rhs.rssi
        }
    }

    nonisolated private static func describeSecurity(_ network: CWNetwork) -> String {
        if network.supportsSecurity(.wpa3Transition) ||
            network.supportsSecurity(.wpa3Personal) ||
            network.supportsSecurity(.wpa3Enterprise) {
            return "WPA3"
        }
        if network.supportsSecurity(.wpa2Personal) ||
            network.supportsSecurity(.wpa2Enterprise) ||
            network.supportsSecurity(.personal) ||
            network.supportsSecurity(.enterprise) {
            return "WPA2"
        }
        if network.supportsSecurity(.wpaPersonal) ||
            network.supportsSecurity(.wpaEnterprise) ||
            network.supportsSecurity(.wpaPersonalMixed) ||
            network.supportsSecurity(.wpaEnterpriseMixed) {
            return "WPA"
        }
        if network.supportsSecurity(.WEP) || network.supportsSecurity(.dynamicWEP) {
            return "WEP"
        }
        if network.supportsSecurity(CWSecurity.none) {
            return "Open"
        }
        return "Secured"
    }
}

extension WiFiScanner: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let continuation = permissionContinuation else { return }
            permissionContinuation = nil
            continuation.resume(returning: manager.authorizationStatus)
        }
    }
}

private extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        switch self {
        case .authorized, .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }
}
