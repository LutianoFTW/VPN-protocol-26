import SwiftUI
import MapKit

struct MapLocationView: View {
    let estimate: LocationEstimate

    @State private var position: MapCameraPosition

    init(estimate: LocationEstimate) {
        self.estimate = estimate
        let region = MKCoordinateRegion(
            center: estimate.coordinate,
            latitudinalMeters: max(estimate.accuracyMeters * 4, 250),
            longitudinalMeters: max(estimate.accuracyMeters * 4, 250)
        )
        _position = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $position) {
            Annotation(estimate.source.shortName, coordinate: estimate.coordinate) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().stroke(.white, lineWidth: 2)
                        )
                }
            }

            MapCircle(center: estimate.coordinate, radius: estimate.accuracyMeters)
                .foregroundStyle(Theme.accent.opacity(0.12))
                .stroke(Theme.accent.opacity(0.45), lineWidth: 1)
        }
        .mapStyle(.standard(elevation: .realistic))
        .onChange(of: estimate.id) { _, _ in
            position = .region(
                MKCoordinateRegion(
                    center: estimate.coordinate,
                    latitudinalMeters: max(estimate.accuracyMeters * 4, 250),
                    longitudinalMeters: max(estimate.accuracyMeters * 4, 250)
                )
            )
        }
    }
}
