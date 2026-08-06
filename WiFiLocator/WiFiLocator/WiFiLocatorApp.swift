import SwiftUI
import AppKit

@main
struct WiFiLocatorApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Scan Wi‑Fi & Locate") {
                    Task { await appModel.scanAndLocate() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(appModel.isBusy)

                Button("Scan Wi‑Fi Only") {
                    Task { await appModel.scanNetworksOnly() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(appModel.isBusy)

                Divider()

                Button("Copy Selected Coordinates") {
                    appModel.copySelectedCoordinates()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(appModel.selectedEstimate == nil)

                Button("Export Scan JSON…") {
                    if let url = appModel.exportScanReport() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appModel.accessPoints.isEmpty && appModel.estimates.isEmpty)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
    }
}
