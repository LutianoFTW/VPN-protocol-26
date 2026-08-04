import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Geolocation providers") {
                Toggle("Apple Wi‑Fi Positioning System", isOn: $model.settings.enableAppleWPS)
                Text(GeolocationSource.appleWPS.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("BeaconDB (open Wi‑Fi database)", isOn: $model.settings.enableBeaconDB)
                Text(GeolocationSource.beaconDB.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Public IP geolocation", isOn: $model.settings.enablePublicIP)
                Text(GeolocationSource.publicIP.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Google Geolocation API", isOn: $model.settings.enableGoogle)
                SecureField("Google API key", text: $model.settings.googleAPIKey)
                    .disabled(!model.settings.enableGoogle)
                Text(GeolocationSource.google.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("Wi‑Fi BSSIDs can reveal precise location. Networks ending in _nomap are ignored. Location Services permission is required on modern macOS to read SSIDs and BSSIDs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .padding()
    }
}
