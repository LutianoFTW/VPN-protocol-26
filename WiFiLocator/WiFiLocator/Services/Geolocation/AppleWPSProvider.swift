import Foundation

/// Queries Apple’s Wireless Positioning System (WPS) with nearby BSSIDs.
/// Protocol based on public reverse-engineering of `gs-loc.apple.com/clls/wloc`.
struct AppleWPSProvider: GeolocationProvider {
    let source: GeolocationSource = .appleWPS
    private let endpoint = URL(string: "https://gs-loc.apple.com/clls/wloc")!

    func locate(accessPoints: [AccessPoint]) async throws -> LocationEstimate {
        let usable = accessPoints
            .filter { !$0.bssid.isEmpty }
            .prefix(40)

        guard usable.count >= 1 else {
            throw AppError.noAccessPoints
        }

        let body = AppleWPSCodec.buildRequest(bssids: usable.map(\.bssid))
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-us", forHTTPHeaderField: "Accept-Language")
        request.setValue("locationd/2890.0.71 CFNetwork/1490.0.4 Darwin/23.2.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkFailed("Invalid Apple WPS response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.geolocationFailed("Apple WPS HTTP \(http.statusCode)")
        }

        let locations = try AppleWPSCodec.parseResponse(data)
        guard !locations.isEmpty else {
            throw AppError.geolocationFailed("Apple WPS returned no known BSSIDs")
        }

        // Prefer locations for observed BSSIDs; otherwise use returned nearby APs.
        let observed = Set(usable.map { $0.bssid.uppercased() })
        let matched = locations.filter { observed.contains($0.bssid.uppercased()) }
        let pool = matched.isEmpty ? locations : matched

        // RSSI-weighted centroid when we have local RSSI for matched APs.
        let rssiByBSSID = Dictionary(uniqueKeysWithValues: usable.map {
            ($0.bssid.uppercased(), Double($0.rssi))
        })

        var weightedLat = 0.0
        var weightedLon = 0.0
        var totalWeight = 0.0

        for item in pool {
            let rssi = rssiByBSSID[item.bssid.uppercased()] ?? -70
            let weight = max(1.0, Double(rssi + 100))
            weightedLat += item.latitude * weight
            weightedLon += item.longitude * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            throw AppError.geolocationFailed("Apple WPS could not triangulate")
        }

        let lat = weightedLat / totalWeight
        let lon = weightedLon / totalWeight

        // Rough accuracy: tighter when more observed APs match the database.
        let accuracy: Double
        switch matched.count {
        case 0: accuracy = 500
        case 1: accuracy = 120
        case 2...4: accuracy = 55
        default: accuracy = 25
        }

        return LocationEstimate(
            id: UUID(),
            latitude: lat,
            longitude: lon,
            accuracyMeters: accuracy,
            source: .appleWPS,
            address: nil,
            detail: "Matched \(matched.count) of \(usable.count) scanned BSSIDs; Apple returned \(locations.count) nearby APs.",
            usedAccessPoints: usable.count,
            fetchedAt: Date()
        )
    }
}

enum AppleWPSCodec {
    struct APLocation {
        let bssid: String
        let latitude: Double
        let longitude: Double
    }

    static func buildRequest(bssids: [String]) -> Data {
        var proto = Data()
        for bssid in bssidNormalized(bssids) {
            // field 1 (wifi device message), wire type 2 (length-delimited)
            var device = Data()
            // field 1 string bssid
            let bssidData = Data(bssid.utf8)
            device.append(protobufKey(field: 1, wire: 2))
            device.append(contentsOf: encodeVarint(UInt64(bssidData.count)))
            device.append(bssidData)

            proto.append(protobufKey(field: 1, wire: 2))
            proto.append(contentsOf: encodeVarint(UInt64(device.count)))
            proto.append(device)
        }

        // unknown1 = 0 (field 2, varint)
        proto.append(protobufKey(field: 2, wire: 0))
        proto.append(contentsOf: encodeVarint(0))
        // unknown2 = 1 => return only queried BSSIDs (more focused)
        // Using 0 returns ~400 nearby results which helps triangulation.
        proto.append(protobufKey(field: 3, wire: 0))
        proto.append(contentsOf: encodeVarint(0))

        var payload = Data()
        // Length-prefixed header used by locationd / Apple WPS clients.
        payload.append(contentsOf: [0x00, 0x01])
        payload.append(lengthPrefixedASCII("en_US"))
        payload.append(lengthPrefixedASCII("com.apple.locationd"))
        payload.append(lengthPrefixedASCII("15.0.0.24A5289g"))
        payload.append(contentsOf: [0x00, 0x00, 0x00, 0x01, 0x00, 0x00])

        // Protobuf length: classic clients use a single trailing length byte when < 256.
        let length = proto.count
        if length < 256 {
            payload.append(0x00)
            payload.append(UInt8(length))
        } else {
            // Fallback for larger batches: 2-byte big-endian length.
            payload.append(UInt8((length >> 8) & 0xFF))
            payload.append(UInt8(length & 0xFF))
        }
        payload.append(proto)
        return payload
    }

