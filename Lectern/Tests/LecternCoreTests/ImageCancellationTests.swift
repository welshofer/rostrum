import Foundation
import Testing
@testable import LecternCore

/// REL-2: a cancel that lands while images are in flight is a cancelled run,
/// not N image failures. Before the fix, `illustrate` folded `CancellationError`
/// into per-slide failures and `finish` went straight on to `.rendering`, so
/// the app saved a deck carrying "N of M image(s) couldn't be generated" into
/// the user's library as if it were a finished result.
@Suite struct ImageCancellationTests {

    private func illustratedDeckJSON() throws -> String {
        let deck = DeckIR(meta: Meta(title: "Turbines"), slides: [
            IRSlide(id: "title", layout: "title", title: "Wind power"),
            IRSlide(id: "a", layout: "bullets", title: "Siting",
                    body: Body(bullets: [Bullet(text: "Coastal ridges")]),
                    image: ImageBrief(prompt: "a turbine on a ridge")),
            IRSlide(id: "b", layout: "bullets", title: "Output",
                    body: Body(bullets: [Bullet(text: "Capacity factor")]),
                    image: ImageBrief(prompt: "a turbine at dusk")),
            IRSlide(id: "end", layout: "closing", title: "Next step", body: Body(callToAction: "Act"))
        ])
        return String(decoding: try JSONEncoder().encode(deck), as: UTF8.self)
    }

    private func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("image-cancel-\(UUID().uuidString)", isDirectory: true)
    }

    private func generator(_ imageProvider: any ImageProvider) throws -> DeckGenerator {
        DeckGenerator(provider: FixtureProvider(validJSON: try illustratedDeckJSON()),
                      imageProvider: imageProvider, quality: false)
    }

    private let request = DeckRequest(prompt: "turbines", slideCount: 4, notes: false)

    private func pptxFiles(in dir: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return contents.filter { $0.pathExtension == "pptx" }
    }

    /// The provider itself reports the cancel (as `URLSession` and
    /// `Task.sleep` do when their task is cancelled).
    @Test func providerCancellationEndsTheRunInsteadOfBecomingImageWarnings() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let events = StageRecorder()
        let generator = try generator(StubImageProvider(behaviour: .throwCancellation))

        await #expect(throws: CancellationError.self) {
            _ = try await generator.generate(request, designURL: nil, into: dir) { events.record($0) }
        }
        #expect(events.stages.contains("illustrating"), "the image pass should have started")
        #expect(!events.stages.contains("rendering"), "a cancelled run must not render")
        #expect(!events.stages.contains("finished"))
        #expect(pptxFiles(in: dir).isEmpty, "no deck may be written for a cancelled run")
    }

    /// The surrounding task is cancelled while requests are in flight.
    @Test func cancellingTheRunMidFlightThrowsCancellation() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let events = StageRecorder()
        let generator = try generator(StubImageProvider(behaviour: .waitForCancel))
        let request = request

        let run = Task {
            try await generator.generate(request, designURL: nil, into: dir) { events.record($0) }
        }
        try await events.waitFor("illustrating")
        run.cancel()

        await #expect(throws: CancellationError.self) { _ = try await run.value }
        #expect(!events.stages.contains("rendering"), "a cancelled run must not render")
        #expect(pptxFiles(in: dir).isEmpty, "no deck may be written for a cancelled run")
    }

    /// A provider may turn its task's cancel into its own error (a
    /// `URLError.cancelled`, say). That is recorded as an ordinary image
    /// failure inside `illustrate`, so `finish` must still notice the cancel
    /// before rendering.
    @Test func cancelReportedAsAProviderErrorStillStopsBeforeRendering() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let events = StageRecorder()
        let generator = try generator(StubImageProvider(behaviour: .waitForCancelThenURLError))
        let request = request

        let run = Task {
            try await generator.generate(request, designURL: nil, into: dir) { events.record($0) }
        }
        try await events.waitFor("illustrating")
        run.cancel()

        await #expect(throws: CancellationError.self) { _ = try await run.value }
        #expect(!events.stages.contains("rendering"), "a cancelled run must not render")
        #expect(pptxFiles(in: dir).isEmpty, "no deck may be written for a cancelled run")
    }

    /// Unchanged behaviour: an ordinary image failure is not fatal. The deck
    /// renders and the failure is reported as a warning.
    @Test func ordinaryImageFailureStillYieldsADeckWithAWarning() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let events = StageRecorder()
        let generator = try generator(StubImageProvider(behaviour: .fail))

        let result = try await generator.generate(request, designURL: nil, into: dir) { events.record($0) }

        #expect(events.stages.contains("rendering"))
        #expect(FileManager.default.fileExists(atPath: result.url.path))
        let warning = try #require(result.warnings.first { $0.contains("image(s) couldn't be generated") })
        #expect(warning.contains("2 of 2"))
        #expect(warning.contains("image backend exploded"))
    }
}

private struct StubImageProvider: ImageProvider {
    enum Behaviour: Sendable {
        case throwCancellation
        case waitForCancel
        case waitForCancelThenURLError
        case fail
    }

    let id: ImageProviderID = .openAI
    let behaviour: Behaviour

    func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        switch behaviour {
        case .throwCancellation:
            throw CancellationError()
        case .waitForCancel:
            // Throws `CancellationError` once the run is cancelled.
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return Data("image-bytes".utf8)
        case .waitForCancelThenURLError:
            do {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            } catch {
                throw URLError(.cancelled)
            }
            return Data("image-bytes".utf8)
        case .fail:
            throw LecternError.providerError(status: 500, message: "image backend exploded")
        }
    }
}

/// Thread-safe record of which pipeline stages were reached.
private final class StageRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: Set<String> = []

    func record(_ event: GenerationEvent) {
        let name: String
        switch event {
        case .illustrating: name = "illustrating"
        case .rendering: name = "rendering"
        case .finished: name = "finished"
        default: return
        }
        lock.lock(); defer { lock.unlock() }
        seen.insert(name)
    }

    var stages: Set<String> { lock.lock(); defer { lock.unlock() }; return seen }

    func waitFor(_ stage: String) async throws {
        for _ in 0..<1_000 {
            if stages.contains(stage) { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        Issue.record("timed out waiting for \(stage)")
    }
}
