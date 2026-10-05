import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct TextAlignmentRecipeTests {
    @Test(arguments: [false, true])
    func nativeAlignmentAndPublicFitsSurviveSaving(alternative: Bool) throws {
        let draft = try PlatformLabRecipes.make(.textAlignment, options: .init(alternative: alternative))
        let reference = try PlatformLabRecipes.textAlignmentReferences()
        #expect(draft.deck.slides.count == 5)
        #expect(draft.deck.slideSize.width == .points(720) && draft.deck.slideSize.height == .points(720))
        #expect(reference.cases.count == 24 && Set(reference.cases.map(\.id)).count == 24)
        #expect(reference.cases.reduce(0) { $0 + $1.expectedVisibleScalars } == 172)
        #expect(reference.cases.filter(\.table).count == 4)
        let pages = try (0..<4).map { try TextAlignmentSVGPage(svg: draft.deck.renderSVG(slideAt: $0), fonts: draft.deck.fonts) }
        for sample in reference.cases { #expect(pages[sample.slide].matches(sample), "\(sample.id)") }
        let below = try #require(reference.cases.first { $0.id == "wrap-prefix111-width-110.99-ctr" })
        let above = try #require(reference.cases.first { $0.id == "wrap-prefix111-width-111.01-ctr" })
        #expect(below.lines.map(\.visibleText) == ["BBBBBBBBBBB", "BZ"])
        #expect(above.lines.map(\.visibleText) == ["BBBBBBBBBBBB", "Z"])
        for role in ["Original", "Shape.fitText", "TextFrame.fitText"] {
            let body = try PlatformLabRecipes.paragraphBody(draft.deck, named: role + " alignment copy", slideAt: 4)
            #expect(body.firstChild(named: "a:p")?.firstChild(named: "a:pPr")?[attribute: "algn"] == (alternative ? "r" : "ctr"))
            let scale = try #require(body.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")?[attribute: "fontScale"].flatMap(Double.init))
            #expect(role == "Original" ? scale == 100_000 : scale > 0 && scale < 100_000)
            let layout = try PlatformLabRecipes.paragraphGeometry(draft.deck, named: role + " alignment copy", slideAt: 4)
            #expect(layout.fits && layout.diagnostics.isEmpty)
            #expect(layout.lines.allSatisfy { $0.visibleWidth <= 190 })
            if role != "Original" { #expect(layout.contentHeight <= 70) }
        }
        let bytes = try draft.deck.serializedData()
        let reopened = try Presentation(data: bytes)
        for check in draft.checks + (try draft.verify(reopened)) { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(try reopened.serializedData() == bytes)
        #expect(draft.extraFiles["native-alignment-reference.json"] != nil)
        if let parent = ProcessInfo.processInfo.environment["LECTERN_ALIGNMENT_ARTIFACTS"] {
            let directory = URL(fileURLWithPath: parent).appendingPathComponent("alternative-\(alternative)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: directory.appendingPathComponent("textAlignment.pptx"))
            for page in 0..<5 { try Data(draft.deck.renderSVG(slideAt: page).utf8).write(to: directory.appendingPathComponent("slide-\(page + 1).svg")) }
        }
    }

    @Test func nativeReferencesAndStrictSVGAuditRemainIndependent() throws {
        let reference = try PlatformLabRecipes.textAlignmentReferences()
        #expect(reference.sourceSHA256 == "98c27b081f8ecb9c297d46e04019b83bcdc969ed3d42113f89491aa0b9d70dac")
        #expect(reference.nativePDFSHA256 == "49b3001cee2777ec1c319c191f40836c4c20391a65224b49f6289d54908b6b66")
        #expect(Set(reference.faces.map(\.sha256)) == ["7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954", "b184b89e3c1075f22f6b71575b6fc20d4972b3cfd3b23322ca6fd596dcaef167", "107244956e9962b9e96faccdc551825e0ae0898ae13737133e1b921a2fd35ffa"])
        let draft = try PlatformLabRecipes.make(.textAlignment, options: .init())
        let sample = try #require(reference.cases.first)
        let svg = try draft.deck.renderSVG(slideAt: 0)
        #expect(try TextAlignmentSVGPage(svg: svg, fonts: draft.deck.fonts).matches(sample))
        #expect(try !TextAlignmentSVGPage(svg: svg.replacingOccurrences(of: "<tspan ", with: "<tspan textLength=\"1\" "), fonts: draft.deck.fonts).matches(sample))
        #expect(try !TextAlignmentSVGPage(svg: svg.replacingOccurrences(of: ">Agjp</tspan>", with: ">Agj</tspan>"), fonts: draft.deck.fonts).matches(sample))
        #expect(try !TextAlignmentSVGPage(svg: svg.replacingOccurrences(of: "font-size=\"14\"", with: "font-size=\"15\""), fonts: draft.deck.fonts).matches(sample))
    }
}
