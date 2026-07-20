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

// Forces the main window to the declared launch frame. `.defaultSize` only
// applies to never-before-seen windows; both NSWindow frame autosave and macOS
// state restoration resurrect the previous frame on later launches. This view
// sits invisibly in the window and re-asserts the declared frame when the
// window attaches, overriding whatever was restored. Height is clamped to the
// screen's visible area when the display is too short.
private final class LaunchFrameView: NSView {
    static let launchSize = NSSize(width: 780, height: 1060)
    private var enforced = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !enforced, window != nil else { return }
        enforced = true
        enforce()
        // Re-assert on the next runloop tick in case restoration applies its
        // frame after the content view is attached.
        DispatchQueue.main.async { [weak self] in self?.enforce() }
    }

    private func enforce() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        window.isRestorable = false
        let visible = screen.visibleFrame
        let height = min(Self.launchSize.height, visible.height)
        window.setFrame(
            NSRect(x: (visible.midX - Self.launchSize.width / 2).rounded(),
                   y: visible.maxY - height,
                   width: Self.launchSize.width,
                   height: height),
            display: true)
    }
}

private struct LaunchFrame: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { LaunchFrameView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
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

    init() {
        #if os(macOS)
        // .defaultSize only applies to windows AppKit has never seen; after
        // that, launch restores the last saved frame from user defaults.
        // Scrub the main window's saved frame (but not Settings') so every
        // launch starts at the size declared below.
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("NSWindow Frame") && key.contains("AppWindow") {
            defaults.removeObject(forKey: key)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup("Lectern") {
            ContentView()
                .environment(app)
                #if os(macOS)
                .background(LaunchFrame())
                .onAppear { delegate.app = app }
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 780, height: 1060)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(app)
        }
        #endif
    }
}
