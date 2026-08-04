import Foundation
import SystemConfiguration

enum NetworkInfoService {
    static func collect(connectedSSID: String?, connectedBSSID: String?, interfaceName: String?) async -> NetworkAddressInfo {
        async let publicIP = fetchPublicIP()
        let local = localIPv4Addresses()
        let gateway = defaultGatewayIPv4()

        return NetworkAddressInfo(
            publicIP: await publicIP,
            localIPv4: local,
            gatewayIPv4: gateway,
            interfaceName: interfaceName,
            connectedSSID: connectedSSID,
            connectedBSSID: connectedBSSID
        )
    }

    private static func fetchPublicIP() async -> String? {
        let endpoints = [
            URL(string: "https://api.ipify.org?format=json")!,
            URL(string: "https://api64.ipify.org?format=json")!
        ]

        for url in endpoints {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 8
                request.setValue("WiFiLocator/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    continue
                }
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ip = json["ip"] as? String,
                   !ip.isEmpty {
                    return ip
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private static func localIPv4Addresses() -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let iface = pointer {
            defer { pointer = iface.pointee.ifa_next }

            let flags = Int32(iface.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp, !isLoopback else { continue }

            guard let addr = iface.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                let ip = String(cString: hostname)
                if !addresses.contains(ip) {
                    addresses.append(ip)
                }
            }
        }
        return addresses
    }

    private static func defaultGatewayIPv4() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "WiFiLocator" as CFString, nil, nil) else {
            return nil
        }

        let key = "State:/Network/Global/IPv4" as CFString
        guard let info = SCDynamicStoreCopyValue(store, key) as? [String: Any],
              let router = info["Router"] as? String else {
            return nil
        }
        return router
    }
}
