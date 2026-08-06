import Foundation
import CoreLocation

protocol GeolocationProvider: Sendable {
    var source: GeolocationSource { get }
    func locate(accessPoints: [AccessPoint]) async throws -> LocationEstimate
}

struct GeolocationSettings: Equatable, Sendable {
    var enableAppleWPS: Bool = true
    var enableBeaconDB: Bool = true
    var enableGoogle: Bool = false
    var enablePublicIP: Bool = true
    var googleAPIKey: String = ""

    static let storageKey = "geolocation.settings.v1"
}

@MainActor
final class GeolocationService {
    private let reverseGeocoder = ReverseGeocoder()

    func locate(
        accessPoints: [AccessPoint],
        publicIP: String?,
        settings: GeolocationSettings
    ) async -> (estimates: [LocationEstimate], errors: [String]) {
        var providers: [any GeolocationProvider] = []

        if settings.enableAppleWPS {
            providers.append(AppleWPSProvider())
        }
        if settings.enableBeaconDB {
            providers.append(BeaconDBProvider())
        }
        if settings.enableGoogle {
            providers.append(GoogleGeolocationProvider(apiKey: settings.googleAPIKey))
        }
        if settings.enablePublicIP {
            providers.append(IPGeolocationProvider(preferredIP: publicIP))
        }

        var estimates: [LocationEstimate] = []
        var errors: [String] = []

        await withTaskGroup(of: Result<LocationEstimate, Error>.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let estimate = try await provider.locate(accessPoints: accessPoints)
                        return .success(estimate)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            for await result in group {
                switch result {
                case .success(let estimate):
                    estimates.append(estimate)
                case .failure(let error):
                    errors.append(error.localizedDescription)
                }
            }
        }

        // Fuse independent Wi‑Fi database fixes into a single best estimate.
        if let fused = Self.fuseWiFiEstimates(estimates) {
            estimates.insert(fused, at: 0)
        }

        // Enrich with reverse-geocoded addresses sequentially (quiet on failure).
        var enriched: [LocationEstimate] = []
        for estimate in estimates {
            let address = await reverseGeocoder.address(for: estimate.coordinate)
            enriched.append(
                LocationEstimate(
                    id: estimate.id,
                    latitude: estimate.latitude,
                    longitude: estimate.longitude,
                    accuracyMeters: estimate.accuracyMeters,
                    source: estimate.source,
                    address: address ?? estimate.address,
                    detail: estimate.detail,
                    usedAccessPoints: estimate.usedAccessPoints,
                    fetchedAt: estimate.fetchedAt
                )
            )
        }

        // Prefer fused / precise Wi‑Fi results over coarse IP.
        enriched.sort { lhs, rhs in
            score(lhs) < score(rhs)
        }

        return (enriched, errors)
    }

    /// Inverse-accuracy weighted average of Wi‑Fi provider results (excludes public IP).
    nonisolated static func fuseWiFiEstimates(_ estimates: [LocationEstimate]) -> LocationEstimate? {
        let wifi = estimates.filter { estimate in
            switch estimate.source {
            case .appleWPS, .beaconDB, .google:
                return estimate.accuracyMeters > 0
            case .fused, .publicIP:
                return false
            }
        }
        guard wifi.count >= 2 else { return nil }

        var weightedLat = 0.0
        var weightedLon = 0.0
        var totalWeight = 0.0
        var maxUsed = 0

        for item in wifi {
            let weight = 1.0 / max(item.accuracyMeters, 5.0)
            weightedLat += item.latitude * weight
            weightedLon += item.longitude * weight
            totalWeight += weight
            maxUsed = max(maxUsed, item.usedAccessPoints)
        }

        guard totalWeight > 0 else { return nil }

        let lat = weightedLat / totalWeight
        let lon = weightedLon / totalWeight

        // Fused accuracy ≈ harmonic blend, tightened slightly when providers agree.
        let harmonic = Double(wifi.count) / wifi.reduce(0.0) { $0 + (1.0 / max($1.accuracyMeters, 5.0)) }
        let spread = providerSpreadMeters(wifi, centerLat: lat, centerLon: lon)
        let accuracy = max(8.0, min(harmonic, max(spread, 15.0)))

        let names = wifi.map(\.source.shortName).joined(separator: " + ")
        return LocationEstimate(
            id: UUID(),
            latitude: lat,
            longitude: lon,
            accuracyMeters: accuracy,
            source: .fused,
            address: nil,
            detail: "Weighted blend of \(wifi.count) Wi‑Fi providers (\(names)).",
            usedAccessPoints: maxUsed,
            fetchedAt: Date()
        )
    }

    nonisolated private static func providerSpreadMeters(
        _ estimates: [LocationEstimate],
        centerLat: Double,
        centerLon: Double
    ) -> Double {
        let center = CLLocation(latitude: centerLat, longitude: centerLon)
        let distances = estimates.map { item in
            CLLocation(latitude: item.latitude, longitude: item.longitude)
                .distance(from: center)
        }
        return distances.max() ?? 50
    }

    private func score(_ estimate: LocationEstimate) -> Double {
        let sourceWeight: Double
        switch estimate.source {
        case .fused: sourceWeight = -1
        case .appleWPS: sourceWeight = 0
        case .beaconDB: sourceWeight = 1
        case .google: sourceWeight = 2
        case .publicIP: sourceWeight = 100
        }
        return sourceWeight * 1_000_000 + estimate.accuracyMeters
    }
}
