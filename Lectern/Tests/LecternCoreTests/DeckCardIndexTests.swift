import Foundation
import Testing
import Rostrum
@testable import LecternCore

/// `DeckCardIndex.card(for:)` must start one parse per deck however many
/// visible cards ask at once, and must answer a card cached on disk without
/// queueing behind the two-slot parse gate.
@Suite struct DeckCardIndexTests {
    /// Counts parses per deck and can hold chosen decks' parses open, so the
    /// gate can be filled deterministically.
    private actor BuildLog {
        private(set) var builds: [URL: Int] = [:]
        private var held: Set<URL> = []
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func hold(_ url: URL) { held.insert(url) }

        func build(_ url: URL) async -> DeckCard? {
            builds[url, default: 0] += 1
            if held.contains(url) { await withCheckedContinuation { waiters.append($0) } }
            return DeckCardIndex.build(from: url)
        }

        func releaseHeld() {
            held.removeAll()
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }

        func count(_ url: URL) -> Int { builds[url, default: 0] }
        var total: Int { builds.values.reduce(0, +) }
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeckCardIndexTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func deck(named name: String, slides: Int, in root: URL) throws -> DeckFile {
        let presentation = try Presentation()
        while presentation.slides.count < slides { _ = try presentation.slides.add() }
        #expect(presentation.slides.count == slides)
        let url = root.appendingPathComponent("\(name).pptx")
        try presentation.save(to: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return DeckFile(url: url, name: name,
                        modified: attributes[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0),
                        byteCount: (attributes[.size] as? NSNumber)?.intValue ?? 0)
    }

    /// Polls an actor-backed condition; the work it waits on is in flight
    /// on other tasks, so this only waits until they get there. No wall-clock
    /// deadline: under a full parallel test run the cooperative pool can stay
    /// busy for minutes, so the test's time limit is the hang guard instead.
    private func eventually(_ condition: () async -> Bool) async throws {
        while await !condition() {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    @Test(.timeLimit(.minutes(20)))
    func concurrentRequestsForOneDeckParseItOnce() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let target = try deck(named: "target", slides: 3, in: root)
        let blockerA = try deck(named: "blocker-a", slides: 1, in: root)
        let blockerB = try deck(named: "blocker-b", slides: 1, in: root)
        let cache = root.appendingPathComponent("cards", isDirectory: true)

        let log = BuildLog()
        await log.hold(blockerA.url)
        await log.hold(blockerB.url)
        let index = DeckCardIndex(directory: cache, builder: { await log.build($0) })

        // Fill both parse slots so the target's request has to wait for one —
        // the contention under which a late-registered task let duplicates in.
        let blockers = Task {
            async let a = index.card(for: blockerA)
            async let b = index.card(for: blockerB)
            return await (a, b)
        }
        try await eventually {
            let gated = await index.gateAcquisitions
            let started = await log.total
            return gated == 2 && started == 2
        }

        let cards = await withTaskGroup(of: DeckCard?.self, returning: [DeckCard?].self) { group in
            for _ in 0..<12 { group.addTask { await index.card(for: target) } }
            // Every waiter for the target shares one task, so exactly one read
            // is queued at the gate however many of the twelve have arrived.
            try? await eventually { await index.queuedParses >= 1 }
            #expect(await index.queuedParses == 1)
            await log.releaseHeld()
            var results: [DeckCard?] = []
            for await card in group { results.append(card) }
            return results
        }
        let (a, b) = await blockers.value

        #expect(cards.count == 12)
        #expect(cards.allSatisfy { $0 == DeckCard(slideCount: 3) })
        #expect(a == DeckCard(slideCount: 1) && b == DeckCard(slideCount: 1))
        #expect(await log.count(target.url) == 1)
        #expect(await index.gateAcquisitions == 3)
    }

    @Test func cardOnDiskSkipsTheParseGate() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let target = try deck(named: "target", slides: 2, in: root)
        let cache = root.appendingPathComponent("cards", isDirectory: true)
        let log = BuildLog()

        let first = DeckCardIndex(directory: cache, builder: { await log.build($0) })
        #expect(await first.card(for: target) == DeckCard(slideCount: 2))
        #expect(await log.count(target.url) == 1)
        #expect(await first.gateAcquisitions == 1)

        // A relaunch: memory is cold, the card is on disk. It must come back
        // without a parse and without ever entering the gate.
        let relaunched = DeckCardIndex(directory: cache, builder: { await log.build($0) })
        #expect(await relaunched.card(for: target) == DeckCard(slideCount: 2))
        #expect(await log.count(target.url) == 1)
        #expect(await relaunched.gateAcquisitions == 0)
        // Now remembered in memory too.
        #expect(await relaunched.card(for: target) == DeckCard(slideCount: 2))
        #expect(await relaunched.gateAcquisitions == 0)

        // `removeAll()` still forgets both halves: the next read parses again.
        await relaunched.removeAll()
        #expect(await relaunched.card(for: target) == DeckCard(slideCount: 2))
        #expect(await log.count(target.url) == 2)
        #expect(await relaunched.gateAcquisitions == 1)
    }
}
