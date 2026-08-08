import SwiftUI
import WebKit

/// One slide, as Rostrum rendered it.
///
/// The SVG comes from `Presentation.renderSVG(slideAt:)` run on the deck that
/// was actually written — same theme resolution, same placeholder inheritance,
/// same text. Drawing a preview from the `DeckIR` instead would be a second
/// implementation of layout, free to disagree with the file the user opens.
///
/// It is a preview, not a proof. Where the paragraph's typeface is registered
/// the renderer measures real advance widths and breaks lines exactly as the
/// builders did; where it isn't — a face the design names that this machine
/// doesn't have — line breaks come from a character-width estimate and can
/// fall in different places than PowerPoint puts them. `unmeasuredFonts` on
/// the result says which faces those were.
///
/// SwiftUI has no SVG view, and neither `NSImage` nor `UIImage` will load one,
/// so this is a `WKWebView` showing the markup inline: `loadHTMLString` with a
/// nil base URL, which means no network, no file access, and nothing to
/// navigate to.
struct SlidePreview {
    let svg: String

    /// The SVG carries the slide's own background and aspect ratio (an explicit
    /// `viewBox`), so the wrapper only has to stop the web view adding chrome,
    /// margins or a scrollbar around it. Width 100% with `height: auto`
    /// overrides the SVG's pixel width and scales it by the viewBox instead.
    private var document: String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
          svg { display: block; width: 100%; height: auto; }
        </style></head><body>\(svg)</body></html>
        """
    }

    /// Remembers what was last loaded. SwiftUI calls `update…` on every
    /// invalidation, and reloading identical markup would flash the slide.
    /// Also the navigation gatekeeper: a preview shows exactly one document,
    /// loaded by `loadHTMLString`, and nothing in it may navigate anywhere.
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            // `loadHTMLString(_, baseURL: nil)` loads as about:blank; that
            // initial load is the only navigation a preview is allowed.
            let url = navigationAction.request.url
            decisionHandler(url == nil || url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor fileprivate func makeWebView(_ coordinator: Coordinator) -> WKWebView {
        // The SVG is model-derived — a deck drafted from the user's own PDF —
        // and SVG legitimately carries <script>, <foreignObject> and event
        // attributes. `loadHTMLString(_, baseURL: nil)` already denies any
        // network or file origin; turning script execution off closes the
        // scriptable half. A preview is a picture, not a program.
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = coordinator
        #if os(iOS)
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .clear
        #endif
        return view
    }

    @MainActor fileprivate func load(into view: WKWebView, _ coordinator: Coordinator) {
        guard coordinator.loaded != svg else { return }
        coordinator.loaded = svg
        view.loadHTMLString(document, baseURL: nil)
    }
}

#if os(macOS)
extension SlidePreview: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView(context.coordinator) }
    func updateNSView(_ view: WKWebView, context: Context) {
        load(into: view, context.coordinator)
    }
}
#else
extension SlidePreview: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView(context.coordinator) }
    func updateUIView(_ view: WKWebView, context: Context) {
        load(into: view, context.coordinator)
    }
}
#endif

/// The contact sheet for a finished deck: every slide, in order, three across
/// and scrolling down — the sheet a designer lays out to read a deck's rhythm
/// rather than its words.
struct SlideContactSheet: View {
    let previews: [String]
    /// Index-aligned slide titles; when present, VoiceOver hears what a tile
    /// says, not just where it sits in the grid.
    var titles: [String] = []
    /// Fixed at three so the grid reads as a contact sheet at any window size;
    /// the tiles resize, the column count does not.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    fileprivate func label(_ index: Int) -> String {
        slideLabel(index, of: previews.count, titles: titles)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(previews.enumerated()), id: \.offset) { index, svg in
                    SlidePreview(svg: svg)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.primary.opacity(0.12)))
                        .overlay(alignment: .bottomTrailing) {
                            Text("\(index + 1)")
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.thinMaterial, in: Capsule())
                                .padding(5)
                        }
                        .accessibilityLabel(label(index))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

/// "Slide 3 of 12: Why now" — position always, the slide's own words when the
/// deck has them. The webview beneath is opaque to VoiceOver, so this label is
/// the payoff screen's entire accessible surface.
private func slideLabel(_ index: Int, of count: Int, titles: [String]) -> String {
    let base = "Slide \(index + 1) of \(count)"
    guard titles.indices.contains(index), !titles[index].isEmpty else { return base }
    return "\(base): \(titles[index])"
}

/// The filmstrip under a finished deck: every slide, in order, at a glance.
struct SlideFilmstrip: View {
    let previews: [String]
    var titles: [String] = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(previews.enumerated()), id: \.offset) { index, svg in
                    SlidePreview(svg: svg)
                        .frame(width: 240, height: 135)   // 16:9
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.primary.opacity(0.12)))
                        .overlay(alignment: .bottomTrailing) {
                            Text("\(index + 1)")
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.thinMaterial, in: Capsule())
                                .padding(6)
                        }
                        .accessibilityLabel(slideLabel(index, of: previews.count, titles: titles))
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .frame(height: 152)
    }
}
