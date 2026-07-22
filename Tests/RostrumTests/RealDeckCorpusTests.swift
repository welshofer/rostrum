import Foundation
import Testing
@testable import Rostrum

/// PowerPoint-authored fixture decks, when any are checked in. See
/// Fixtures/RealDecks/README.md — drop `.pptx` files there to enroll them.
private let realDecks: [URL] = {
    guard let base = Bundle.module.resourceURL?
        .appendingPathComponent("Fixtures/RealDecks") else { return [] }
    let files = (try? FileManager.default.contentsOfDirectory(
        at: base, includingPropertiesForKeys: nil)) ?? []
    return files.filter { $0.pathExtension.lowercased() == "pptx" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}()

/// Relationship parts and the content-types stream are parsed into models on
/// open and deterministically re-serialized — they are exempt from the
/// byte-identity gate (see ARCHITECTURE.md; making them pristine too is on
/// the v0.4 hardening backlog).
private func isReserializedStream(_ entryName: String) -> Bool {
    entryName == "[Content_Types].xml" || entryName.hasSuffix(".rels")
}

/// The lossless-round-trip hard rule, proven against decks Rostrum did NOT
/// write: authored in PowerPoint/Keynote/Google Slides, checked in as
/// fixtures. Rostrum-generated corpora can't exercise foreign XML habits
/// (attribute order, exotic parts, vendor extensions), so this gate is only
/// as strong as the fixture set — see the README for what to include.
@Suite struct RealDeckCorpusTests {
    /// Compares at the zip-entry level, not through `package.parts`, so
    /// nothing the reader chooses not to model can silently escape the gate.
    /// Every content part must come back byte-identical after an open → save
    /// with no edits (the pristine-blob guarantee); the two re-serialized
    /// streams (`.rels`, `[Content_Types].xml`) are checked for presence.
    @Test func untouchedForeignContentPartsSurviveByteIdentically() throws {
        for url in realDecks {
            let original = try Data(contentsOf: url)
            let resaved = try Presentation(data: original).serializedData()

            let before = try ZipReader(data: original)
            let after = try ZipReader(data: resaved)
            let afterNames = Set(after.entryNames)
            for name in before.entryNames {
                #expect(afterNames.contains(name),
                        "\(url.lastPathComponent): \(name) missing after resave")
                guard !isReserializedStream(name), afterNames.contains(name) else { continue }
                #expect(try after.data(forEntry: name) == before.data(forEntry: name),
                        "\(url.lastPathComponent): \(name) bytes changed on resave")
            }
        }
    }

    @Test func foreignDeckResavesAreDeterministic() throws {
        for url in realDecks {
            let original = try Data(contentsOf: url)
            let once = try Presentation(data: original).serializedData()
            let twice = try Presentation(data: once).serializedData()
            #expect(once == twice,
                    "\(url.lastPathComponent): resave is not a fixed point")
        }
    }

    @Test func foreignDecksEnumerateWithoutTrapping() throws {
        for url in realDecks {
            let deck = try Presentation(data: try Data(contentsOf: url))
            var slides = 0
            for slide in deck.slides {
                _ = slide.shapes.count
                slides += 1
            }
            #expect(slides == deck.slides.count,
                    "\(url.lastPathComponent): iterator skipped unresolvable slides")
        }
    }
}
