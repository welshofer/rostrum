import Foundation
import Testing
@testable import LecternCore

/// REL-4: the design text used to be read inside the `RenderSnapshot`
/// initializer, after `illustrate` had spent the image budget and before
/// anything could be saved. A missing style file (a deleted bundle resource,
/// an iCloud-evicted custom design) then threw a raw Foundation error and the
/// paid draft, QA pass and images were all lost. The read now happens before
/// any image is bought, and a failure keeps the normalized draft.
@Suite struct DesignReadFailureTests {

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

    private func scratch() throws -> (root: URL, decks: URL, diagnostics: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("design-read-\(UUID().uuidString)", isDirectory: true)
        let decks = root.appendingPathComponent("Decks", isDirectory: true)
        let diagnostics = root.appendingPathComponent("Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: decks, withIntermediateDirectories: true)
        return (root, decks, diagnostics)
    }

    private let request = DeckRequest(prompt: "turbines", slideCount: 4, notes: false)

    private func files(in dir: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
    }

    @Test func unreadableDesignKeepsTheDraftAndBuysNoImages() async throws {
        let (root, decks, diagnostics) = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let images = CountingImageProvider()
        let generator = DeckGenerator(provider: FixtureProvider(validJSON: try illustratedDeckJSON()),
                                      imageProvider: images, quality: false)
        let missing = root.appendingPathComponent("evicted-custom-design.md")

        var reported: String?
        do {
            _ = try await generator.generate(request, designURL: missing, into: decks,
                                             diagnostics: diagnostics) { _ in }
            Issue.record("an unreadable design file must fail the run")
        } catch let LecternError.renderFailed(message) {
            reported = message
        }
        let message = try #require(reported, "expected LecternError.renderFailed")

        #expect(images.calls.isEmpty, "no image may be bought before the design is known to be readable")
        #expect(message.contains("evicted-custom-design.md"), "the message must name the design file: \(message)")

        let kept = try #require(files(in: diagnostics).first { $0.hasPrefix("rejected-draft-") && $0.hasSuffix(".json") },
                                "the draft should be kept in the diagnostics folder")
        let keptURL = diagnostics.appendingPathComponent(kept)
        #expect(message.contains("saved for recovery at \(keptURL.path)"), "\(message)")
        let recovered = try JSONDecoder().decode(DeckIR.self, from: Data(contentsOf: keptURL))
        #expect(recovered.slides.map(\.id) == ["title", "a", "b", "end"])
        #expect(recovered.slides[1].body?.bullets?.first?.text == "Coastal ridges")

        let deckFiles = files(in: decks)
        #expect(!deckFiles.contains { $0.hasPrefix("rejected-draft") }, "draft leaked into decks: \(deckFiles)")
        #expect(!deckFiles.contains { $0.hasSuffix(".pptx") }, "no deck may be written: \(deckFiles)")
    }

    @Test func readableDesignStillRendersWithImages() async throws {
        let (root, decks, diagnostics) = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let images = CountingImageProvider()
        let generator = DeckGenerator(provider: FixtureProvider(validJSON: try illustratedDeckJSON()),
                                      imageProvider: images, quality: false)
        let style = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Resources/Styles/serif.md")
        #expect(FileManager.default.fileExists(atPath: style.path))

        let result = try await generator.generate(request, designURL: style, into: decks,
                                                  diagnostics: diagnostics) { _ in }

        #expect(images.calls.count == 2)
        #expect(FileManager.default.fileExists(atPath: result.url.path))
        let recovery = try #require(result.recoveryURL)
        #expect(try RenderSnapshot.load(recovery).design == String(contentsOf: style, encoding: .utf8))
        #expect(!files(in: diagnostics).contains { $0.hasPrefix("rejected-draft") })
    }
}

/// Records each prompt it is asked to draw and returns a minimal PNG header.
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
