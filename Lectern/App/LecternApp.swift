import SwiftUI
#if os(macOS)
import AppKit

// Blocks quit while a deck is generating: an in-flight generation is a paid
// API call, so any quit path that sends a proper quit event (⌘Q, scripted
// `quit app`, logout) must confirm first. SIGKILL still bypasses this.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var app: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard app?.phase == .generating else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "A deck is still generating"
        alert.informativeText =
            "Quitting now abandons the in-flight generation and its API spend."
        alert.addButton(withTitle: "Keep Generating")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
    }
}

#endif

// Xcode app target entry point, shared by the macOS and iOS/iPadOS targets.
// (Not built by `swift test`, which builds LecternCore only.) Liquid Glass
// styling per §3 — system components: .buttonStyle(.glass)/.glassProminent for
// actions, standard toolbar/sheets. On iOS there is no Settings scene or window
// frame to manage — ContentView presents Settings as a sheet, and the quit
// guard has no equivalent (iOS apps aren't quit through an event we can veto).
@main
struct LecternApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup("Lectern") {
            ContentView()
                .environment(app)
                #if os(macOS)
                .onAppear { delegate.app = app }
                #endif
        }
        #if os(macOS)
        // Sizes a window AppKit has never seen; after that, the user's own
        // frame — resized, moved, tiled, restored — is theirs to keep. The
        // app used to scrub the saved frame and force this size on every
        // launch, which read as broken window management on macOS.
        .defaultSize(width: 780, height: 1060)
        .commands { lecternCommands }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(app)
        }
        #endif
    }

    #if os(macOS)
    /// The app's own menus.
    ///
    /// Without this the app inherits SwiftUI's defaults — a File menu offering
    /// New Window and Print, an Edit menu offering Undo — none of which do
    /// anything here. Replacing the ones that are wrong is as much of the job
    /// as adding the ones that are missing.
    @CommandsBuilder private var lecternCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Deck") { app.reset() }
                .keyboardShortcut("n")
                // Generating is paid work in flight; the quit guard already
                // refuses to abandon it silently and this must not either.
                .disabled(app.phase == .generating)
            Button("Your Decks") { app.isShowingLibrary = true }
                .keyboardShortcut("l")
                .disabled(app.library.isEmpty)
            Divider()
            Button("Open Decks Folder") {
                let directory = AppState.decksDirectory()
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                NSWorkspace.shared.open(directory)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .help) {
            Link("Lectern Help",
                 destination: URL(string: "https://github.com/welshofer/rostrum/blob/main/Lectern/README.md")!)
        }
    }
    #endif
}
