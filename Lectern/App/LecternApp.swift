import SwiftUI

// Xcode app target entry point. (Not built by `swift test`, which builds
// LecternCore only.) Liquid Glass styling per §3 — use system components:
// .buttonStyle(.glass) for the primary action, glassEffect, standard toolbar/
// sidebar/inspector. Kept standard here so the scaffold compiles on the current
// toolchain; swap to the glass modifiers when targeting macOS 26.
@main
struct LecternApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup("Lectern") {
            ContentView()
                .environment(app)
        }
        .defaultSize(width: 760, height: 940)
        Settings {
            SettingsView()
                .environment(app)
        }
    }
}
