import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar()
                Divider().overlay(Theme.hairline)
                MainSplit()
                Divider().overlay(Theme.hairline)
                StatusBar()
            }
        }
        .tint(Theme.accent)
    }
}

private struct HeaderBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WiFi Locator")
                    .font(.custom("Avenir Next Demi Bold", size: 22))
                    .foregroundStyle(Theme.ink)
                Text("Apple Silicon · CoreWLAN · public geolocation databases")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            Button {
                Task { await model.scanAndLocate() }
            } label: {
                HStack(spacing: 8) {
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "location.magnifyingglass")
                    }
                    Text(model.isBusy ? "Working…" : "Scan & Locate")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Theme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(model.isBusy)
            .opacity(model.isBusy ? 0.7 : 1)

            Button {
                Task { await model.scanNetworksOnly() }
            } label: {
                Text("Wi‑Fi Only")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Theme.panel)
            .foregroundStyle(Theme.ink)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(model.isBusy)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.surface)
    }
}

private struct MainSplit: View {
    var body: some View {
        HStack(spacing: 0) {
            NetworkSidebar()
                .frame(width: 320)
            Divider().overlay(Theme.hairline)
            LocationPane()
            Divider().overlay(Theme.hairline)
            AccessPointPane()
                .frame(minWidth: 300, idealWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NetworkSidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle("This Mac")

                InfoCard {
                    LabeledValue(label: "Public IP", value: model.networkInfo.publicIP ?? "—", mono: true)
                    LabeledValue(label: "Gateway", value: model.networkInfo.gatewayIPv4 ?? "—", mono: true)
                    LabeledValue(
                        label: "Local IPv4",
                        value: model.networkInfo.localIPv4.isEmpty
                            ? "—"
                            : model.networkInfo.localIPv4.joined(separator: "\n"),
                        mono: true
                    )
                    LabeledValue(label: "Interface", value: model.networkInfo.interfaceName ?? "—", mono: true)
                    LabeledValue(label: "Connected SSID", value: model.networkInfo.connectedSSID ?? "—")
                    LabeledValue(label: "Connected BSSID", value: model.networkInfo.connectedBSSID ?? "—", mono: true)
                }

                SectionTitle("Providers")
                VStack(alignment: .leading, spacing: 8) {
                    ProviderToggle(title: "Apple WPS", isOn: $model.settings.enableAppleWPS)
                    ProviderToggle(title: "BeaconDB", isOn: $model.settings.enableBeaconDB)
                    ProviderToggle(title: "Public IP", isOn: $model.settings.enablePublicIP)
                    ProviderToggle(title: "Google (API key)", isOn: $model.settings.enableGoogle)
                }

                if !model.providerErrors.isEmpty {
                    SectionTitle("Provider notes")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.providerErrors, id: \.self) { error in
                            Text(error)
                                .font(.custom("Avenir Next", size: 11))
                                .foregroundStyle(Theme.warn)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.surface)
    }
}

private struct LocationPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let estimate = model.selectedEstimate {
                MapLocationView(estimate: estimate)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(Theme.hairline)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(estimate.address ?? "Estimated coordinates")
                                .font(.custom("Avenir Next Demi Bold", size: 18))
                                .foregroundStyle(Theme.ink)
                            Text(estimate.source.rawValue)
                                .font(.custom("Avenir Next", size: 12))
                                .foregroundStyle(Theme.accent)
                        }
                        Spacer()
                        AccuracyBadge(meters: estimate.accuracyMeters)
                    }

                    Text(String(format: "%.6f, %.6f", estimate.latitude, estimate.longitude))
                        .font(.custom("Menlo", size: 13))
                        .foregroundStyle(Theme.ink)

                    if let detail = estimate.detail {
                        Text(detail)
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(Theme.muted)
                    }

