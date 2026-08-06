import Foundation

/// BeaconDB — open Ichnaea/MLS-compatible Wi‑Fi geolocation API.
struct BeaconDBProvider: GeolocationProvider {
    let source: GeolocationSource = .beaconDB
    private let endpoint = URL(string: "https://api.beacondb.net/v1/geolocate")!

    func locate(accessPoints: [AccessPoint]) async throws -> LocationEstimate {
        let usable = accessPoints.filter { ap in
            !ap.bssid.isEmpty && !ap.ssid.hasSuffix("_nomap")
        }

        // Ichnaea privacy rule: at least two Wi‑Fi networks for a Wi‑Fi fix.
        guard usable.count >= 2 else {
            throw AppError.geolocationFailed("BeaconDB needs at least two access points")
        }

        let wifiPayload: [[String: Any]] = usable.prefix(40).map { ap in
            var item: [String: Any] = [
                "macAddress": ap.bssid,
                "signalStrength": ap.rssi
            ]
            if ap.channel > 0 {
                item["channel"] = ap.channel
            }
            if !ap.ssid.isEmpty {
                item["ssid"] = ap.ssid
            }
            return item
        }

        let body: [String: Any] = [
            "wifiAccessPoints": wifiPayload,
            "fallbacks": [
                "lacf": false,
                "ipf": false
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("WiFiLocator/1.0 (macOS; Apple Silicon)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkFailed("Invalid BeaconDB response")
        }

        if http.statusCode == 404 {
            throw AppError.geolocationFailed("BeaconDB has no coverage for these networks")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.geolocationFailed("BeaconDB HTTP \(http.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let location = json?["location"] as? [String: Any],
              let lat = location["lat"] as? Double,
              let lng = location["lng"] as? Double else {
            throw AppError.geolocationFailed("BeaconDB returned an unexpected payload")
        }

        let accuracy = (json?["accuracy"] as? Double) ?? 100
        let fallback = json?["fallback"] as? String

        return LocationEstimate(
            id: UUID(),
            latitude: lat,
            longitude: lng,
            accuracyMeters: accuracy,
            source: .beaconDB,
            address: nil,
            detail: fallback.map { "Fallback used: \($0)" } ?? "Wi‑Fi multilateration from BeaconDB",
            usedAccessPoints: usable.count,
            fetchedAt: Date()
        )
    }
}
