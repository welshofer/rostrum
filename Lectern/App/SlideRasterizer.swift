import SwiftUI
import WebKit
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
    struct CacheKey: Hashable {
        let svg: String
        let width: Int
        let height: Int
    }
    private var cache: BoundedCache<CacheKey, Image>
    private var host: SnapshotHost?

    // One web view means one render at a time. The gate is what makes that a
    // queue rather than a race.
    private var busy = false
    private var waiting: [(id: UUID, continuation: CheckedContinuation<Bool, Never>)] = []
    private let snapshotOverride: (@MainActor (String, CGSize) async -> Image?)?
    static let maximumPendingRequests = 64

    /// Tests can supply a snapshot operation without creating a window.
    init(capacity: Int = SlideRasterizer.defaultCapacity,
         snapshot: (@MainActor (String, CGSize) async -> Image?)? = nil) {
        cache = BoundedCache(capacity: capacity)
        snapshotOverride = snapshot
    }

    func cached(_ key: CacheKey) -> Image? { cache.value(forKey: key) }
    var cacheCount: Int { cache.count }
    var pendingCount: Int { waiting.count }

    func image(for svg: String, pixelWidth: CGFloat = 640) async -> Image? {
        guard !Task.isCancelled,
              let size = SlidePreviewGeometry(svg: svg)?.snapshotSize(pixelWidth: pixelWidth) else { return nil }
        let key = Self.key(for: svg, size: size)
        if let hit = cached(key) { return hit }
        guard await acquire() else { return nil }
        defer { release() }
        guard !Task.isCancelled else { return nil }
        if let hit = cached(key) { return hit }

        let image: Image?
        if let snapshotOverride { image = await snapshotOverride(svg, size) }
        else {
            let host = host ?? SnapshotHost()
            self.host = host
            image = await host.snapshot(svg: svg, size: size)
        }
        guard !Task.isCancelled, let image else { return nil }
        remember(image, forKey: key)
        return image
    }

    func remember(_ image: Image, forKey key: CacheKey) { cache.insert(image, forKey: key) }

    /// Full content equality avoids hash collisions; normalized dimensions keep
    /// a small thumbnail from satisfying a later high-resolution request.
    static func key(for svg: String, size: CGSize) -> CacheKey {
        CacheKey(svg: svg, width: Int(size.width), height: Int(size.height))
    }

    private func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }
        if !busy { busy = true; return true }
        guard waiting.count < Self.maximumPendingRequests else { return false }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(returning: false); return }
                waiting.append((id, continuation))
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, let index = self.waiting.firstIndex(where: { $0.id == id }) else { return }
                self.waiting.remove(at: index).continuation.resume(returning: false)
            }
        }
    }

    private func release() {
        if waiting.isEmpty { busy = false }
        else { waiting.removeFirst().continuation.resume(returning: true) }
    }

}

/// Completes exactly once, even if WebKit never replies or replies after a
/// timeout/cancellation. One instance belongs to one snapshot, so a stale
/// callback can never complete a subsequent slide's request.
@MainActor
final class SlideSnapshotRequest<Value: Sendable> {
    private var continuation: CheckedContinuation<Value?, Never>?
    private var timer: Task<Void, Never>?
    private var stop: (() -> Void)?
    private var started = false
    private var finished = false

    func value(timeout: Duration, start: () -> Void, stop: @escaping () -> Void) async -> Value? {
        guard !started else { return nil }
        started = true
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !finished else { continuation.resume(returning: nil); return }
                self.continuation = continuation
                self.stop = stop
                guard !Task.isCancelled else { finish(nil); return }
                timer = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.finish(nil)
                }
                start()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(nil) }
        }
    }

    func finish(_ value: Value?) {
        guard !finished else { return }
        finished = true
        timer?.cancel(); timer = nil
        let continuation = continuation
        self.continuation = nil
        let stop = stop
        self.stop = nil
        if value == nil { stop?() }
        continuation?.resume(returning: value)
    }
}

/// The one off-screen web view, and the window it has to live in.
///
/// `takeSnapshot` renders what is on screen, so a view with no window produces
/// nothing. An ordinary borderless `NSWindow` placed far off any display is the
/// documented way to give it one without showing anything.
@MainActor
private final class SnapshotHost: NSObject, WKNavigationDelegate {
    private let window: NSWindow
    private let webView: WKWebView
    private var request: SlideSnapshotRequest<Image>?
    private var navigation: WKNavigation?
    private var snapshotSize: CGSize = .zero

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

    func snapshot(svg: String, size: CGSize) async -> Image? {
        let request = SlideSnapshotRequest<Image>()
        self.request = request
        snapshotSize = size
        window.setContentSize(size)
        webView.frame = NSRect(origin: .zero, size: size)
        let image = await request.value(timeout: .seconds(10), start: {
            navigation = webView.loadHTMLString(Self.document(svg: svg), baseURL: nil)
        }, stop: { [weak self] in self?.webView.stopLoading() })
        if self.request === request { self.request = nil; navigation = nil }
        return image
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === self.navigation, let request else { return }
        let config = WKSnapshotConfiguration()
        config.rect = NSRect(origin: .zero, size: snapshotSize)
        config.snapshotWidth = NSNumber(value: Double(snapshotSize.width))
        webView.takeSnapshot(with: config) { image, _ in
            request.finish(image.map { Image(nsImage: $0) })
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if navigation === self.navigation { request?.finish(nil) }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if navigation === self.navigation { request?.finish(nil) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { request?.finish(nil) }

    /// The SVG carries its own background and aspect ratio; this only stops the
    /// web view adding chrome around it.
    private static func document(svg: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <style>
          html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
          svg { display: block; width: 100%; height: 100%; }
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
            image = nil
            let rendered = await SlideRasterizer.shared.image(for: svg)
            guard !Task.isCancelled else { return }
            image = rendered
        }
    }
    #else
    var body: some View { SlidePreview(svg: svg) }
    #endif
}
