import Foundation
import CoreLocation

struct LocationEstimate: Identifiable, Equatable, Sendable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let source: GeolocationSource
    let address: String?
    let detail: String?
    let usedAccessPoints: Int
    let fetchedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var mapsURL: URL? {
        URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=Estimated%20Location")
    }

    var openStreetMapURL: URL? {
        URL(string: "https://www.openstreetmap.org/?mlat=\(latitude)&mlon=\(longitude)#map=16/\(latitude)/\(longitude)")
    }
}

enum GeolocationSource: String, CaseIterable, Identifiable, Sendable {
    case fused = "Fused Wi‑Fi Fix"
    case appleWPS = "Apple WPS"
    case beaconDB = "BeaconDB"
    case google = "Google Geolocation"
    case publicIP = "Public IP"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .fused: return "Fused"
        case .appleWPS: return "Apple"
        case .beaconDB: return "BeaconDB"
        case .google: return "Google"
        case .publicIP: return "IP"
        }
    }

    var explanation: String {
        switch self {
        case .fused:
            return "Inverse-accuracy weighted blend of Wi‑Fi database fixes for the best available position."
        case .appleWPS:
            return "Queries Apple’s Wi‑Fi Positioning System using nearby BSSIDs."
        case .beaconDB:
            return "Open Ichnaea-compatible Wi‑Fi geolocation database (BeaconDB)."
        case .google:
            return "Google Geolocation API (requires your own API key in Settings)."
        case .publicIP:
            return "Coarse location from the device’s public IP address."
        }
    }
}

enum AppError: LocalizedError, Equatable {
    case wifiUnavailable
    case locationPermissionDenied
    case scanFailed(String)
    case noAccessPoints
    case geolocationFailed(String)
    case networkFailed(String)
    case missingAPIKey(String)

    var errorDescription: String? {
        switch self {
        case .wifiUnavailable:
            return "No Wi‑Fi interface is available on this Mac."
        case .locationPermissionDenied:
            return "Location permission is required to read Wi‑Fi BSSIDs on modern macOS. Enable it in System Settings → Privacy & Security → Location Services."
        case .scanFailed(let message):
            return "Wi‑Fi scan failed: \(message)"
        case .noAccessPoints:
            return "No nearby Wi‑Fi access points were found."
        case .geolocationFailed(let message):
            return "Could not estimate location: \(message)"
        case .networkFailed(let message):
            return "Network request failed: \(message)"
        case .missingAPIKey(let provider):
            return "\(provider) requires an API key. Add one in Settings."
        }
    }
}
