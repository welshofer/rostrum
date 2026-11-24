import Foundation
import Testing
@testable import LecternCore

/// Concurrency deduplication, parse-gate capping, and waiter cancellation for `DeckCardIndex`.
@Suite struct DeckCardIndexTests {
    private func tempDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("deckcardindex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func deck(_ name: String, in dir: URL) -> DeckFile {
        DeckFile(
            url: dir.appendingPathComponent("\(name).pptx"),
            name: name,
            modified: Date(timeIntervalSince1970: 1_700_000_000),
            byteCount: 1024
        )
    }

    /// Pure-async build coordinator using CheckedContinuations so tests never
    /// block cooperative threads even on 2-core CI runners.
    private actor BuildProbe {
        private var counts: [String: Int] = [:]
        private var active = 0
        private var maxActive = 0
        private let gatedNames: Set<String>
        private let expectedStarts: Int
        private var startedNames: Set<String> = []
        private var startWaiters: [CheckedContinuation<Void, Never>] = []
        private var released = false
        private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

        init(gatedNames: Set<String> = [], expectedStarts: Int = 0) {
            self.gatedNames = gatedNames
            self.expectedStarts = expectedStarts
        }

        func build(_ url: URL) async -> DeckCard? {
            let name = url.deletingPathExtension().lastPathComponent
            counts[name, default: 0] += 1
            active += 1
            if active > maxActive { maxActive = active }
            if gatedNames.contains(name) {
                startedNames.insert(name)
                if startedNames.count >= expectedStarts {
                    let waiters = startWaiters
                    startWaiters.removeAll()
                    waiters.forEach { $0.resume() }
                }
                if !released {
                    await withCheckedContinuation { continuation in
                        if released {
                            continuation.resume()
                        } else {
                            releaseWaiters.append(continuation)
                        }
                    }
                }
            }
            active -= 1
            return DeckCard(slideCount: name.count)
        }

        func waitForGatedStarts() async {
            if startedNames.count >= expectedStarts { return }
            await withCheckedContinuation { continuation in
                if startedNames.count >= expectedStarts {
                    continuation.resume()
                } else {
                    startWaiters.append(continuation)
                }
            }
        }

        func releaseAll() {
            released = true
            let waiters = releaseWaiters
            releaseWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        func count(for name: String) -> Int {
            counts[name, default: 0]
        }

        var peakConcurrency: Int {
            maxActive
        }
    }

    @Test func concurrentCallersCoalesceEvenWhenParseSlotsAreBusy() async throws {
        let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let probe = BuildProbe(gatedNames: ["A", "B"], expectedStarts: 2)
        let index = DeckCardIndex(directory: dir, build: { await probe.build($0) })

        let deckA = deck("A", in: dir)
        let deckB = deck("B", in: dir)
        let deckC = deck("C", in: dir)

        let taskA = Task { await index.card(for: deckA) }
        let taskB = Task { await index.card(for: deckB) }
        await probe.waitForGatedStarts()

        // Both parse slots are occupied by A and B. Queue two concurrent
        // callers for C; they must share one in-flight parse rather than both
        // queuing independent builds behind acquire().
        let taskC1 = Task { await index.card(for: deckC) }
        let taskC2 = Task { await index.card(for: deckC) }
        try await Task.sleep(nanoseconds: 50_000_000)

        await probe.releaseAll()
        let (_, _, cardC1, cardC2) = await (taskA.value, taskB.value, taskC1.value, taskC2.value)

        #expect(cardC1 == DeckCard(slideCount: 1))
        #expect(cardC2 == DeckCard(slideCount: 1))
        #expect(await probe.count(for: "C") == 1)
        #expect(await probe.peakConcurrency <= 2)
    }

    @Test func cancelledWaiterReturnsPromptlyWithoutParsingWhenSlotOpens() async throws {
        let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let probe = BuildProbe(gatedNames: ["A", "B"], expectedStarts: 2)
        let index = DeckCardIndex(directory: dir, build: { await probe.build($0) })

        let deckA = deck("A", in: dir)
        let deckB = deck("B", in: dir)
        let deckD = deck("D", in: dir)

        let taskA = Task { await index.card(for: deckA) }
        let taskB = Task { await index.card(for: deckB) }
        await probe.waitForGatedStarts()

        let taskD = Task { await index.card(for: deckD) }
        try await Task.sleep(nanoseconds: 50_000_000)
        taskD.cancel()

        // Must complete *before* A and B release their parse slots.
        let cardD = await taskD.value
        #expect(cardD == nil)

        await probe.releaseAll()
        _ = await (taskA.value, taskB.value)
        #expect(await probe.count(for: "D") == 0)
    }

    @Test func cancellingOneSharedCallerPreservesRemainingCaller() async throws {
        let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let probe = BuildProbe(gatedNames: ["A", "B"], expectedStarts: 2)
        let index = DeckCardIndex(directory: dir, build: { await probe.build($0) })

        let deckA = deck("A", in: dir)
        let deckB = deck("B", in: dir)
        let deckE = deck("E", in: dir)

        let taskA = Task { await index.card(for: deckA) }
        let taskB = Task { await index.card(for: deckB) }
        await probe.waitForGatedStarts()

        let taskE1 = Task { await index.card(for: deckE) }
        let taskE2 = Task { await index.card(for: deckE) }
        try await Task.sleep(nanoseconds: 50_000_000)
        taskE1.cancel()
        try await Task.sleep(nanoseconds: 50_000_000)

        await probe.releaseAll()
        let (_, _, _, cardE2) = await (taskA.value, taskB.value, taskE1.value, taskE2.value)

        #expect(cardE2 == DeckCard(slideCount: 1))
        #expect(await probe.count(for: "E") == 1)
    }

    @Test func removeAllDrainsQueuedWaitersAndPreventsStaleDiskWrites() async throws {
        let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let probe = BuildProbe(gatedNames: ["A", "B"], expectedStarts: 2)
        let index = DeckCardIndex(directory: dir, build: { await probe.build($0) })

        let deckA = deck("A", in: dir)
        let deckB = deck("B", in: dir)
        let deckF = deck("F", in: dir)

        let taskA = Task { await index.card(for: deckA) }
        let taskB = Task { await index.card(for: deckB) }
        await probe.waitForGatedStarts()

        let taskF = Task { await index.card(for: deckF) }
        try await Task.sleep(nanoseconds: 50_000_000)

        await index.removeAll()
        // Queued waiter F should unblock immediately with nil and never build.
        let cardF = await taskF.value
        #expect(cardF == nil)

        await probe.releaseAll()
        _ = await (taskA.value, taskB.value)
        #expect(await probe.count(for: "F") == 0)
        // Stale builds A and B must not recreate the cleared cache directory.
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }
}
