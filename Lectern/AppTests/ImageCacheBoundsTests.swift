import SwiftUI
import Testing
@testable import Lectern

/// The two image caches — `DeckThumbnailStore` and `SlideRasterizer` — used to
/// be dictionaries with no eviction, so both grew for the life of the process.
/// These tests pin the structural fix: each cache has a hard entry cap it never
/// exceeds, the least-recently-used entry is the one dropped, and the warm-path
/// read a view makes in `body` is still synchronous.
@Suite struct ImageCacheBoundsTests {

    // MARK: - The bounded LRU cache itself

    /// Inserting past the cap never grows the cache beyond it, and the entries
    /// left standing are the most recently inserted.
    @Test func boundedCacheNeverExceedsItsCapacity() {
        var cache = BoundedCache<String, Int>(capacity: 3)
        for index in 0..<10 {
            cache.insert(index, forKey: "k\(index)")
            #expect(cache.count <= 3)
        }
        #expect(cache.count == 3)
        // The three most recently inserted survive; everything older is gone.
        #expect(cache.value(forKey: "k9") == 9)
        #expect(cache.value(forKey: "k8") == 8)
        #expect(cache.value(forKey: "k7") == 7)
        #expect(cache.value(forKey: "k0") == nil)
        #expect(cache.value(forKey: "k6") == nil)
    }

    /// A read counts as a use: the entry that was touched most recently survives
    /// the next insert, and the genuinely least-recently-used one is evicted.
    @Test func boundedCacheEvictsLeastRecentlyUsed() {
        var cache = BoundedCache<String, Int>(capacity: 3)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        cache.insert(3, forKey: "c")

        // Touch "a" so "b" is now the least-recently-used entry.
        #expect(cache.value(forKey: "a") == 1)

        // Inserting a fourth entry must evict "b", not the freshly-used "a".
        cache.insert(4, forKey: "d")

        #expect(cache.count == 3)
        #expect(cache.value(forKey: "b") == nil)   // evicted: least-recently-used
        #expect(cache.value(forKey: "a") == 1)     // survived: recently used
        #expect(cache.value(forKey: "c") == 3)     // survived
        #expect(cache.value(forKey: "d") == 4)     // survived: just inserted
    }

    /// Re-inserting a live key replaces it in place — the count does not grow,
    /// and the key is refreshed as most-recently-used rather than duplicated.
    @Test func boundedCacheReplacesExistingKeyInPlace() {
        var cache = BoundedCache<String, Int>(capacity: 2)
        cache.insert(1, forKey: "a")
        cache.insert(2, forKey: "b")
        cache.insert(99, forKey: "a")   // replace + promote "a"
        #expect(cache.count == 2)
        #expect(cache.value(forKey: "a") == 99)

        // "a" is now most-recently-used, so the next insert evicts "b".
        cache.insert(3, forKey: "c")
        #expect(cache.count == 2)
        #expect(cache.value(forKey: "b") == nil)
        #expect(cache.value(forKey: "a") == 99)
        #expect(cache.value(forKey: "c") == 3)
    }

    // MARK: - DeckThumbnailStore

    @MainActor
    @Test func thumbnailStoreStaysWithinItsCap() {
        let store = DeckThumbnailStore(capacity: 3)
        for index in 0..<8 {
            store.remember(Image(systemName: "\(index).circle"), forKey: "deck-\(index)")
            #expect(store.cacheCount <= 3)
        }
        #expect(store.cacheCount == 3)
        #expect(store.cached("deck-0") == nil)   // long since evicted
        #expect(store.cached("deck-7") != nil)   // most recent survives
    }

    @MainActor
    @Test func thumbnailStoreEvictsLeastRecentlyUsed() {
        let store = DeckThumbnailStore(capacity: 3)
        store.remember(Image(systemName: "a.circle"), forKey: "a")
        store.remember(Image(systemName: "b.circle"), forKey: "b")
        store.remember(Image(systemName: "c.circle"), forKey: "c")

        // Draw "a" again — the grid reading a visible card keeps it hot.
        #expect(store.cached("a") != nil)

        store.remember(Image(systemName: "d.circle"), forKey: "d")

        #expect(store.cacheCount == 3)
        #expect(store.cached("b") == nil)   // least-recently-used, evicted
        #expect(store.cached("a") != nil)   // recently drawn, survived
        #expect(store.cached("c") != nil)
        #expect(store.cached("d") != nil)
    }

    /// The behaviour that removed the scroll stutter: `cached(_:)` is a plain,
    /// synchronous read. This test is deliberately *not* `async` — it calls
    /// `cached(_:)` with no `await`, so it would fail to compile if that read
    /// ever became asynchronous.
    @MainActor
    @Test func thumbnailStoreCachedReturnsSynchronously() {
        let store = DeckThumbnailStore(capacity: 4)
        let key = DeckThumbnailStore.key(
            url: URL(fileURLWithPath: "/decks/hello.pptx"),
            version: Date(timeIntervalSince1970: 0),
            width: 320)
        store.remember(Image(systemName: "photo"), forKey: key)
        #expect(store.cached(key) != nil)
    }

    // MARK: - SlideRasterizer (macOS only — the rasteriser does not exist on iOS)

    #if os(macOS)
    @MainActor
    @Test func rasterizerStaysWithinItsCap() {
        let rasterizer = SlideRasterizer(capacity: 3)
        for index in 0..<8 {
            rasterizer.remember(Image(systemName: "\(index).square"), forKey: "slide-\(index)")
            #expect(rasterizer.cacheCount <= 3)
        }
        #expect(rasterizer.cacheCount == 3)
        #expect(rasterizer.cached("slide-0") == nil)
        #expect(rasterizer.cached("slide-7") != nil)
    }

    @MainActor
    @Test func rasterizerEvictsLeastRecentlyUsed() {
        let rasterizer = SlideRasterizer(capacity: 3)
        rasterizer.remember(Image(systemName: "a.square"), forKey: "a")
        rasterizer.remember(Image(systemName: "b.square"), forKey: "b")
        rasterizer.remember(Image(systemName: "c.square"), forKey: "c")

        #expect(rasterizer.cached("a") != nil)   // touch "a"

        rasterizer.remember(Image(systemName: "d.square"), forKey: "d")

        #expect(rasterizer.cacheCount == 3)
        #expect(rasterizer.cached("b") == nil)   // least-recently-used, evicted
        #expect(rasterizer.cached("a") != nil)   // recently used, survived
        #expect(rasterizer.cached("c") != nil)
        #expect(rasterizer.cached("d") != nil)
    }
    #endif
}
