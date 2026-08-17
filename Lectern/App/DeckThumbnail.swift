import SwiftUI
import QuickLookThumbnailing
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A least-recently-used cache with a hard entry-count ceiling.
///
/// Both of the app's image caches were plain dictionaries with no eviction, so
/// every thumbnail and every rasterised slide lived until the process exited.
/// That is invisible on today's ~29-deck library and a slow leak with no
/// ceiling on a large one, or on a session left open for days. This bounds
/// them: once `capacity` is reached, inserting a new key evicts the
/// least-recently-used entry.
///
/// The audit's suggestion — `NSCache` with a `totalCostLimit` — is a poor fit
/// here: the value is a SwiftUI `Image`, a *struct*, which `NSCache` (an
/// Objective-C class-object cache) cannot hold without boxing, and its eviction
/// is opaque and so untestable. A plain dictionary plus a recency-ordered key
/// array is a value type, evicts on a rule we can assert, and — with caps in
/// the low hundreds — is far simpler than a hand-rolled linked list while being
/// more than fast enough. Reads count as uses, so an image the grid is actively
/// drawing keeps its place and is never the entry dropped.
struct BoundedCache<Key: Hashable, Value> {
    /// The hard upper bound on live entries. Never exceeded after `insert`.
    let capacity: Int
    private var entries: [Key: Value] = [:]
    /// Keys in use order, least-recently-used first, most-recently-used last.
    private var recency: [Key] = []

    init(capacity: Int) {
        precondition(capacity > 0, "BoundedCache needs a positive capacity")
        self.capacity = capacity
    }

    /// Live entry count; never greater than `capacity`.
    var count: Int { entries.count }

    /// Returns the value for `key`, marking it most-recently-used on a hit.
    /// Synchronous by construction — the fast path a view can call from `body`.
    mutating func value(forKey key: Key) -> Value? {
        guard let value = entries[key] else { return nil }
        promote(key)
        return value
    }

    /// Inserts (or replaces) `value` for `key` and, if that pushes the cache
    /// past `capacity`, evicts the single least-recently-used entry.
    mutating func insert(_ value: Value, forKey key: Key) {
        entries[key] = value
        promote(key)
        while entries.count > capacity, let oldest = recency.first {
            recency.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    private mutating func promote(_ key: Key) {
        if let index = recency.firstIndex(of: key) { recency.remove(at: index) }
        recency.append(key)
    }
}

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

    /// Hard ceiling on cached thumbnails. The library is ~29 decks and the grid
    /// asks for at most a couple of widths, so ~58 entries is the common live
    /// set. 128 leaves better than 2× headroom for a larger library and for the
    /// stale entries an in-place rewrite strands — the file's modification date
    /// is part of the key, so a rewritten deck's old picture can never be hit
    /// again and is dead weight that eviction must reclaim — while still capping
    /// worst-case memory (a couple of hundred small thumbnails).
    static let defaultCapacity = 128

    private var images: BoundedCache<String, Image>
    private var inFlight: [String: Task<Image?, Never>] = [:]

    /// Custom-capacity initialiser: production uses the default; tests pass a
    /// small cap to assert the cache stays bounded without the shared singleton.
    init(capacity: Int = DeckThumbnailStore.defaultCapacity) {
        images = BoundedCache(capacity: capacity)
    }

    /// A hit means the grid can draw immediately, with no async work at all —
    /// which is the whole point. Reading also marks the entry most-recently-used,
    /// so a thumbnail the grid is actively drawing is never the one evicted.
    func cached(_ key: String) -> Image? { images.value(forKey: key) }

    /// Live entry count. Exposed so tests can assert the cache never grows past
    /// its cap.
    var cacheCount: Int { images.count }

    static func key(url: URL, version: Date, width: CGFloat) -> String {
        "\(url.path)|\(version.timeIntervalSince1970)|\(Int(width))"
    }

    func thumbnail(url: URL, key: String, width: CGFloat, scale: CGFloat) async -> Image? {
        if let hit = cached(key) { return hit }
        if let running = inFlight[key] { return await running.value }

        let task = Task<Image?, Never> {
            await Self.generate(url: url, width: width, scale: scale)
        }
        inFlight[key] = task
        // The in-flight map is its own small cache and must not leak either.
        // It only ever holds one entry per distinct thumbnail being fetched
        // right now — a second caller for the same key coalesces onto the task
        // above rather than adding a row — and this `defer` removes that entry
        // the moment the task finishes, so the map drains instead of growing.
        // (The task never throws and awaiting its value is not cancellable, so
        // this runs on every path out of the function.)
        defer { inFlight[key] = nil }
        let image = await task.value
        if let image { remember(image, forKey: key) }
        return image
    }

    /// Records a finished thumbnail, evicting the least-recently-used entry once
    /// the cache is full. Internal so a test can seed the cache without standing
    /// up a live Quick Look request.
    func remember(_ image: Image, forKey key: String) {
        images.insert(image, forKey: key)
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