                    if model.estimates.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(model.estimates) { item in
                                    EstimateChip(
                                        estimate: item,
                                        selected: item.id == model.selectedEstimateID
                                    ) {
                                        model.selectedEstimateID = item.id
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        if let url = estimate.mapsURL {
                            Link("Open in Apple Maps", destination: url)
                                .font(.custom("Avenir Next Medium", size: 12))
                        }
                        if let url = estimate.openStreetMapURL {
                            Link("OpenStreetMap", destination: url)
                                .font(.custom("Avenir Next Medium", size: 12))
                        }
                    }
                }
                .padding(16)
                .background(Theme.surface)
            } else {
                EmptyLocationState()
            }
        }
        .background(Theme.background)
    }
}

private struct AccessPointPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionTitle("Nearby Wi‑Fi")
                Spacer()
                Text("\(model.accessPoints.count)")
                    .font(.custom("Menlo", size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.trailing, 16)
            }
            .padding(.top, 16)
            .padding(.leading, 16)

            if model.accessPoints.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No scan yet")
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .foregroundStyle(Theme.ink)
                    Text("Run Scan & Locate to list BSSIDs, signal, and channels.")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(model.accessPoints) { ap in
                    AccessPointRow(ap: ap)
                        .listRowBackground(Theme.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.surface)
    }
}

private struct AccessPointRow: View {
    let ap: AccessPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ap.displaySSID)
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if ap.isCurrent {
                    Text("CONNECTED")
                        .font(.custom("Avenir Next Bold", size: 9))
                        .tracking(0.6)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.15))
                        .foregroundStyle(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Spacer()
                Text("\(ap.rssi) dBm")
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(signalColor)
            }

            Text(ap.bssid)
                .font(.custom("Menlo", size: 11))
                .foregroundStyle(Theme.muted)

            HStack(spacing: 10) {
                MetaTag(ap.band.rawValue)
                MetaTag("Ch \(ap.channel)")
                MetaTag(ap.security)
                MetaTag(ap.signalQuality.rawValue)
            }
        }
        .padding(.vertical, 4)
    }

    private var signalColor: Color {
        switch ap.signalQuality {
        case .excellent: return Theme.good
        case .good: return Theme.accent
        case .fair: return Theme.warn
        case .weak: return Theme.bad
        }
    }
}

private struct EmptyLocationState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Find where this Mac is")
                .font(.custom("Avenir Next Demi Bold", size: 22))
                .foregroundStyle(Theme.ink)
            Text("Scans nearby Wi‑Fi BSSIDs, reads IP addresses, and asks public databases which place those signals belong to.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.background, Theme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(model.lastError == nil ? Theme.good : Theme.bad)
                .frame(width: 8, height: 8)
            Text(model.lastError ?? model.statusMessage)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Spacer()
            if let date = model.lastScanAt {
                Text(date, style: .time)
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }
}

// MARK: - Small building blocks

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.custom("Avenir Next Bold", size: 10))
            .tracking(1.1)
            .foregroundStyle(Theme.muted)
    }
}

private struct InfoCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.custom("Avenir Next", size: 10))
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(mono ? .custom("Menlo", size: 12) : .custom("Avenir Next Medium", size: 12))
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
        }
    }
}

private struct ProviderToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.custom("Avenir Next", size: 12))
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}

private struct MetaTag: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.custom("Avenir Next", size: 10))
            .foregroundStyle(Theme.muted)
    }
}

private struct AccuracyBadge: View {
    let meters: Double

    var body: some View {
        Text("± \(formatted)")
            .font(.custom("Menlo", size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .foregroundStyle(Theme.ink)
    }

    private var formatted: String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }
}

private struct EstimateChip: View {
    let estimate: LocationEstimate
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(estimate.source.shortName)
                    .font(.custom("Avenir Next Demi Bold", size: 11))
                Text("±\(Int(estimate.accuracyMeters)) m")
                    .font(.custom("Menlo", size: 10))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? Theme.accent.opacity(0.15) : Theme.panel)
            .foregroundStyle(selected ? Theme.accent : Theme.ink)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .frame(width: 1100, height: 700)
}
