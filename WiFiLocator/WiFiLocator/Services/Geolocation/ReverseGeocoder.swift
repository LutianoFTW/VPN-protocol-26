import Foundation
import CoreLocation

struct ReverseGeocoder: Sendable {
    func address(for coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            let parts = [
                placemark.name,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

            // Deduplicate while preserving order
            var seen = Set<String>()
            let unique = parts.filter { seen.insert($0).inserted }
            return unique.isEmpty ? nil : unique.joined(separator: ", ")
        } catch {
            return nil
        }
    }
}
