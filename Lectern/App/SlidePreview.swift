import SwiftUI
import WebKit

/// One slide, as Rostrum rendered it.
///
/// The SVG comes from `Presentation.renderSVG(slideAt:)` run on the deck that
/// was actually written — same theme resolution, same placeholder inheritance,
/// same line breaking, measured with the same fonts the builders used. Drawing
/// a preview from the `DeckIR` instead would be a second implementation of
/// layout, free to disagree with the file the user opens.
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
    @MainActor final class Coordinator {
        var loaded: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor fileprivate func makeWebView() -> WKWebView {
        let view = WKWebView()
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
    func makeNSView(context: Context) -> WKWebView { makeWebView() }
    func updateNSView(_ view: WKWebView, context: Context) {
        load(into: view, context.coordinator)
    }
}
#else
extension SlidePreview: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView() }
    func updateUIView(_ view: WKWebView, context: Context) {
        load(into: view, context.coordinator)
    }
}
#endif

/// The filmstrip under a finished deck: every slide, in order, at a glance.
struct SlideFilmstrip: View {
    let previews: [String]

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
                        .accessibilityLabel("Slide \(index + 1) of \(previews.count)")
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .frame(height: 152)
    }
}
