import Foundation

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

        // Prefer more precise (smaller accuracy) Wi‑Fi results over IP.
        enriched.sort { lhs, rhs in
            score(lhs) < score(rhs)
        }

        return (enriched, errors)
    }

    private func score(_ estimate: LocationEstimate) -> Double {
        let sourceWeight: Double
        switch estimate.source {
        case .appleWPS: sourceWeight = 0
        case .beaconDB: sourceWeight = 1
        case .google: sourceWeight = 2
        case .publicIP: sourceWeight = 100
        }
        return sourceWeight * 1_000_000 + estimate.accuracyMeters
    }
}
