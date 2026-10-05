import Foundation
import Testing
import Rostrum
@testable import LecternCore

@Suite struct ImageOwnersRecipeTests {
    @Test(arguments: [false, true])
    func savedOwnersAndExports(alternative: Bool) throws {
        let retained = ProcessInfo.processInfo.environment["LECTERN_IMAGE_OWNERS_ARTIFACTS"]
        let parent = retained.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent("ImageOwners-" + UUID().uuidString)
        defer { if retained == nil { try? FileManager.default.removeItem(at: parent) } }
        let result = try LibraryLab.run(.imageOwners, options: .init(alternative: alternative), in: parent)
        #expect(result.passed)
        for check in result.checks { #expect(check.passed, "\(check.name): \(check.detail)") }
        #expect(result.findings.isEmpty && result.slideCount == 5)
        let bytes = try Data(contentsOf: result.afterURL), deck = try Presentation(data: bytes)
        #expect(deck.slideSize.width == .points(864) && deck.slideSize.height == .points(540))
        #expect(try deck.slides[4].part.dom()[attribute: "xmlns:r"] == "http://schemas.openxmlformats.org/officeDocument/2006/relationships")
        let reference = try PlatformLabRecipes.imageOwnersReferences()
        #expect(reference.sources.count == 4 && reference.sources.reduce(0) { $0 + $1.paints.count } == 7)
        for source in reference.sources {
            #expect(try Data(contentsOf: result.directory.appendingPathComponent("native-source-" + source.originalSource)) == PlatformLabRecipes.resource(String(source.source.dropLast(5)), "pptx"))
        }
        let exported = try DeckExporter.export(deckAt: result.afterURL, into: result.directory.appendingPathComponent("second-export"))
        #expect(exported.assetsWritten == (alternative ? 5 : 6) && exported.warnings.isEmpty)
        let outline = deck.outline()
        for slide in outline.slides { for asset in slide.assets {
            let file = exported.directory.appendingPathComponent(String(format: "slide-%02d/", slide.number) + asset.filename)
            #expect(try Data(contentsOf: file) == deck.package.part(at: PackURI(asset.partName)).blob)
        } }
        #expect(try Data(contentsOf: result.afterURL) == bytes && deck.serializedData() == bytes)
        if retained != nil {
            let output = parent.appendingPathComponent("native-candidates/alternative-\(alternative)")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try bytes.write(to: output.appendingPathComponent("imageOwners.pptx"))
            for page in 0..<5 { try Data(deck.renderSVG(slideAt: page).utf8).write(to: output.appendingPathComponent("slide-\(page + 1).svg")) }
        }
    }
    @Test func strictPaintAuditRejectsMovedWrongOrTransformedImages() throws {
        let draft = try PlatformLabRecipes.imageOwners(.init()), reference = try PlatformLabRecipes.imageOwnersReferences()
        let raw = try draft.deck.renderSVG(slideAt: 0), red = try PlatformLabRecipes.resource("ImageOwners-theme-red", "png"), blue = try PlatformLabRecipes.resource("ImageOwners-slide-blue", "png")
        let original = try ImageOwnersSVGPage(raw)
        #expect(original.matches(reference.sources[0].paints, red: red, blue: blue))
        let overpaint = try ImageOwnersSVGPage(raw)
        overpaint.root.appendElement(XML.Element("rect", attributes: [("x", "0"), ("y", "0"), ("width", "9999999"), ("height", "9999999"), ("fill", "#FFFFFF")]))
        #expect(!overpaint.matches(reference.sources[0].paints, red: red, blue: blue))
        for (kind, attribute, value) in [("svg", "transform", "translate(12700 0)"), ("image", "href", "data:image/png;base64," + blue.base64EncodedString()), ("image", "x", "12700"), ("image", "opacity", "0.5"), ("g", "transform", "translate(12700 0)"), ("pattern", "patternTransform", "scale(2)"), ("rect", "transform", "translate(1 0)")] {
            let page = try ImageOwnersSVGPage(raw)
            let node = try #require(DrawingLabFixtures.nodes(page.root, kind).first)
            node[attribute: attribute] = value
            #expect(!page.matches(reference.sources[0].paints, red: red, blue: blue), "Reject \(kind) \(attribute)")
        }
    }
    @Test func ownerGraphRejectsWrongImageAndInvalidMasterID() throws {
        let data = try PlatformLabRecipes.resource("ImageOwners-theme-collision", "pptx")
        let source = try Presentation(data: data), destination = try Presentation(data: data)
        #expect(try PlatformLabRecipes.imageOwnerGraphMatches(source, destination, destinationIndex: 0))
        let theme = destination.theme.part
        let rel = try #require(theme.rels.relationship(withId: "rIdOwnerProbe"))
        let image = try destination.package.part(at: PackURI.resolve(target: rel.target, relativeTo: theme.uri.baseURI))
        let original = image.blob
        image.replaceBlob(try PlatformLabRecipes.resource("ImageOwners-slide-blue", "png"))
        #expect(try !PlatformLabRecipes.imageOwnerGraphMatches(source, destination, destinationIndex: 0))
        image.replaceBlob(original)
        let master = try #require(destination.slides[0].master?.part)
        let id = try #require(master.dom().firstChild(named: "p:sldLayoutIdLst")?.firstChild(named: "p:sldLayoutId"))
        id[attribute: "id"] = "0"; master.markDirty()
        _ = try destination.serializedData()
        #expect(try !PlatformLabRecipes.imageOwnerGraphMatches(source, destination, destinationIndex: 0))
    }
    @Test func alternativeChangesOnlyThePublicPage() throws {
        let first = try PlatformLabRecipes.imageOwners(.init()), second = try PlatformLabRecipes.imageOwners(.init(alternative: true))
        for page in 0..<4 { #expect(try first.deck.renderSVG(slideAt: page) == second.deck.renderSVG(slideAt: page)) }
        #expect(try first.deck.renderSVG(slideAt: 4) != second.deck.renderSVG(slideAt: 4))
        #expect(try PlatformLabRecipes.imageOwnerControlMatches(first.deck, alternative: false))
        #expect(try PlatformLabRecipes.imageOwnerControlMatches(second.deck, alternative: true))
    }
}
