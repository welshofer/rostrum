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
    /// Accounted SVG UTF-8 bytes plus bitmap backing estimates. This does not
    /// bound WebKit processes, view-held images, allocator or GPU overhead.
    static let defaultByteLimit = 256 * 1024 * 1024

    /// Keyed by the markup itself — the same slide re-inspected is the same
    /// picture, and two slides that happen to be identical cost one render.
    struct CacheKey: Hashable {
        let content: PreviewContent
        var svg: String { content.svg }
        let width: Int
        let height: Int

        init(content: PreviewContent, width: Int, height: Int) {
            self.content = content; self.width = width; self.height = height
        }
        init(svg: String, width: Int, height: Int) {
            self.init(content: PreviewContent(svg: svg), width: width, height: height)
        }
    }
    private let cache: CostLimitedCache<CacheKey, Image>
    private var host: SnapshotHost?
    private let shareFontResources: Bool

    // One web view means one render at a time. The gate is what makes that a
    // queue rather than a race.
    private var busy = false
    private var waiting: [(id: UUID, continuation: CheckedContinuation<Bool, Never>)] = []
    private let snapshotOverride: (@MainActor (String, CGSize) async -> Image?)?
    static let maximumPendingRequests = 64

    /// Tests can supply a snapshot operation without creating a window.
    init(capacity: Int = SlideRasterizer.defaultCapacity,
         byteLimit: Int = SlideRasterizer.defaultByteLimit,
         shareFontResources: Bool = false,
         snapshot: (@MainActor (String, CGSize) async -> Image?)? = nil) {
        cache = CostLimitedCache(capacity: capacity, costLimit: byteLimit)
        self.shareFontResources = shareFontResources
        snapshotOverride = snapshot
    }

    func cached(_ key: CacheKey) -> Image? {
        PipelineTrace.measure("thumbnail.cacheLookup") { cache.value(forKey: key) }
    }
    var cacheCount: Int { cache.count }
    var cacheCostBytes: Int { cache.totalCost }
    var cacheByteLimit: Int { cache.costLimit }
    var pendingCount: Int { waiting.count }
    var fontResourceStatistics: [String: Int] { host?.fontResourceStatistics ?? [:] }

    func image(for svg: String, pixelWidth: CGFloat = 640) async -> Image? {
        guard !Task.isCancelled else { return nil }
        return await image(for: PreviewContent(svg: svg), pixelWidth: pixelWidth)
    }

    func image(for content: PreviewContent, pixelWidth: CGFloat = 640) async -> Image? {
        let request = PipelineTrace.begin("thumbnail.request")
        var outcome = "unavailable"
        defer { request?.end(outcome: Task.isCancelled ? "cancelled" : outcome) }
        guard !Task.isCancelled,
              let size = PipelineTrace.measure("thumbnail.geometry", {
                  SlidePreviewGeometry(svg: content.svg)?.snapshotSize(pixelWidth: pixelWidth)
              }) else { return nil }
        let key = CacheKey(content: content, width: Int(size.width), height: Int(size.height))
        if let hit = cached(key) { outcome = "cacheHit"; return hit }
        let queue = PipelineTrace.begin("thumbnail.queue")
        let acquired = await acquire()
        queue?.end(outcome: acquired ? "acquired" : "refused")
        guard acquired else { return nil }
        defer { release() }
        guard !Task.isCancelled else { return nil }
        if let hit = cached(key) { outcome = "cacheHitAfterQueue"; return hit }

        let image: Image?
        var bitmapBytes = Self.bitmapCost(width: key.width, height: key.height)
        if let snapshotOverride { image = await snapshotOverride(content.svg, size) }
        else {
            let host = host ?? SnapshotHost(shareFontResources: shareFontResources)
            self.host = host
            if let bitmap = await host.snapshot(svg: content.svg, size: size) {
                bitmapBytes = Self.bitmapCost(bitmap, fallback: bitmapBytes)
                image = Image(nsImage: bitmap)
            } else { image = nil }
        }
        guard !Task.isCancelled, let image else { return nil }
        remember(image, forKey: key, bitmapBytes: bitmapBytes)
        outcome = "rendered"
        return image
    }

    /// Only an owning test/tool should close its private rasterizer.
    func close() { host?.close(); host = nil }

    func remember(_ image: Image, forKey key: CacheKey, bitmapBytes: Int? = nil) {
        let bitmap = bitmapBytes ?? Self.bitmapCost(width: key.width, height: key.height)
        let (cost, overflow) = key.content.byteCount.addingReportingOverflow(bitmap)
        let span = PipelineTrace.begin("thumbnail.cacheInsert")
        let admitted = !overflow && bitmap >= 0 && cache.insert(image, forKey: key, cost: cost)
        span?.end(outcome: admitted ? "admitted" : "overBudget")
    }

    static func bitmapCost(width: Int, height: Int) -> Int {
        guard width > 0, height > 0 else { return 0 }
        let (pixels, pixelOverflow) = width.multipliedReportingOverflow(by: height)
        let (bytes, byteOverflow) = pixels.multipliedReportingOverflow(by: 4)
        return pixelOverflow || byteOverflow ? Int.max : bytes
    }

    private static func bitmapCost(_ image: NSImage, fallback: Int) -> Int {
        var total = 0
        for representation in image.representations {
            let bytes: Int
            if let bitmap = representation as? NSBitmapImageRep {
                let (count, overflow) = bitmap.bytesPerRow.multipliedReportingOverflow(by: bitmap.pixelsHigh)
                bytes = overflow ? Int.max : max(0, count)
            } else {
                bytes = bitmapCost(width: representation.pixelsWide, height: representation.pixelsHigh)
            }
            let (sum, overflow) = total.addingReportingOverflow(bytes)
            total = overflow ? Int.max : sum
        }
        return max(fallback, total)
    }

    /// Full content equality avoids hash collisions; normalized dimensions keep
    /// a small thumbnail from satisfying a later high-resolution request.
    static func key(for svg: String, size: CGSize) -> CacheKey {
        CacheKey(svg: svg, width: Int(size.width), height: Int(size.height))
    }

    static func size(for svg: String, pixelWidth: CGFloat = 640) -> CGSize {
        SlidePreviewGeometry(svg: svg)?.snapshotSize(pixelWidth: pixelWidth) ?? CGSize(width: 640, height: 360)
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
final class SnapshotHost: NSObject, WKNavigationDelegate {
    struct VectorCapture: Sendable {
        let pdf: Data
        let fontReadinessJSON: String
        let viewport: CGSize
    }

    private enum Capture: Sendable {
        case bitmap(NSImage)
        case vector(VectorCapture)
    }
    private enum Mode { case bitmap, vector }
    private let window: NSWindow
    private let webView: WKWebView
    private var fontResources: PreviewFontResources?
    private let fontHandler: PreviewFontSchemeHandler?
    private var sourceSVGBytes = 0
    private var loadedSVGBytes = 0
    private var request: SlideSnapshotRequest<Capture>?
    private var navigation: WKNavigation?
    private var snapshotSize: CGSize = .zero
    private var mode: Mode = .bitmap
    private var trace: PipelineTrace?
    private var phase: PipelineTrace.Span?
    private(set) var lastCaptureFailure: String?
    var isCapturing: Bool { request != nil && navigation != nil }

    var fontResourceStatistics: [String: Int] {
        ["sourceSVGBytes": sourceSVGBytes, "loadedSVGBytes": loadedSVGBytes,
         "retainedBytes": fontResources?.retainedBytes ?? 0,
         "retainedCount": fontResources?.retainedCount ?? 0,
         "decodedResources": fontResources?.decodedResources ?? 0,
         "servedFontBytes": fontHandler?.servedBytes ?? 0,
         "servedFontRequests": fontHandler?.servedRequests ?? 0]
    }

    init(shareFontResources: Bool = false) {
        let config = WKWebViewConfiguration()
        if shareFontResources {
            fontResources = PreviewFontResources()
            let handler = PreviewFontSchemeHandler()
            fontHandler = handler
            config.setURLSchemeHandler(handler, forURLScheme: PreviewFontResources.scheme)
        } else { fontResources = nil; fontHandler = nil }
        // Same rule as the live preview: the markup is model-derived and SVG
        // can carry script. A picture is not a program.
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        // And not a network client either: the block-all rule list (see
        // PreviewContentRules for the three layers and their ordering). The
        // navigation gate below and the document's CSP cover the first load
        // if the list is still compiling.
        PreviewContentRules.attach(to: config)
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

    func snapshot(svg: String, size: CGSize) async -> NSImage? {
        guard let result = await capture(svg: svg, size: size, mode: .bitmap),
              case .bitmap(let image) = result else { return nil }
        return image
    }

    /// Captures the same loaded SVG as the bitmap path, retaining vector glyphs
    /// for independent inspection. It does not establish native Office parity.
    func vectorCapture(svg: String, size: CGSize) async -> VectorCapture? {
        guard let result = await capture(svg: svg, size: size, mode: .vector),
              case .vector(let capture) = result else { return nil }
        return capture
    }

    private func capture(svg: String, size: CGSize, mode: Mode) async -> Capture? {
        guard request == nil, !Task.isCancelled, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        let request = SlideSnapshotRequest<Capture>()
        self.request = request
        trace = PipelineTrace.current
        defer {
            phase?.end(outcome: Task.isCancelled ? "cancelled" : "failed")
            phase = nil; trace = nil
            fontHandler?.resources.removeAll()
        }
        self.mode = mode
        lastCaptureFailure = nil
        snapshotSize = size
        window.setContentSize(size)
        webView.frame = NSRect(origin: .zero, size: size)
        let markup: String
        if let fontResources {
            let prepared = PipelineTrace.measure("thumbnail.fontResources") { fontResources.prepare(svg: svg) }
            fontHandler?.resources = Dictionary(uniqueKeysWithValues: prepared.resources.map { ($0.url, $0) })
            markup = prepared.svg
        } else { markup = svg }
        sourceSVGBytes += svg.utf8.count
        loadedSVGBytes += markup.utf8.count
        let document = PipelineTrace.measure("thumbnail.document") { Self.document(svg: markup) }
        phase = PipelineTrace.begin("thumbnail.navigation")
        let result = await request.value(timeout: .seconds(10), start: {
            navigation = webView.loadHTMLString(document, baseURL: nil)
        }, stop: { [weak self] in
            guard let self else { return }
            if lastCaptureFailure == nil { lastCaptureFailure = "Capture cancelled or timed out." }
            webView.stopLoading()
        })
        if self.request === request { self.request = nil; navigation = nil }
        return result
    }

    /// Tests and short-lived export callers dispose only their owned host.
    func close() {
        request?.finish(nil)
        navigation = nil
        webView.stopLoading()
        fontHandler?.resources.removeAll()
        fontResources = nil
        window.orderOut(nil)
        window.close()
    }

    /// The same gate as the live preview's coordinator: the `about:blank` that
    /// `loadHTMLString(_, baseURL: nil)` loads as is the only navigation an
    /// offscreen render may make (fonts are subresources, not navigations).
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        decisionHandler(PreviewPolicy.allows(navigationAction.request.url) ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === self.navigation, let request else { return }
        phase?.end()
        phase = PipelineTrace.$current.withValue(trace) { PipelineTrace.begin("thumbnail.fontReadiness") }
        // API-injected script remains available with page scripting disabled.
        // Font promises and the request deadline are bounded; offscreen windows
        // may throttle animation frames, so readiness does not depend on rAF.
        webView.callAsyncJavaScript(Self.fontReadinessScript, arguments: [:], in: nil, in: .defaultClient) { [weak self] result in
            guard let self, navigation === self.navigation, self.request === request else { return }
            switch result {
            case .failure(let error):
                self.lastCaptureFailure = "Font readiness failed: \(error.localizedDescription)"
                request.finish(nil)
            case .success(let value):
                guard let readiness = value as? String else {
                    self.lastCaptureFailure = "Font readiness returned no receipt."
                    request.finish(nil)
                    return
                }
                self.phase?.end()
                self.phase = PipelineTrace.$current.withValue(self.trace) {
                    PipelineTrace.begin(self.mode == .bitmap ? "thumbnail.snapshot" : "thumbnail.pdf")
                }
                self.finishCapture(request, navigation: navigation, readiness: readiness)
            }
        }
    }

    private func finishCapture(_ request: SlideSnapshotRequest<Capture>, navigation: WKNavigation?, readiness: String) {
        let size = snapshotSize
        switch mode {
        case .bitmap:
            let config = WKSnapshotConfiguration()
            config.rect = NSRect(origin: .zero, size: size)
            config.snapshotWidth = NSNumber(value: Double(size.width))
            webView.takeSnapshot(with: config) { [weak self] image, error in
                guard let self, navigation === self.navigation, self.request === request else { return }
                if let error { self.lastCaptureFailure = "Snapshot failed: \(error.localizedDescription)" }
                self.phase?.end(outcome: image == nil ? "failed" : "completed")
                request.finish(image.map(Capture.bitmap))
            }
        case .vector:
            let config = WKPDFConfiguration()
            config.rect = NSRect(origin: .zero, size: size)
            webView.createPDF(configuration: config) { [weak self] result in
                guard let self, navigation === self.navigation, self.request === request else { return }
                switch result {
                case .success(let data):
                    self.phase?.end()
                    request.finish(.vector(.init(pdf: data, fontReadinessJSON: readiness, viewport: size)))
                case .failure(let error):
                    self.lastCaptureFailure = "PDF capture failed: \(error.localizedDescription)"
                    request.finish(nil)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if navigation === self.navigation {
            lastCaptureFailure = "Navigation failed: \(error.localizedDescription)"
            request?.finish(nil)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if navigation === self.navigation {
            lastCaptureFailure = "Navigation failed: \(error.localizedDescription)"
            request?.finish(nil)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        lastCaptureFailure = "Web content process terminated."
        request?.finish(nil)
    }

    private static let fontReadinessScript = """
    const normalize = value => value.trim().replace(/^['"]|['"]$/g, '');
    const families = new Set();
    for (const node of document.querySelectorAll('svg text, svg tspan')) {
        for (const family of getComputedStyle(node).fontFamily.split(',')) families.add(normalize(family));
    }
    const faces = Array.from(document.fonts).filter(face => families.has(normalize(face.family)));
    let timer;
    try {
        await Promise.race([
            (async () => {
                document.body.getBoundingClientRect();
                await Promise.all(faces.map(face => face.load()));
                await document.fonts.ready;
                document.body.getBoundingClientRect();
            })(),
            new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Embedded font readiness timed out.')), 5000); })
        ]);
    } finally { clearTimeout(timer); }
    if (faces.some(face => face.status !== 'loaded')) throw new Error('A used embedded font did not load.');
    return JSON.stringify({status: document.fonts.status, usedFamilies: Array.from(families).sort(),
        faces: faces.map(face => ({family: face.family, status: face.status, style: face.style, weight: face.weight})),
        viewport: {width: innerWidth, height: innerHeight}});
    """

    /// The SVG carries its own background and aspect ratio; this only stops the
    /// web view adding chrome around it — and, through the CSP, stops anything
    /// in the markup fetching beyond inline, `data:` and the font scheme.
    static func document(svg: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        \(PreviewPolicy.contentSecurityPolicyMeta)
        <style>
          html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
          body > svg { display: block; width: 100%; height: 100%; }
        </style></head><body>\(svg)</body></html>
        """
    }
}
#endif

/// One slide in a grid: a picture on macOS, the live preview elsewhere.
struct SlideTile: View {
    let content: PreviewContent

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
        .task(id: content) {
            image = nil
            let rendered = await SlideRasterizer.shared.image(for: content)
            guard !Task.isCancelled else { return }
            image = rendered
        }
    }
    #else
    var body: some View { SlidePreview(svg: content.svg) }
    #endif
}
