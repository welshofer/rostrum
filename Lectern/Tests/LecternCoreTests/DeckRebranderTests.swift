import Foundation
import Testing
import Rostrum
@testable import LecternCore

/// The rebrand path — Lectern's reason to open a deck rather than only write
/// one, and the thing that exercises Rostrum's read side.
@Suite struct DeckRebranderTests {
    private func tempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rebrand-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A deck shaped like one somebody would want rebranded: real content, and
    /// colours hard-coded from its own theme, which is what Rostrum's builders
    /// write and what PowerPoint writes.
    private func sourceDeck(in directory: URL) throws -> URL {
        let deck = try Presentation()
        try deck.titleSlide("Q3 Review", subtitle: "Prepared by Finance")
        try deck.bulletSlide("Highlights", ["Revenue up", "Costs flat", "Headcount steady"])
        let url = directory.appendingPathComponent("source.pptx")
        try deck.save(to: url)
        return url
    }

    private func templateDeck(in directory: URL) throws -> URL {
        let template = try Presentation()
        template.theme.majorFont = "Papyrus"
        template.theme.minorFont = "Courier New"
        template.theme.setColor(.accent1, Color("0078D4"))
        let url = directory.appendingPathComponent("brand.potx")
        try template.save(to: url)
        return url
    }

    @Test func rebrandingWritesANewDeckAndNeverTouchesTheOriginal() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = try sourceDeck(in: dir)
        let template = try templateDeck(in: dir)
        let sourceBytes = try Data(contentsOf: source)

        let result = try await DeckRebrander().rebrand(
            deck: source, template: template, into: dir.appendingPathComponent("out"))

        #expect(result.url.lastPathComponent == "source-rebranded.pptx")
        #expect(FileManager.default.fileExists(atPath: result.url.path))
        // The input is the user's file; a rebrand is not entitled to replace it.
        #expect(try Data(contentsOf: source) == sourceBytes)
    }

    @Test func theRebrandedDeckCarriesTheTemplatesBrand() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRebrander().rebrand(
            deck: try sourceDeck(in: dir), template: try templateDeck(in: dir),
            into: dir.appendingPathComponent("out"))

        let rebranded = try Presentation(contentsOf: result.url)
        #expect(rebranded.theme.majorFont == "Papyrus")
        #expect(rebranded.theme.color(.accent1)?.hex.uppercased() == "0078D4")
        #expect(result.relaid > 0)
        // Rostrum's builders write literals, so there is always something to
        // rebind on a deck built this way — and rebinding is what lets the new
        // accent actually reach the text.
        #expect(result.reboundColors > 0)
    }

    @Test func slidesAreNeitherAddedNorLost() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = try sourceDeck(in: dir)
        let expected = try Presentation(contentsOf: source).slides.count

        let result = try await DeckRebrander().rebrand(
            deck: source, template: try templateDeck(in: dir),
            into: dir.appendingPathComponent("out"))

        #expect(result.slideCount == expected)
        #expect(try Presentation(contentsOf: result.url).slides.count == expected)
    }

    /// The before/after pair is the product: a rebrand nobody can see is
    /// indistinguishable from one that did not happen.
    @Test func aPreviewIsRenderedForEverySlideBothWays() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRebrander().rebrand(
            deck: try sourceDeck(in: dir), template: try templateDeck(in: dir),
            into: dir.appendingPathComponent("out"))

        #expect(result.before.count == result.slideCount)
        #expect(result.after.count == result.slideCount)
        #expect(result.before != result.after, "the rebrand changed nothing visible")
        #expect(result.before.allSatisfy { $0.contains("<svg") })
    }

    @Test func theWrittenDeckPassesRostrumsOwnLint() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await DeckRebrander().rebrand(
            deck: try sourceDeck(in: dir), template: try templateDeck(in: dir),
            into: dir.appendingPathComponent("out"))
        #expect(result.schemaIssues.isEmpty, "\(result.schemaIssues.prefix(3))")
    }

    @Test func somethingThatIsNotADeckIsReportedNotCrashed() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let notADeck = dir.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: notADeck)

        await #expect(throws: RebrandError.self) {
            _ = try await DeckRebrander().rebrand(
                deck: notADeck, template: try self.templateDeck(in: dir),
                into: dir.appendingPathComponent("out"))
        }
        // And the same for the template side.
        await #expect(throws: RebrandError.self) {
            _ = try await DeckRebrander().rebrand(
                deck: try self.sourceDeck(in: dir), template: notADeck,
                into: dir.appendingPathComponent("out"))
        }
    }

    @Test func rebrandingTwiceDoesNotOverwriteTheFirstResult() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = try sourceDeck(in: dir)
        let template = try templateDeck(in: dir)
        let out = dir.appendingPathComponent("out")

        let first = try await DeckRebrander().rebrand(deck: source, template: template, into: out)
        let second = try await DeckRebrander().rebrand(deck: source, template: template, into: out)

        #expect(first.url != second.url)
        #expect(second.url.lastPathComponent == "source-rebranded-2.pptx")
        #expect(FileManager.default.fileExists(atPath: first.url.path))
    }

    /// What the user actually did: File ▸ Save as Template. That writes a
    /// `.potx` whose main part is content-typed `template`, not merely a deck
    /// with a different extension.
    private func savedAsTemplate(in directory: URL) throws -> URL {
        let deck = try Presentation()
        try deck.titleSlide("Q3 Review", subtitle: "Prepared by Finance")
        try deck.bulletSlide("Highlights", ["Revenue up", "Costs flat"])
        deck.documentKind = .template
        let url = directory.appendingPathComponent("saved-as-template.potx")
        try deck.save(to: url)
        return url
    }

    /// A `.potx` has slides, so it is a legitimate thing to rebrand — but the
    /// output is written as `.pptx`, and PowerPoint decides what a file is from
    /// the main part's content type rather than its extension. Ship the
    /// template content type inside a `.pptx` and double-clicking the result
    /// spawns a new untitled deck instead of opening the rebranded one.
    @Test func rebrandingATemplateProducesADeckAndNotAnotherTemplate() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = try savedAsTemplate(in: dir)
        #expect(try Presentation(contentsOf: source).documentKind == .template,
                "the fixture is not actually a template")

        let result = try await DeckRebrander().rebrand(
            deck: source, template: try templateDeck(in: dir),
            into: dir.appendingPathComponent("out"))

        #expect(result.url.pathExtension == "pptx")
        #expect(try Presentation(contentsOf: result.url).documentKind == .presentation)
        #expect(result.slideCount == (try Presentation(contentsOf: source).slides.count))
    }
}
