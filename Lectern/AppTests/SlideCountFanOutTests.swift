import Foundation
import Testing
import LecternCore
@testable import Lectern

/// `loadSlideCounts` used to await one `DeckCardIndex` read at a time on the
/// main actor, re-rendering the whole library once per deck. It now fans the
/// reads out and merges the results in a single pass. This is a performance
/// item, so these assert the *structural* change — that the reads overlap and
/// land in one merged write — rather than a flaky wall-clock threshold.
///
/// The real `loadSlideCounts()` passes the `DeckCardIndex.shared` read; the
/// injectable `loadSlideCounts(for:reading:)` seam lets a test supply its own
/// counts and watch how many reads are in flight at once, without touching the
/// index's deliberate concurrency gate or opening any real deck.
@Suite struct SlideCountFanOutTests {
    /// Records how many injected reads are running at the same moment, and the
    /// exact decks that were asked for. An actor because the reads run
    /// concurrently and off the main actor.
    private actor ReadProbe {
        private(set) var active = 0
        private(set) var maxActive = 0
        private(set) var requested: [URL] = []

        func begin(_ url: URL) {
            requested.append(url)
            active += 1
            maxActive = max(maxActive, active)
        }

        func end() {
            active -= 1
        }
    }

    private func makeDeck(_ name: String) -> DeckFile {
        DeckFile(url: URL(fileURLWithPath: "/library/\(name).pptx"),
                 name: name,
                 modified: Date(),
                 byteCount: 0)
    }

    @MainActor
    @Test func oneCallCountsEveryPendingDeckAndTheReadsOverlap() async {
        let app = AppState(skipKeychain: true)
        let decks = [makeDeck("a"), makeDeck("b"), makeDeck("c"), makeDeck("d")]
        // "d" has no reading — it must simply get no count, not crash or block.
        let known: [URL: Int] = [decks[0].url: 3, decks[1].url: 7, decks[2].url: 12]
        let probe = ReadProbe()

        await app.loadSlideCounts(for: decks) { deck in
            await probe.begin(deck.url)
            // A short suspension so a serial loop and a fan-out are
            // distinguishable: while one read is parked here, the others must
            // have started for the count to climb above one.
            try? await Task.sleep(for: .milliseconds(40))
            await probe.end()
            return known[deck.url]
        }

        #expect(app.slideCounts[decks[0].url] == 3)
        #expect(app.slideCounts[decks[1].url] == 7)
        #expect(app.slideCounts[decks[2].url] == 12)
        // A nil reading leaves that deck without a count, exactly as before.
        #expect(app.slideCounts[decks[3].url] == nil)

        let maxActive = await probe.maxActive
        // The whole point: the reads did NOT run strictly one after another.
        #expect(maxActive >= 2)

        let requested = await probe.requested
        #expect(Set(requested) == Set(decks.map(\.url)))
    }

    @MainActor
    @Test func decksThatAlreadyHaveACountAreNotReReadRequested() async {
        let app = AppState(skipKeychain: true)
        let one = makeDeck("one")
        let two = makeDeck("two")
        let known: [URL: Int] = [one.url: 5, two.url: 9]
        let probe = ReadProbe()

        // First pass counts only "one".
        await app.loadSlideCounts(for: [one]) { deck in
            await probe.begin(deck.url)
            await probe.end()
            return known[deck.url]
        }
        #expect(app.slideCounts[one.url] == 5)

        // Second pass sees both, but "one" is already known and must be
        // skipped — only "two" should reach the reader.
        await app.loadSlideCounts(for: [one, two]) { deck in
            await probe.begin(deck.url)
            await probe.end()
            return known[deck.url]
        }
        #expect(app.slideCounts[two.url] == 9)

        let requested = await probe.requested
        #expect(requested == [one.url, two.url])
        #expect(requested.filter { $0 == one.url }.count == 1)
    }
}
