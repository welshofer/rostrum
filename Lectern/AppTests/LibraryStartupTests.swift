import Foundation
import Testing
import LecternCore
@testable import Lectern

@MainActor
@Suite struct LibraryStartupTests {
    @Test func refreshRemainsResponsiveAndOnlyNewestScanPublishes() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let scans = ControlledScans()
        let expectedDirectory = context.libraryDirectory
        let app = AppState(skipKeychain: true, defaults: context.defaults,
            libraryDirectory: context.libraryDirectory, readingLibrary: { directory in
                #expect(!isMainThreadAtCall())
                #expect(directory == expectedDirectory)
                return await scans.read()
            })
        let old = app.refreshLibrary()
        await scans.wait(for: 1)
        app.startCreate()
        #expect(app.phase == .compose && app.isRefreshingLibrary)
        let live = app.refreshLibrary()
        await scans.wait(for: 2)
        await scans.finish(1, with: [deck("old", in: context)])
        await old.value
        #expect(app.library.isEmpty && app.isRefreshingLibrary)
        await scans.finish(2, with: [deck("live", in: context)])
        await live.value
        #expect(app.library.map(\.name) == ["live"])
        #expect(!app.isRefreshingLibrary)
    }

    @Test func cancelledViewRefreshDoesNotPublishLateListing() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let scans = ControlledScans()
        let app = AppState(skipKeychain: true, defaults: context.defaults,
            libraryDirectory: context.libraryDirectory, readingLibrary: { _ in await scans.read() })
        let caller = Task { await app.refreshLibraryAndWait() }
        await scans.wait(for: 1)
        caller.cancel()
        await scans.finish(1, with: [deck("cancelled", in: context)])
        await caller.value
        #expect(app.library.isEmpty && !app.isRefreshingLibrary)
        let live = app.refreshLibrary()
        await scans.wait(for: 2)
        await scans.finish(2, with: [deck("live", in: context)])
        await live.value
        #expect(app.library.map(\.name) == ["live"])
    }

    @Test func staleSlideCountsCannotReturnAfterLibraryReplacement() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let scans = ControlledScans(), count = StartupSignal()
        let app = AppState(skipKeychain: true, defaults: context.defaults,
            libraryDirectory: context.libraryDirectory, readingLibrary: { _ in await scans.read() })
        let first = app.refreshLibrary()
        await scans.wait(for: 1)
        let oldDeck = deck("old", in: context)
        await scans.finish(1, with: [oldDeck])
        await first.value
        let counts = Task { await app.loadSlideCounts(for: app.library) { _ in await count.run(); return 9 } }
        await count.waitUntilStarted()
        let replacement = app.refreshLibrary()
        await scans.wait(for: 2)
        await scans.finish(2, with: [])
        await replacement.value
        await count.finish()
        await counts.value
        #expect(app.library.isEmpty && app.slideCounts.isEmpty)
    }

    @Test func overlappingStartupPreparesOnceAndCancelledCallerCannotPublish() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let preparation = StartupSignal()
        let app = AppState(skipKeychain: true, defaults: context.defaults,
            libraryDirectory: context.libraryDirectory,
            legacyDirectory: context.libraryDirectory.appendingPathComponent("Legacy"),
            diagnosticsDirectory: context.libraryDirectory.appendingPathComponent("Diagnostics"),
            preparingLibrary: { _ in
                #expect(!isMainThreadAtCall())
                await preparation.run()
                return 2
            })
        let cancelled = Task { await app.start() }
        await preparation.waitUntilStarted()
        cancelled.cancel()
        // Main-actor navigation proceeds while the startup worker is held.
        app.startCreate()
        #expect(app.phase == .compose && app.migrationNotice == nil)
        await preparation.finish()
        await cancelled.value
        #expect(app.migrationNotice == nil && app.library.isEmpty)
        await app.start()
        #expect(await preparation.runCount == 1)
        #expect(app.migrationNotice == "Moved 2 decks to Documents › Lectern.")
        app.dismissMigrationNotice()
        await app.start()
        #expect(app.migrationNotice == nil)
        #expect(await preparation.runCount == 1)
    }

    @Test func sameCountRefreshInvalidatesOnlyChangedFileCounts() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let scans = ControlledScans()
        let app = AppState(skipKeychain: true, defaults: context.defaults,
            libraryDirectory: context.libraryDirectory, readingLibrary: { _ in await scans.read() })
        let first = app.refreshLibrary()
        await scans.wait(for: 1)
        let stable = deck("stable", in: context)
        var changed = deck("changed", in: context)
        await scans.finish(1, with: [stable, changed])
        await first.value
        await app.loadSlideCounts(for: app.library) { _ in 3 }
        let revision = app.libraryRevision
        changed.modified = Date(timeIntervalSince1970: 1)
        let next = app.refreshLibrary()
        await scans.wait(for: 2)
        await scans.finish(2, with: [stable, changed])
        await next.value
        #expect(app.libraryRevision != revision && app.library.count == 2)
        #expect(app.slideCounts[stable.url] == 3 && app.slideCounts[changed.url] == nil)
        await app.loadSlideCounts(for: app.library) { _ in 7 }
        #expect(app.slideCounts[stable.url] == 3 && app.slideCounts[changed.url] == 7)
    }

    @Test func testHostUsesActualStartupAgainstOnlyOwnedPaths() async throws {
        let context = try AppStateTestContext()
        defer { context.remove() }
        let root = context.libraryDirectory
        let legacy = root.appendingPathComponent("Legacy"), library = root.appendingPathComponent("Library")
        let diagnostics = root.appendingPathComponent("Diagnostics")
        for directory in [legacy, library, diagnostics] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let movedBytes = Data("owned migrated deck".utf8)
        try movedBytes.write(to: legacy.appendingPathComponent("moved.pptx"))
        try Data("old collision".utf8).write(to: legacy.appendingPathComponent("collision.pptx"))
        try Data("existing collision".utf8).write(to: library.appendingPathComponent("collision.pptx"))
        try Data("lock".utf8).write(to: legacy.appendingPathComponent("~$lock.pptx"))
        let old = diagnostics.appendingPathComponent("rejected-draft-old.json")
        let recent = diagnostics.appendingPathComponent("rejected-draft-recent.json")
        let unrelated = diagnostics.appendingPathComponent("unrelated.json")
        for url in [old, recent, unrelated] { try Data("owned fixture".utf8).write(to: url) }
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -30 * 86400)], ofItemAtPath: old.path)
        let app = AppState.forLaunch(environment: ["LECTERN_TEST_HOST": "1"], testRoot: root, testDefaults: context.defaults)
        await app.start()
        #expect(Set(app.library.map(\.name)) == ["collision", "moved"])
        #expect(app.migrationNotice == "Moved 1 deck to Documents › Lectern.")
        #expect(try Data(contentsOf: library.appendingPathComponent("moved.pptx")) == movedBytes)
        #expect(try Data(contentsOf: library.appendingPathComponent("collision.pptx")) == Data("existing collision".utf8))
        #expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("collision.pptx").path))
        #expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent("~$lock.pptx").path))
        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: recent.path) && FileManager.default.fileExists(atPath: unrelated.path))
        #expect(app.providerID == .openAI && app.imageProviderID == .openAI)
        #expect(!app.hasKey && !app.hasImageKey)
        app.dismissMigrationNotice()
        await app.start()
        #expect(app.migrationNotice == nil)
    }

    private func deck(_ name: String, in context: AppStateTestContext) -> DeckFile {
        DeckFile(url: context.libraryDirectory.appendingPathComponent(name + ".pptx"),
            name: name, modified: .distantPast, byteCount: 0)
    }
}

