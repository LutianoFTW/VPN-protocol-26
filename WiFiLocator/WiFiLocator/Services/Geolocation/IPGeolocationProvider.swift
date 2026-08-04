import Foundation

/// Coarse location from the Mac’s public IP using free IP geolocation databases.
struct IPGeolocationProvider: GeolocationProvider {
    let source: GeolocationSource = .publicIP
    let preferredIP: String?

    func locate(accessPoints: [AccessPoint]) async throws -> LocationEstimate {
        if let preferredIP, let estimate = try? await queryIPAPI(ip: preferredIP) {
            return estimate
        }
        if let estimate = try? await queryIPAPI(ip: nil) {
            return estimate
        }
        if let estimate = try? await queryIPWho(ip: preferredIP) {
            return estimate
        }
        throw AppError.geolocationFailed("All public IP geolocation providers failed")
    }

    private func queryIPAPI(ip: String?) async throws -> LocationEstimate {
        let path = ip.map { "https://ip-api.com/json/\($0)" } ?? "https://ip-api.com/json/"
        guard var components = URLComponents(string: path) else {
            throw AppError.networkFailed("Bad ip-api URL")
        }
        components.queryItems = [
            URLQueryItem(name: "fields", value: "status,message,country,regionName,city,zip,lat,lon,isp,query,accuracy")
        ]
        guard let url = components.url else {
            throw AppError.networkFailed("Bad ip-api URL")
        }

        var request = URLRequest(url: url)
        request.setValue("WiFiLocator/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.networkFailed("ip-api HTTP error")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let status = json?["status"] as? String, status == "success",
              let lat = json?["lat"] as? Double,
              let lon = json?["lon"] as? Double else {
            let message = (json?["message"] as? String) ?? "unknown"
            throw AppError.geolocationFailed("ip-api: \(message)")
        }

        let city = json?["city"] as? String
        let region = json?["regionName"] as? String
        let country = json?["country"] as? String
        let isp = json?["isp"] as? String
        let query = json?["query"] as? String
        let address = [city, region, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")

        return LocationEstimate(
            id: UUID(),
            latitude: lat,
            longitude: lon,
            accuracyMeters: 5_000,
            source: .publicIP,
            address: address.isEmpty ? nil : address,
            detail: [query.map { "IP \($0)" }, isp.map { "ISP: \($0)" }]
                .compactMap { $0 }
                .joined(separator: " · "),
            usedAccessPoints: 0,
            fetchedAt: Date()
        )
    }

    private func queryIPWho(ip: String?) async throws -> LocationEstimate {
        let path = ip.map { "https://ipwho.is/\($0)" } ?? "https://ipwho.is/"
        guard let url = URL(string: path) else {
            throw AppError.networkFailed("Bad ipwho URL")
        }

        var request = URLRequest(url: url)
        request.setValue("WiFiLocator/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AppError.networkFailed("ipwho HTTP error")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let success = json?["success"] as? Bool, success,
              let lat = json?["latitude"] as? Double,
              let lon = json?["longitude"] as? Double else {
            throw AppError.geolocationFailed("ipwho lookup failed")
        }

        let city = json?["city"] as? String
        let region = json?["region"] as? String
        let country = json?["country"] as? String
        let address = [city, region, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let query = json?["ip"] as? String
        let connection = json?["connection"] as? [String: Any]
        let isp = connection?["isp"] as? String

        return LocationEstimate(
            id: UUID(),
            latitude: lat,
            longitude: lon,
            accuracyMeters: 8_000,
            source: .publicIP,
            address: address.isEmpty ? nil : address,
            detail: [query.map { "IP \($0)" }, isp.map { "ISP: \($0)" }]
                .compactMap { $0 }
                .joined(separator: " · "),
            usedAccessPoints: 0,
            fetchedAt: Date()
        )
    }
}
