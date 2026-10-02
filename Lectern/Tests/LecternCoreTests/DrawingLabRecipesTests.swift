import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite("Drawing Library Lab recipes")
struct DrawingLabRecipesTests {
    @Test("Every recipe reopens and checks both variants", arguments: DrawingLabRecipes.catalog.map(\.id))
    func everyRecipe(_ id: LibraryDemoID) throws {
        var variants: [Data] = []
        for alternative in [false, true] {
            let options = LibraryLabOptions(text: "Independent specimen <&>", accentHex: "A54263", sampleSize: 3, alternative: alternative)
            let draft = try DrawingLabRecipes.make(id, options: options)
            let before = try #require(draft.before)
            let after = try draft.deck.serializedData()
            #expect(before != after)
            let baseline = try Presentation(data: before)
            #expect(baseline.slides.count > 0)
            let reopened = try Presentation(data: after)
            let checks = try draft.checks + draft.verify(reopened)
            #expect(!checks.isEmpty)
            for check in checks { #expect(check.passed, "\(id.rawValue): \(check.name): \(check.detail)") }
            let warm = try reopened.serializedData()
            #expect(try reopened.serializedData() == warm)
            variants.append(after)
            // Independent expectations, beyond recipe-reported checks.
            switch id {
            case .shapes:
                #expect(reopened.slides.flatMap { $0.shapes.all }.filter { $0.name.hasPrefix("Preset: ") }.count == 178)
            case .tableStyles:
                let tables = reopened.slides.flatMap { $0.shapes.all.compactMap { ($0 as? TableFrame)?.table } }
                #expect(Set(tables.compactMap(\.styleID)).count == 74)
                #expect(tables.allSatisfy { $0.rightToLeft == alternative })
            case .tableStructure:
                let tables = try reopened.slides[0].shapes.all.compactMap { ($0 as? TableFrame)?.table }
                let table = try #require(tables.first)
                #expect(table.rowCount == 3 && table.columnCount == 3)
                #expect(try table.cell(1, 1).text == options.text)
                #expect(try table.cell(2, 2).text == "R3C3")
            case .pictures:
                let images = try reopened.slides[0].shapes.all.compactMap { $0 as? Picture }
                #expect(images[0].imageData != images[1].imageData)
                #expect(images[1].imageData == LibraryLabSupport.pixels)
                let retainedSlide = try reopened.slides[1]
                let retained = retainedSlide.shapes.all.compactMap { $0 as? Picture }
                #expect(retained.count == 3)
                #expect(retained[1].imageData == DrawingLabFixtures.jpeg)
                #expect(retained[1].rotation == 30)
                let metadata = try #require(ImageSniffer.sniff(DrawingLabFixtures.jpeg))
                #expect(metadata.format == .jpeg && metadata.pixelWidth == 4 && metadata.pixelHeight == 4)
                let source = try Presentation(data: before)
                let beforeImages = try source.slides[1].shapes.all.compactMap { $0 as? Picture }
                #expect(beforeImages[1].imageData == LibraryLabSupport.pixels)
                let beforeXML = try DrawingLabFixtures.shapeXML("Retained ellipse and flips", slide: source.slides[1])
                let afterXML = try DrawingLabFixtures.shapeXML("Retained ellipse and flips", slide: retainedSlide)
                #expect(DrawingLabFixtures.nodes(beforeXML, "a:xfrm").first?.serialized() == DrawingLabFixtures.nodes(afterXML, "a:xfrm").first?.serialized())
                #expect(try !DrawingLabFixtures.mappingMatches(svg: reopened.renderSVG(slideAt: 0), bytes: images[0].imageData!, mime: "image/gif", frame: images[0].frame, crop: PictureCrop(left: 0.45), geometry: "rect", rotation: alternative ? -20 : 20, flipped: false))
            case .text:
                let body = try #require(reopened.slides[0].shapes.all.first { $0.name == "Rich text specimen" }?.textFrame)
                #expect(body.paragraphs.first?.runs.first?.text == options.text)
                #expect(body.paragraphs.count == 5)
            case .tableAppearance:
                let tables = try reopened.slides[0].shapes.all.compactMap { ($0 as? TableFrame)?.table }
                let table = try #require(tables.first)
                #expect(try table.cell(0, 0).text == options.text)
                #expect(try table.cell(0, 0).border(.diagonalDown)?.width == .points(5))
                let custom = try reopened.slides[1].shapes.all.compactMap { ($0 as? TableFrame)?.table }
                #expect(custom.count == 3)
                #expect(custom[0].styleID == DrawingLabFixtures.styleID)
                #expect(custom[1].styleID != custom[0].styleID && custom[1].styleID == custom[2].styleID)
                #expect(reopened.package.parts.values.contains { $0.blob == DrawingLabFixtures.opaque })
            case .fillsAndLines:
                #expect(try reopened.slides[0].shapes[2].fill == .solid(Color("A54263"), alpha: 0.4))
            default: Issue.record("Unexpected drawing recipe")
            }
        }
        #expect(variants[0] != variants[1])
    }

    @Test("Galleries stay bounded at maximum input")
    func maximumGalleries() throws {
        for id in [LibraryDemoID.shapes, .tableStyles, .tableStructure, .text] {
            let draft = try DrawingLabRecipes.make(id, options: .init(sampleSize: 12, alternative: true))
            #expect(draft.deck.slides.count <= 15)
            let checks = try draft.verify(Presentation(data: draft.deck.serializedData()))
            #expect(checks.allSatisfy { $0.passed })
        }
    }
}
