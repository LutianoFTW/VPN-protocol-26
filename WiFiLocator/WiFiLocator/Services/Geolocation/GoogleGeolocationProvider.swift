import Foundation

/// Optional Google Geolocation API provider (user-supplied API key).
struct GoogleGeolocationProvider: GeolocationProvider {
    let source: GeolocationSource = .google
    let apiKey: String

    func locate(accessPoints: [AccessPoint]) async throws -> LocationEstimate {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw AppError.missingAPIKey("Google Geolocation")
        }

        let usable = accessPoints.filter { !$0.bssid.isEmpty && !$0.ssid.hasSuffix("_nomap") }
        guard usable.count >= 2 else {
            throw AppError.geolocationFailed("Google Geolocation needs at least two access points")
        }

        guard let url = URL(string: "https://www.googleapis.com/geolocation/v1/geolocate?key=\(key)") else {
            throw AppError.networkFailed("Invalid Google Geolocation URL")
        }

        let wifiPayload: [[String: Any]] = usable.prefix(40).map { ap in
            var item: [String: Any] = [
                "macAddress": ap.bssid,
                "signalStrength": ap.rssi
            ]
            if ap.channel > 0 { item["channel"] = ap.channel }
            return item
        }

        let body: [String: Any] = [
            "considerIp": false,
            "wifiAccessPoints": wifiPayload
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("WiFiLocator/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkFailed("Invalid Google response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AppError.geolocationFailed("Google: \(message)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let location = json?["location"] as? [String: Any],
              let lat = location["lat"] as? Double,
              let lng = location["lng"] as? Double else {
            throw AppError.geolocationFailed("Google returned an unexpected payload")
        }

        let accuracy = (json?["accuracy"] as? Double) ?? 100

        return LocationEstimate(
            id: UUID(),
            latitude: lat,
            longitude: lng,
            accuracyMeters: accuracy,
            source: .google,
            address: nil,
            detail: "Google Geolocation API multilateration",
            usedAccessPoints: usable.count,
            fetchedAt: Date()
        )
    }
}
