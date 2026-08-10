import SwiftUI
import QuickLookThumbnailing
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Thumbnails that survive the view being torn down.
///
/// `DeckThumbnail` used to hold its picture in `@State`, which dies with the
/// view — and the grid's views die every time you leave the library. Coming
/// back therefore re-requested every visible thumbnail from Quick Look and
/// re-decoded every one of them, on the exact frame the return transition
/// started. That is what the stutter was.
///
/// Keyed by path, modification date and the width it was asked for, so a deck
/// rewritten in place gets a fresh picture, and the same deck at two sizes gets
/// two entries rather than the wrong one.
@MainActor
final class DeckThumbnailStore {
    static let shared = DeckThumbnailStore()

    private var cache: [String: Image] = [:]
    private var inFlight: [String: Task<Image?, Never>] = [:]

    /// A hit means the grid can draw immediately, with no async work at all —
    /// which is the whole point.
    func cached(_ key: String) -> Image? { cache[key] }

    static func key(url: URL, version: Date, width: CGFloat) -> String {
        "\(url.path)|\(version.timeIntervalSince1970)|\(Int(width))"
    }

    func thumbnail(url: URL, key: String, width: CGFloat, scale: CGFloat) async -> Image? {
        if let hit = cache[key] { return hit }
        if let running = inFlight[key] { return await running.value }

        let task = Task<Image?, Never> {
            await Self.generate(url: url, width: width, scale: scale)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { cache[key] = image }
        return image
    }

    /// Asks for the size it will actually be drawn at.
    ///
    /// This used to ask for 640×400 whatever the caller did with it — at 2×
    /// that is 1280×800 of bitmap per card, and the list drew it into 44×25
    /// points. Twelve oversized decodes is both the memory and the frames.
    private static func generate(url: URL, width: CGFloat, scale: CGFloat) async -> Image? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: width, height: (width * 9 / 16).rounded()),
            scale: scale,
            representationTypes: .thumbnail)
        guard let generated = try? await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: request) else { return nil }
        #if os(macOS)
        return Image(nsImage: generated.nsImage)
        #else
        return Image(uiImage: generated.uiImage)
        #endif
    }
}

/// A deck's cover, taken from Quick Look.
///
/// The system has already rendered these files — it draws the same picture in
/// Finder, in Spotlight and in the share sheet — and it keeps the result in its
/// own cache. Asking for that costs a thumbnail request; drawing our own cost a
/// full package parse per card, which on a library of ninety-megabyte decks
/// measured three minutes and two gigabytes before it drew anything.
///
/// Falls back to a quiet placard when Quick Look has nothing.
struct DeckThumbnail: View {
    let url: URL
    /// The name to set on the placard when there is no thumbnail.
    let fallbackTitle: String
    /// The deck's modification date, so a deck rewritten in place is not shown
    /// with its old cover.
    var version: Date = .distantPast
    /// The width this will be drawn at, in points. Quick Look is asked for
    /// exactly this rather than one size that suits nobody.
    var width: CGFloat = 320

    @Environment(\.displayScale) private var displayScale
    @State private var loaded: Image?

    private var key: String {
        DeckThumbnailStore.key(url: url, version: version, width: width)
    }

    /// The cache is read synchronously in `body`: a warm grid draws on the
    /// first frame rather than after a hop through the concurrency runtime, so
    /// returning to the library does no work at all.
    private var image: Image? {
        loaded ?? DeckThumbnailStore.shared.cached(key)
    }

    var body: some View {
        ZStack {
            if let image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                DeckPlacard(title: fallbackTitle, muted: true)
            }
        }
        // The generated image is whatever shape the slide is; the card decides
        // the shape. Without this, a wider thumbnail renders past its own
        // corners and over the card beside it.
        .clipped()
        .task(id: key) {
            // Already had it: no request, no decode, and nothing to animate.
            guard DeckThumbnailStore.shared.cached(key) == nil else { return }
            let image = await DeckThumbnailStore.shared.thumbnail(
                url: url, key: key, width: width, scale: displayScale)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) { loaded = image }
        }
    }
}

/// The stand-in when Quick Look has no picture: a quiet surface rather than an
/// empty grey rectangle.
struct DeckPlacard: View {
    let title: String
    /// True while the thumbnail is still being fetched, so the placard reads as
    /// "loading" rather than as the final answer.
    var muted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(white: 0.97), Color(white: 0.90)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if !muted {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .padding(16)
            }
        }
    }
}
