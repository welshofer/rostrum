import Foundation
import Testing
@testable import Rostrum

@Suite struct RenderWorkContractTests {
    private let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

    @Test func diagnosticPathsRemainDocumentOrderedAcrossMixedSiblingNamesAndUnknownContainers() throws {
        let deck = try Presentation()
        let owner = try deck.slides[0].part
        let shape = try XML.parse(Data("""
        <p:sp><p:nvSpPr><p:cNvPr id="42"/></p:nvSpPr>
          <a:effectLst><a:glow/></a:effectLst>
          <unknown><a:prstGeom prst="star5"/><a:blip/>
            <a:prstGeom prst="ellipse"><a:avLst><a:gd/></a:avLst></a:prstGeom>
            <unknown><a:pattFill/></unknown>
          </unknown>
          <unknown><a:blip/></unknown>
        </p:sp>
        """.utf8))
        let before = shape.serialized()
        let collector = RenderDiagnosticCollector()
        collector.inspect(shape, owner: owner, slideIndex: 2, path: "/p:sp[3]", package: deck.package)
        let issues = collector.issues
        #expect(issues.map(\.code) == [.omittedEffect, .unsupportedGeometry, .unavailableImage,
                                      .unsupportedGeometry, .unsupportedFill, .unavailableImage])
        #expect(issues.map(\.location.path) == [
            "/p:sp[3]/a:effectLst[1]", "/p:sp[3]/unknown[1]/a:prstGeom[1]",
            "/p:sp[3]/unknown[1]/a:blip[1]", "/p:sp[3]/unknown[1]/a:prstGeom[2]",
            "/p:sp[3]/unknown[1]/unknown[1]/a:pattFill[1]", "/p:sp[3]/unknown[2]/a:blip[1]",
        ])
        #expect(issues.allSatisfy { $0.location.shapeID == "42" && $0.location.slideIndex == 2 })
        collector.inspect(shape, owner: owner, slideIndex: 2, path: "/p:sp[3]", package: deck.package)
        #expect(collector.issues == issues)
        collector.inspect(shape, owner: owner, slideIndex: 2, path: "/p:sp[4]", package: deck.package)
        #expect(collector.issues.count == 12)
        #expect(collector.issues.suffix(6).map(\.location.path) == issues.map { $0.location.path.replacingOccurrences(of: "/p:sp[3]", with: "/p:sp[4]") })
        collector.inspect(shape, owner: owner, slideIndex: 2, path: "/p:sp[3]", package: deck.package)
        #expect(collector.issues.count == 12)
        collector.reset()
        collector.inspect(shape, owner: owner, slideIndex: 2, path: "/p:sp[3]", package: deck.package)
        #expect(collector.issues == issues)
        #expect(shape.serialized() == before)
    }

    @Test func reusedRendererObservesDirectMediaAndRelationshipEditsBetweenRenders() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let frame = Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1))
        let first = try slide.shapes.addPicture(png, frame: frame)
        _ = try slide.shapes.addPicture(png, frame: frame)
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
                                   theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let original = try renderer.render(pixelWidth: 640)
        #expect(original.problems.isEmpty)
        let media = try #require(first.imagePart)
        media.replaceBlob(Data("unsupported raster".utf8))
        let broken = try renderer.render(pixelWidth: 640)
        let issues = broken.problems.fidelityIssues
        #expect(issues.map(\.code) == [.unsupportedImage, .unsupportedImage])
        #expect(issues[0].location.shapeID != issues[1].location.shapeID)
        #expect(!broken.svg.contains("data:image/png"))
        media.replaceBlob(png)
        let restored = try renderer.render(pixelWidth: 640)
        #expect(restored.svg == original.svg && restored.problems == original.problems)
        let blip = try #require(first.element.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip"))
        let oldID = try #require(blip[attribute: "r:embed"])
        blip[attribute: "r:embed"] = "missing"
        let missing = try renderer.render(pixelWidth: 640)
        #expect(missing.problems.fidelityIssues.map(\.code) == [.unavailableImage])
        blip[attribute: "r:embed"] = oldID
        #expect(try renderer.render(pixelWidth: 640).svg == original.svg)
    }

    @Test func imageLookupSeparatesOwnersEvenWhenRelationshipIDsMatch() throws {
        let package = OPCPackage()
        let good = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        let bad = package.addPart(uri: PackURI("/ppt/media/bad.png"), contentType: ContentType.png, blob: Data([1, 2, 3]))
        let ownerA = package.addPart(uri: PackURI("/ppt/slides/a.xml"), contentType: ContentType.slide, blob: Data())
        let ownerB = package.addPart(uri: PackURI("/ppt/slides/b.xml"), contentType: ContentType.slide, blob: Data())
        let firstID = ownerA.rels.add(type: RelType.image, target: "../media/good.png")
        let secondID = ownerB.rels.add(type: RelType.image, target: "../media/bad.png")
        #expect(firstID == secondID)
        let resources = RenderImageResources()
        #expect(resources.resolve(firstID, owner: ownerA, package: package)?.data == good.blob)
        #expect(resources.resolve(secondID, owner: ownerB, package: package)?.data == bad.blob)
        #expect(resources.resolve(secondID, owner: ownerB, package: package)?.info == nil)
        let resource = try #require(resources.resolve(firstID, owner: ownerA, package: package))
        #expect(resources.url(for: resource)?.contains(png.base64EncodedString()) == true)
    }
}