// A synchronous probe of the code's current executor, with no thread-bound
// state retained across suspension points.
private func isMainThreadAtCall() -> Bool { Thread.isMainThread }

private actor ControlledScans {
    private var scans: [Int: CheckedContinuation<[DeckFile], Never>] = [:]
    private var waiting: [(Int, CheckedContinuation<Void, Never>)] = []
    private var count = 0
    func read() async -> [DeckFile] {
        count += 1
        let id = count
        return await withCheckedContinuation { continuation in
            scans[id] = continuation
            for (target, waiter) in waiting where target <= count { waiter.resume() }
            waiting.removeAll { $0.0 <= count }
        }
    }
    func wait(for target: Int) async {
        if count >= target { return }
        await withCheckedContinuation { waiting.append((target, $0)) }
    }
    func finish(_ id: Int, with decks: [DeckFile]) { scans.removeValue(forKey: id)?.resume(returning: decks) }
}

actor StartupSignal {
    private(set) var runCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func run() async {
        runCount += 1
        await withCheckedContinuation { continuation = $0; for waiter in waiting { waiter.resume() }; waiting = [] }
    }
    func waitUntilStarted() async {
        if runCount > 0 { return }
        await withCheckedContinuation { waiting.append($0) }
    }
    func finish() { continuation?.resume(); continuation = nil }
}
