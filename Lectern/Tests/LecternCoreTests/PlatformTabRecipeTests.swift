import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct PlatformTabRecipeTests {
    @Test(arguments: [false, true], [2, 12])
    func boundedRowsAndMovedStopsReachSavedGeometry(moved: Bool, rows: Int) throws {
        let draft = try PlatformLabRecipes.make(.tabLayout, options: .init(text: "Saved tab example", accentHex: "A54263", sampleSize: rows, alternative: moved))
        let bytes = try draft.deck.serializedData()
        let deck = try Presentation(data: bytes)
        #expect(deck.registerEmbeddedFonts() == ["DejaVu Sans"])
        let expectedStop = (moved ? 1.8 : 1.4) * 72
        let metrics = try #require(deck.fonts.metrics(for: "DejaVu Sans"))
        for (name, mode) in PlatformLabRecipes.tabModes {
            let box = try #require(deck.slides[0].shapes.all.first { $0.name == name + " tab fields" })
            let paragraphs = try #require(box.textFrame?.paragraphs)
            #expect(paragraphs.count == rows)
            #expect(paragraphs[0].tabStops == [TextTabStop(position: .points(expectedStop), alignment: mode)])
            #expect(paragraphs[0].defaultTabInterval == .inches(0.5))
            let layout = try PlatformLabRecipes.tabGeometry(deck, named: box.name)
            #expect(layout.lines.count == rows && layout.fits && layout.diagnostics.isEmpty)
            for (row, line) in layout.lines.enumerated() {
                let spans = line.spans.filter { !$0.run.text.isEmpty && $0.run.text != "\t" }
                let start = try #require(spans.first).x
                let end = try #require(spans.last)
                let value = PlatformLabRecipes.tabSamples[row]
                #expect(spans.map(\.run.text).joined() == value)
                switch mode {
                case .left: #expect(abs(start - expectedStop) < 0.01)
                case .center: #expect(abs((start + end.x + end.width) / 2 - expectedStop) < 0.01)
                case .right: #expect(abs(end.x + end.width - expectedStop) < 0.01)
                case .decimal:
                    let beforePeriod = String(value.prefix { $0 != "." })
                    #expect(abs(start + metrics.width(of: beforePeriod, pointSize: 16) - expectedStop) < 0.01)
                }
            }
        }
        for check in draft.checks + (try draft.verify(deck)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try deck.serializedData() == bytes)
        #expect(try draft.deck.renderSVG(slideAt: 0).contains("#A54263"))
        // Opt-in retention exposes these exact bounded test specimens to native
        // PowerPoint review without adding a separate fixture authoring path.
        if let parent = ProcessInfo.processInfo.environment["LECTERN_TAB_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("rows-\(rows)-moved-\(moved)-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("tabLayout.pptx"))
        }
    }

    @Test func eachControlChangesTheRealArtifact() throws {
        let base = try PlatformLabRecipes.make(.tabLayout, options: .init())
        let bytes = try base.deck.serializedData()
        for options in [LibraryLabOptions(text: "Another title"), .init(accentHex: "963D61"), .init(sampleSize: 12), .init(alternative: true)] {
            let changed = try PlatformLabRecipes.make(.tabLayout, options: options)
            #expect(try changed.deck.serializedData() != bytes)
        }
        let moved = try PlatformLabRecipes.make(.tabLayout, options: .init(alternative: true))
        #expect(try PlatformLabRecipes.tabGeometry(base.deck, named: "Decimal tab fields").lines != PlatformLabRecipes.tabGeometry(moved.deck, named: "Decimal tab fields").lines)
    }

    @Test(arguments: [false, true])
    func justifiedTabAndTableExpandSpacesAfterTheirAnchor(moved: Bool) throws {
        let draft = try PlatformLabRecipes.make(.tabLayout, options: .init(alternative: moved))
        let natural = try PlatformLabRecipes.tabGeometry(draft.deck, named: "Natural tab paragraph", slideAt: 1)
        let justified = try PlatformLabRecipes.tabGeometry(draft.deck, named: "Justified tab paragraph", slideAt: 1)
        let metrics = try #require(draft.deck.fonts.metrics(for: "DejaVu Sans"))
        let first = try #require(justified.lines.first)
        #expect(first.spans.contains { $0.run.text == " " && $0.width > metrics.width(of: " ", pointSize: 16) + 0.1 })
        #expect(abs(PlatformLabRecipes.paragraphVisibleWidth(first, fonts: draft.deck.fonts) - 5.7 * 72) < 0.01)
        #expect(natural.lines.last?.width == justified.lines.last?.width)
        #expect(try PlatformLabRecipes.tabTableGeometry(draft.deck).lines == justified.lines)
        let reopened = try Presentation(data: draft.deck.serializedData())
        reopened.registerEmbeddedFonts()
        #expect(try PlatformLabRecipes.tabGeometry(reopened, named: "Justified tab paragraph", slideAt: 1).lines == justified.lines)
    }
}
