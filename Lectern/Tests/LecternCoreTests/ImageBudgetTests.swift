import Foundation
import Testing
@testable import LecternCore

/// SEC-3: every image brief is a paid, user-billed call, and how many briefs a
/// deck carries is the model's choice — one a source document can steer. The
/// image pass is capped at `PriceTable.imageCallBudget(slideCount:)` calls and
/// each subject at `ImageStyleDirective.maximumSubjectScalars`.
@Suite struct ImageBudgetTests {

    private func deckJSON(briefs: Int, prompt: (Int) -> String = { "a turbine, view \($0)" }) throws -> String {
        let slides = (0..<briefs).map { i in
            IRSlide(id: "s\(i)", layout: "bullets", title: "Point \(i)",
                    body: Body(bullets: [Bullet(text: "Fact \(i)")]),
                    image: ImageBrief(prompt: prompt(i)))
        }
        let deck = DeckIR(meta: Meta(title: "Turbines"), slides:
            [IRSlide(id: "title", layout: "title", title: "Wind power")] + slides
            + [IRSlide(id: "end", layout: "closing", title: "Next step", body: Body(callToAction: "Act"))])
        return String(decoding: try JSONEncoder().encode(deck), as: UTF8.self)
    }

    private func run(json: String, slideCount: Int, images: CountingImageProvider) async throws -> DeckResult {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("image-budget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let generator = DeckGenerator(provider: FixtureProvider(validJSON: json),
                                      imageProvider: images, quality: false)
        let request = DeckRequest(prompt: "turbines", slideCount: slideCount, notes: false)
        return try await generator.generate(request, designURL: nil, into: dir) { _ in }
    }

    @Test func budgetIsTheSlideCountPlusTheValidatorTolerance() {
        #expect(PriceTable.imageCallBudgetFactor == 1.25)
        #expect(PriceTable.imageCallBudget(slideCount: 10) == 13)
        #expect(PriceTable.imageCallBudget(slideCount: 8) == 10)
        #expect(PriceTable.imageCallBudget(slideCount: 0) == 1)
    }

    @Test func briefsBeyondTheBudgetAreDroppedInSlideOrderWithAWarning() async throws {
        let images = CountingImageProvider()
        let result = try await run(json: try deckJSON(briefs: 40), slideCount: 10, images: images)

        #expect(images.calls.count == 13, "a 10-slide request may spend at most 13 image calls")
        #expect(images.calls.count <= 13)
        let warning = try #require(result.warnings.first { $0.contains("were not generated") })
        #expect(warning.contains("40 exceeds the budget of 13 for a 10-slide request"))
        for i in 13..<40 { #expect(warning.contains("\"s\(i)\""), "dropped slide s\(i) must be named") }
        for i in 0..<13 { #expect(!warning.contains("\"s\(i)\""), "kept slide s\(i) must not be named") }
        // The first 13 briefs in slide order are the ones generated.
        let prompts = Set(images.calls)
        for i in 0..<13 { #expect(prompts.contains("a turbine, view \(i)")) }
    }

    @Test func anOverlongBriefIsClampedBeforeItReachesTheProvider() async throws {
        let long = String(repeating: "wind turbine ", count: 160)   // 2,080 scalars
        #expect(long.unicodeScalars.count > 2_000)
        let images = CountingImageProvider()
        let result = try await run(json: try deckJSON(briefs: 2) { $0 == 0 ? long : "a turbine at dusk" },
                                   slideCount: 4, images: images)

        #expect(images.calls.count == 2)
        let sent = try #require(images.calls.first { $0.hasPrefix("wind turbine") })
        #expect(sent.unicodeScalars.count <= ImageStyleDirective.maximumSubjectScalars)
        #expect(sent.unicodeScalars.count > ImageStyleDirective.maximumSubjectScalars / 2)
        #expect(sent.hasSuffix("wind") || sent.hasSuffix("turbine"), "cut on a word boundary")
        #expect(images.calls.contains("a turbine at dusk"), "a short brief is untouched")
        let warning = try #require(result.warnings.first { $0.contains("were shortened") })
        #expect(warning.contains("\"s0\""))
        #expect(!warning.contains("\"s1\""))
    }

    @Test func clampingPrefersAWordBoundaryAndCountsScalars() {
        let max = ImageStyleDirective.maximumSubjectScalars
        let exact = String(repeating: "x", count: max)
        #expect(ImageStyleDirective.clampSubject(exact) == (exact, false))

        // No whitespace at all: a hard cut at the limit.
        let solid = String(repeating: "y", count: max * 2)
        let (hard, hardCut) = ImageStyleDirective.clampSubject(solid)
        #expect(hardCut && hard.unicodeScalars.count == max)

        // Multi-scalar characters count by scalar, not by Character.
        let flags = String(repeating: "🇳🇴", count: max)   // two scalars each
        let (clipped, cut) = ImageStyleDirective.clampSubject(flags)
        #expect(cut && clipped.unicodeScalars.count <= max)
    }

    @Test func aDeckWithinBudgetIsUnchanged() async throws {
        let images = CountingImageProvider()
        let result = try await run(json: try deckJSON(briefs: 4), slideCount: 6, images: images)

        #expect(images.calls.count == 4, "every brief within budget is generated")
        #expect(Set(images.calls) == Set((0..<4).map { "a turbine, view \($0)" }), "prompts are sent verbatim")
        #expect(!result.warnings.contains { $0.contains("Image briefs") })
        #expect(!result.warnings.contains { $0.contains("couldn't be generated") })
    }
}

/// Records each prompt it is asked to draw and returns a minimal PNG (Rostrum
/// only sniffs the header to place it).
private final class CountingImageProvider: ImageProvider, @unchecked Sendable {
    let id: ImageProviderID = .openAI
    private let lock = NSLock()
    private var prompts: [String] = []

    var calls: [String] { lock.lock(); defer { lock.unlock() }; return prompts }

    private func record(_ prompt: String) { lock.lock(); defer { lock.unlock() }; prompts.append(prompt) }

    func image(prompt: String, style: String?, aspect: ImageAspect, role: ImageRole) async throws -> Data {
        record(prompt)
        func be32(_ v: Int) -> [UInt8] {
            [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
        }
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        b += be32(13); b += Array("IHDR".utf8); b += be32(8); b += be32(8)
        b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }
}
