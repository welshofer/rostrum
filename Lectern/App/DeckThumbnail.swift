import SwiftUI
import QuickLookThumbnailing
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A deck's cover, taken from Quick Look.
///
/// The system has already rendered these files — it draws the same picture in
/// Finder, in Spotlight and in the share sheet — and it keeps the result in its
/// own cache. Asking for that costs a thumbnail request; drawing our own cost
/// a full package parse per card, which on a library of ninety-megabyte decks
/// measured three minutes and two gigabytes before it drew anything.
///
/// Falls back to a tinted placard when Quick Look has nothing, which happens
/// for a deck that has never been previewed on a machine with no PowerPoint
/// and no QuickLook generator for PresentationML.
struct DeckThumbnail: View {
    let url: URL
    /// The name to set on the placard when there is no thumbnail.
    let fallbackTitle: String

    @Environment(\.displayScale) private var displayScale
    @State private var image: Image?
    @State private var resolved = false

    var body: some View {
        ZStack {
            if let image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                DeckPlacard(title: fallbackTitle, muted: !resolved)
            }
        }
        // The generated image is whatever shape the slide is; the card decides
        // the shape. Without this, a wider thumbnail renders past its own
        // corners and over the card beside it.
        .clipped()
        .task(id: url.path) { await load() }
    }

    private func load() async {
        image = nil
        resolved = false
        let scale = displayScale
        let thumbnail = await Self.thumbnail(for: url, scale: scale)
        // A thumbnail that arrives after the card scrolled away would flash the
        // wrong deck; `task(id:)` cancels first, so only check the result.
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            image = thumbnail
            resolved = true
        }
    }

    /// One request, `.thumbnail` representation: the cheapest one Quick Look
    /// offers, and the one it is most likely to already have.
    static func thumbnail(for url: URL, scale: CGFloat) async -> Image? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 640, height: 400),
            scale: scale,
            representationTypes: .thumbnail)
        let generated = try? await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: request)
        guard let generated else { return nil }
        #if os(macOS)
        return Image(nsImage: generated.nsImage)
        #else
        return Image(uiImage: generated.uiImage)
        #endif
    }
}

/// The stand-in when Quick Look has no picture: the deck's name, set on a
/// surface, rather than an empty grey rectangle.
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
        .overlay {
            if muted {
                ProgressView().controlSize(.small)
            }
        }
    }
}
