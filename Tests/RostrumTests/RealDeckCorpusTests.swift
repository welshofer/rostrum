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

/// The lossless-round-trip hard rule, proven against decks Rostrum did NOT
/// write: authored in PowerPoint/Keynote/Google Slides, checked in as
/// fixtures. Rostrum-generated corpora can't exercise foreign XML habits
/// (attribute order, exotic parts, vendor extensions), so this gate is only
/// as strong as the fixture set — see the README for what to include.
@Suite struct RealDeckCorpusTests {
    @Test func untouchedForeignPartsSurviveByteIdentically() throws {
        for url in realDecks {
            let original = try Data(contentsOf: url)
            let resaved = try Presentation(data: original).serializedData()

            // Every part of the original must come back byte-identical after
            // an open → save with no edits (the pristine-blob guarantee).
            let before = try Presentation(data: original).package.parts
            let after = try Presentation(data: resaved).package.parts
            #expect(Set(before.keys) == Set(after.keys),
                    "\(url.lastPathComponent): part set changed on resave")
            for (uri, part) in before {
                #expect(after[uri]?.blob == part.blob,
                        "\(url.lastPathComponent): \(uri) bytes changed on resave")
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
