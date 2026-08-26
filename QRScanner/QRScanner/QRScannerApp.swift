import SwiftUI

@main
struct QRScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
