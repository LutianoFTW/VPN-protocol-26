import Foundation

struct AccessPoint: Identifiable, Hashable, Codable, Sendable {
    var id: String { bssid.uppercased() }

    let ssid: String
    let bssid: String
    let rssi: Int
    let channel: Int
    let band: WiFiBand
    let security: String
    let isCurrent: Bool

    var displaySSID: String {
        ssid.isEmpty ? "(Hidden Network)" : ssid
    }

    var signalQuality: SignalQuality {
        switch rssi {
        case (-50)...0: return .excellent
        case (-60)..<(-50): return .good
        case (-70)..<(-60): return .fair
        default: return .weak
        }
    }
}

enum WiFiBand: String, Codable, Sendable {
    case twoGHz = "2.4 GHz"
    case fiveGHz = "5 GHz"
    case sixGHz = "6 GHz"
    case unknown = "Unknown"

    static func from(channel: Int) -> WiFiBand {
        switch channel {
        case 1...14: return .twoGHz
        case 15...177: return .fiveGHz
        case 178...: return .sixGHz
        default: return .unknown
        }
    }
}

enum SignalQuality: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
}

struct NetworkAddressInfo: Equatable, Sendable {
    var publicIP: String?
    var localIPv4: [String]
    var gatewayIPv4: String?
    var interfaceName: String?
    var connectedSSID: String?
    var connectedBSSID: String?

    static let empty = NetworkAddressInfo(
        publicIP: nil,
        localIPv4: [],
        gatewayIPv4: nil,
        interfaceName: nil,
        connectedSSID: nil,
        connectedBSSID: nil
    )
}