    static func parseResponse(_ data: Data) throws -> [APLocation] {
        // Response typically starts with a small binary header then protobuf.
        // Try several offsets until protobuf decode yields wifi entries.
        let candidates = [10, 8, 0, 12, 16]
        for offset in candidates where offset < data.count {
            let slice = data.subdata(in: offset..<data.count)
            if let decoded = try? decodeDeviceList(slice), !decoded.isEmpty {
                return decoded
            }
        }
        throw AppError.geolocationFailed("Unable to parse Apple WPS response")
    }

    private static func decodeDeviceList(_ data: Data) throws -> [APLocation] {
        var results: [APLocation] = []
        var index = 0
        while index < data.count {
            let (key, next) = try decodeVarint(data, at: index)
            index = next
            let field = Int(key >> 3)
            let wire = Int(key & 0x7)

            switch wire {
            case 0:
                let (_, n) = try decodeVarint(data, at: index)
                index = n
            case 1:
                index += 8
            case 5:
                index += 4
            case 2:
                let (len, n) = try decodeVarint(data, at: index)
                index = n
                let end = index + Int(len)
                guard end <= data.count else { throw CodecError.truncated }
                let nested = data.subdata(in: index..<end)
                index = end
                if field == 1, let ap = decodeDevice(nested) {
                    results.append(ap)
                }
            default:
                throw CodecError.unsupportedWire
            }
        }
        return results
    }

    private static func decodeDevice(_ data: Data) -> APLocation? {
        var bssid: String?
        var latitude: Int64?
        var longitude: Int64?
        var index = 0

        while index < data.count {
            guard let (key, next) = try? decodeVarint(data, at: index) else { return nil }
            index = next
            let field = Int(key >> 3)
            let wire = Int(key & 0x7)

            do {
                switch wire {
                case 0:
                    let (value, n) = try decodeVarint(data, at: index)
                    index = n
                    // Occasionally lat/lon appear as varints in nested messages
                    _ = value
                case 1:
                    index += 8
                case 5:
                    index += 4
                case 2:
                    let (len, n) = try decodeVarint(data, at: index)
                    index = n
                    let end = index + Int(len)
                    guard end <= data.count else { return nil }
                    let nested = data.subdata(in: index..<end)
                    index = end
                    if field == 1 {
                        bssid = String(data: nested, encoding: .utf8)
                    } else if field == 2 {
                        // Location message: int64 lat=1, lon=2 scaled by 1e8
                        var i = 0
                        while i < nested.count {
                            let (k, n2) = try decodeVarint(nested, at: i)
                            i = n2
                            let f = Int(k >> 3)
                            let w = Int(k & 0x7)
                            if w == 0 {
                                let (v, n3) = try decodeVarint(nested, at: i)
                                i = n3
                                // Protobuf int64 (not sint64/zigzag): bit-pattern cast.
                                let signed = Int64(bitPattern: v)
                                if f == 1 { latitude = signed }
                                if f == 2 { longitude = signed }
                            } else if w == 2 {
                                let (l, n3) = try decodeVarint(nested, at: i)
                                i = n3 + Int(l)
                            } else if w == 1 {
                                i += 8
                            } else if w == 5 {
                                i += 4
                            } else {
                                return nil
                            }
                        }
                    }
                default:
                    return nil
                }
            } catch {
                return nil
            }
        }

        guard let bssid,
              let latitude,
              let longitude,
              latitude != -18000000000,
              longitude != -18000000000 else {
            return nil
        }

        return APLocation(
            bssid: bssid,
            latitude: Double(latitude) / 100_000_000.0,
            longitude: Double(longitude) / 100_000_000.0
        )
    }

    private static func bssidNormalized(_ bssids: [String]) -> [String] {
        bssids.map { raw in
            let hex = raw.uppercased().filter { $0.isHexDigit }
            guard hex.count == 12 else { return raw.lowercased() }
            return stride(from: 0, to: 12, by: 2)
                .map { String(hex[hex.index(hex.startIndex, offsetBy: $0)..<hex.index(hex.startIndex, offsetBy: $0 + 2)]) }
                .joined(separator: ":")
                .lowercased()
        }
    }

    private static func lengthPrefixedASCII(_ string: String) -> Data {
        let bytes = Array(string.utf8)
        var data = Data([0x00, UInt8(bytes.count)])
        data.append(contentsOf: bytes)
        return data
    }

    private static func protobufKey(field: Int, wire: Int) -> UInt8 {
        UInt8((field << 3) | wire)
    }

    private static func encodeVarint(_ value: UInt64) -> [UInt8] {
        var v = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while v != 0
        return bytes
    }

    private static func decodeVarint(_ data: Data, at start: Int) throws -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var index = start
        while index < data.count {
            let byte = data[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return (result, index)
            }
            shift += 7
            if shift > 63 { throw CodecError.overflow }
        }
        throw CodecError.truncated
    }

    enum CodecError: Error {
        case truncated
        case overflow
        case unsupportedWire
    }
}
