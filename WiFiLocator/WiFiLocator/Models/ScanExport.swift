import Foundation

struct ScanExportReport: Codable, Sendable {
    let exportedAt: Date
    let network: NetworkAddressInfo
    let accessPoints: [AccessPoint]
    let estimates: [ExportEstimate]
    let selectedEstimateID: String?
    let providerErrors: [String]
}

struct ExportEstimate: Codable, Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let source: String
    let address: String?
    let detail: String?
    let usedAccessPoints: Int
    let fetchedAt: Date

    init(from estimate: LocationEstimate) {
        id = estimate.id.uuidString
        latitude = estimate.latitude
        longitude = estimate.longitude
        accuracyMeters = estimate.accuracyMeters
        source = estimate.source.rawValue
        address = estimate.address
        detail = estimate.detail
        usedAccessPoints = estimate.usedAccessPoints
        fetchedAt = estimate.fetchedAt
    }
}

extension NetworkAddressInfo: Codable {}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
