import SwiftUI
import WebKit
import LecternCore
#if os(macOS)
import AppKit

/// Turns a slide's SVG into a picture, once.
///
/// The contact sheet used to be a `WKWebView` per tile. A sixty-slide deck is
/// then sixty web content processes, each with its own renderer, and scrolling
/// a grid of them is exactly as heavy as it sounds. SwiftUI has no SVG view and
/// AppKit will not load one, so *something* has to be WebKit — but it can be
/// one web view, off screen, run once per slide, with the result cached.
///
/// The grid then holds `Image`s, which is what it always wanted to hold.
///
/// macOS only. iOS keeps the live preview: `WKWebView.takeSnapshot` needs the
/// view in a window, and iOS has no equivalent of an off-screen `NSWindow` to
/// put one in without commandeering the app's own.
@MainActor
final class SlideRasterizer {
    static let shared = SlideRasterizer()

    /// Hard ceiling on rendered slides. A contact sheet is one deck's slides —
    /// "typically tens" — so a single deck fits with plenty of room. 256 keeps
    /// several recently-viewed decks resident before the least-recently-used
    /// slide is dropped, which bounds a long session (this otherwise held a
    /// picture per slide of *every* deck opened, forever) while capping the
    /// worst case to a few hundred renders rather than an unbounded pile.
    static let defaultCapacity = 256

    /// Keyed by the markup itself — the same slide re-inspected is the same
    /// picture, and two slides that happen to be identical cost one render.
    private var cache: BoundedCache<String, Image>
    private var host: SnapshotHost?

    // One web view means one render at a time. The gate is what makes that a
    // queue rather than a race.
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// Custom-capacity initialiser: production uses the default; tests pass a
    /// small cap to assert the cache stays bounded without the shared singleton.
    init(capacity: Int = SlideRasterizer.defaultCapacity) {
        cache = BoundedCache(capacity: capacity)
    }

    /// A cached render, marked most-recently-used on a hit. Synchronous, so the
    /// gate below is only ever taken for a slide that genuinely needs drawing.
    func cached(_ key: String) -> Image? { cache.value(forKey: key) }

    /// Live entry count. Exposed so tests can assert the cache never grows past
    /// its cap.
    var cacheCount: Int { cache.count }

    func image(for svg: String, pixelWidth: CGFloat = 640) async -> Image? {
        let size = Self.size(for: svg, pixelWidth: pixelWidth)
        let key = Self.key(for: svg, size: size)
        if let hit = cached(key) { return hit }

        await acquire()
        defer { release() }
        // A queued caller may have rendered this very slide while we waited.
        if let hit = cached(key) { return hit }

        let host = host ?? SnapshotHost()
        self.host = host
        guard let bitmap = await host.snapshot(svg: svg, size: size) else { return nil }
        let image = Image(nsImage: bitmap)
        remember(image, forKey: key)
        return image
    }

    /// Records a finished render, evicting the least-recently-used entry once
    /// the cache is full. Internal so a test can seed the cache without standing
    /// up the off-screen web view.
    func remember(_ image: Image, forKey key: String) {
        cache.insert(image, forKey: key)
    }

    static func size(for svg: String, pixelWidth: CGFloat = 640) -> NSSize {
        let geometry = SlidePreviewGeometry(svg: svg).fitted(toWidth: Double(pixelWidth))
        return NSSize(width: geometry.width, height: geometry.height)
    }

    /// The cache is process-local. Swift's string hashing avoids a per-byte Swift
    /// loop over embedded image payloads; dimensions separate different resolutions.
    static func key(for svg: String, size: NSSize) -> String {
        var hasher = Hasher()
        hasher.combine(svg)
        hasher.combine(size.width)
        hasher.combine(size.height)
        return String(hasher.finalize())
    }

    private func acquire() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty { busy = false } else { waiting.removeFirst().resume() }
    }
}

/// The one off-screen web view, and the window it has to live in.
///
/// `takeSnapshot` renders what is on screen, so a view with no window produces
/// nothing. An ordinary borderless `NSWindow` placed far off any display is the
/// documented way to give it one without showing anything.
@MainActor
final class SnapshotHost: NSObject, WKNavigationDelegate {
    private let window: NSWindow
    private let webView: WKWebView
    private var loaded: CheckedContinuation<Void, Never>?

    override init() {
        let config = WKWebViewConfiguration()
        // Same rule as the live preview: the markup is model-derived and SVG
        // can carry script. A picture is not a program.
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: config)
        window = NSWindow(contentRect: .zero,
                          styleMask: [.borderless],
                          backing: .buffered,
                          defer: false)
        super.init()
        webView.navigationDelegate = self
        window.isReleasedWhenClosed = false
        window.contentView = webView
        // It has to be a real, rendering window — `takeSnapshot` captures what
        // was drawn, and a window that never draws yields nothing — but it must
        // not behave like one of the app's own. Without this it turns up in the
        // Window menu, in Mission Control, in window cycling, and in anything
        // that asks the app what windows it has.
        window.isExcludedFromWindowsMenu = true
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenNone]
        // Off every screen rather than merely hidden: an ordered-out window
        // does not render, and a rendered one must not be visible.
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderBack(nil)
    }

    func snapshot(svg: String, size: NSSize) async -> NSImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        window.setContentSize(size)
        webView.frame = NSRect(origin: .zero, size: size)

        await withCheckedContinuation { continuation in
            loaded = continuation
            webView.loadHTMLString(Self.document(svg: svg), baseURL: nil)
        }

        let config = WKSnapshotConfiguration()
        config.rect = NSRect(origin: .zero, size: size)
        guard let image = try? await webView.takeSnapshot(configuration: config) else { return nil }
        return image
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded?.resume(); loaded = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loaded?.resume(); loaded = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        loaded?.resume(); loaded = nil
    }

    /// The SVG carries its own background and aspect ratio; this only stops the
    /// web view adding chrome around it.
    private static func document(svg: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <style>
          html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
          svg { display: block; width: 100%; height: auto; }
        </style></head><body>\(svg)</body></html>
        """
    }
}
#endif

/// One slide in a grid: a picture on macOS, the live preview elsewhere.
struct SlideTile: View {
    let svg: String

    #if os(macOS)
    @State private var image: Image?

    var body: some View {
        ZStack {
            if let image {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                Rectangle().fill(.quaternary.opacity(0.4))
            }
        }
        .task(id: svg) {
            image = await SlideRasterizer.shared.image(for: svg)
        }
    }
    #else
    var body: some View { SlidePreview(svg: svg) }
    #endif
}
