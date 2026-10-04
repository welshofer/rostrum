import Foundation
import Testing
@testable import Rostrum

@Suite struct RenderImageRelationshipsTests {
    private let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

    private func relationship(_ id: String, target: String = "../media/good.png", external: Bool = false) -> Relationship {
        Relationship(rId: id, type: RelType.image, target: target, isExternal: external)
    }

    private func owner(_ name: String, package: OPCPackage, count: Int = 512) -> Part {
        let part = package.addPart(uri: PackURI("/ppt/slides/\(name).xml"), contentType: ContentType.slide, blob: Data())
        part.rels.setItems((0..<count).map { relationship("image\($0)") })
        return part
    }

    @Test func indexedLookupsPreserveFirstMatchExternalMissingAndOwnerSemantics() throws {
        let package = OPCPackage()
        let good = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        let bad = package.addPart(uri: PackURI("/ppt/media/bad.png"), contentType: ContentType.png, blob: Data([1, 2, 3]))
        let first = owner("first", package: package)
        first.rels.setItems(first.rels.items + [
            relationship("duplicate"), relationship("duplicate", target: "../media/bad.png"),
            relationship("external", target: "https://example.com/image.png", external: true), relationship("external"),
            relationship("absent-part", target: "../media/absent.png"),
            relationship("caf\u{00E9}"), relationship("cafe\u{0301}", target: "../media/bad.png"),
        ])
        let second = owner("second", package: package)
        second.rels.setItems(second.rels.items + [relationship("duplicate", target: "../media/bad.png")])
        let resources = RenderImageResources()
        #expect(resources.resolve("image0", owner: first, package: package)?.data == good.blob)
        #expect(resources.relationshipIndexEntryCount == 0)
        #expect(resources.resolve("unused-first", owner: first, package: package) == nil)
        #expect(resources.resolve("unused-second", owner: first, package: package) == nil)
        #expect(resources.relationshipIndexEntryCount > 0)
        #expect(resources.resolve("duplicate", owner: first, package: package)?.data == good.blob)
        #expect(resources.resolve("external", owner: first, package: package) == nil)
        #expect(resources.resolve("absent-part", owner: first, package: package) == nil)
        #expect(resources.resolve("absent-id", owner: first, package: package) == nil)
        #expect(resources.resolve("cafe\u{0301}", owner: first, package: package)?.data == good.blob)
        _ = resources.resolve("unused-first", owner: second, package: package)
        _ = resources.resolve("unused-second", owner: second, package: package)
        #expect(resources.resolve("duplicate", owner: second, package: package)?.data == bad.blob)
        #expect(resources.resolve("duplicate", owner: second, package: package)?.info == nil)
    }

    @Test func unusedOwnersAndOverBudgetRelationshipSetsStayOnTheLinearPath() throws {
        let package = OPCPackage()
        _ = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        let resources = RenderImageResources()
        let oversized = owner("oversized", package: package, count: 4097)
        #expect(resources.resolve("image0", owner: oversized, package: package)?.data == png)
        #expect(resources.resolve("image4096", owner: oversized, package: package)?.data == png)
        #expect(resources.relationshipIndexEntryCount == 0)
        for number in 0..<20 {
            let part = owner("owner\(number)", package: package, count: 1024)
            #expect(resources.resolve("image0", owner: part, package: package)?.data == png)
            #expect(resources.resolve("image1023", owner: part, package: package)?.data == png)
            #expect(resources.resolve("unused", owner: part, package: package) == nil)
        }
        #expect(resources.relationshipIndexEntryCount > 0)
        #expect(resources.relationshipIndexEntryCount <= 4096)
        #expect(resources.relationshipIndexBytes <= 512 * 1024)
        #expect(resources.relationshipOwnerCount <= 16)
    }

    @Test func sparseEarlyLookupsStayLinearWhileDenseLookupsEarnAnIndex() throws {
        let package = OPCPackage()
        _ = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        let resources = RenderImageResources()
        // The 1,024-entry list fits the byte budget: staying linear must be
        // due to low observed work, rather than rejected index admission.
        for count in [1024, 4096] {
            let sparse = owner("sparse\(count)", package: package, count: count)
            for _ in 0..<100 {
                #expect(resources.resolve("image0", owner: sparse, package: package)?.data == png)
                #expect(resources.resolve("image1", owner: sparse, package: package)?.data == png)
            }
            #expect(resources.relationshipIndexEntryCount == 0 && resources.relationshipIndexBytes == 0)
            #expect(resources.relationshipOwnerCount == 0)
        }
        let dense = owner("dense", package: package, count: 1024)
        for index in 0..<40 { #expect(resources.resolve("image\(index)", owner: dense, package: package)?.data == png) }
        #expect(resources.relationshipIndexEntryCount == 0)
        for index in 40..<80 { #expect(resources.resolve("image\(index)", owner: dense, package: package)?.data == png) }
        #expect(resources.relationshipIndexEntryCount == 1024)
    }

    @Test func thresholdAndIntermediateSizesPreserveResultsWithoutIndexingSmallOwners() throws {
        let package = OPCPackage()
        _ = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        for count in [250, 511, 512, 768, 1024] {
            let resources = RenderImageResources()
            let part = owner("threshold\(count)", package: package, count: count)
            #expect(resources.resolve("image0", owner: part, package: package)?.data == png)
            #expect(resources.resolve("missing-first", owner: part, package: package) == nil)
            #expect(resources.resolve("missing-second", owner: part, package: package) == nil)
            #expect(resources.resolve("image\(count / 2)", owner: part, package: package)?.data == png)
            #expect(resources.resolve("image\(count - 1)", owner: part, package: package)?.data == png)
            if count < 512 {
                #expect(resources.relationshipOwnerCount == 0)
                #expect(resources.relationshipIndexEntryCount == 0 && resources.relationshipIndexBytes == 0)
            } else {
                #expect(resources.relationshipIndexEntryCount == count)
                #expect(resources.relationshipOwnerCount == 1)
            }
        }
    }

    @Test func prefixUsesFirstMatchForDuplicateUnicodeAndExternalRelationships() throws {
        let package = OPCPackage()
        _ = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        _ = package.addPart(uri: PackURI("/ppt/media/bad.png"), contentType: ContentType.png, blob: Data([1, 2, 3]))
        let part = owner("prefix", package: package)
        part.rels.setItems([
            relationship("caf\u{00E9}"), relationship("cafe\u{0301}", target: "../media/bad.png"),
            relationship("external", target: "https://example.com/image.png", external: true),
            relationship("duplicate"),
        ] + part.rels.items + [relationship("external"), relationship("duplicate", target: "../media/bad.png")])
        let resources = RenderImageResources()
        #expect(resources.resolve("cafe\u{0301}", owner: part, package: package)?.data == png)
        #expect(resources.resolve("external", owner: part, package: package) == nil)
        #expect(resources.resolve("duplicate", owner: part, package: package)?.data == png)
        #expect(resources.relationshipOwnerCount == 0)
        _ = resources.resolve("missing-first", owner: part, package: package)
        _ = resources.resolve("missing-second", owner: part, package: package)
        #expect(resources.relationshipIndexEntryCount > 0)
        // Reset also clears the per-reference cache for prefix results.
        part.rels.setItems([relationship("caf\u{00E9}", target: "../media/bad.png")] + part.rels.items)
        resources.reset()
        #expect(resources.resolve("cafe\u{0301}", owner: part, package: package)?.data == Data([1, 2, 3]))
        #expect(resources.relationshipOwnerCount == 0)
    }

    @Test func oversizedMetadataDiscardsPartialIndexAndDoesNotRetryBeforeReset() throws {
        let package = OPCPackage()
        _ = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        let part = owner("metadata", package: package)
        let ordinary = part.rels.items
        part.rels.setItems(ordinary + [Relationship(rId: "huge", type: String(repeating: "x", count: 512 * 1024),
                                                   target: "../media/good.png", isExternal: false)])
        let resources = RenderImageResources()
        _ = resources.resolve("unused-first", owner: part, package: package)
        _ = resources.resolve("unused-second", owner: part, package: package)
        #expect(resources.resolve("image1", owner: part, package: package)?.data == png)
        #expect(resources.relationshipIndexEntryCount == 0 && resources.relationshipIndexBytes == 0)
        // A refused owner stays linear even if later lookups could now fit.
        part.rels.setItems(ordinary)
        _ = resources.resolve("unused-third", owner: part, package: package)
        _ = resources.resolve("unused-fourth", owner: part, package: package)
        #expect(resources.resolve("image2", owner: part, package: package)?.data == png)
        #expect(resources.relationshipIndexEntryCount == 0 && resources.relationshipIndexBytes == 0)
        resources.reset()
        _ = resources.resolve("unused-first", owner: part, package: package)
        _ = resources.resolve("unused-second", owner: part, package: package)
        #expect(resources.resolve("image1", owner: part, package: package)?.data == png)
        #expect(resources.relationshipIndexEntryCount > 0)
    }

    @Test func resetObservesRelationshipRetargetingRemovalAndReplacedMedia() throws {
        let package = OPCPackage()
        let media = package.addPart(uri: PackURI("/ppt/media/good.png"), contentType: ContentType.png, blob: png)
        _ = package.addPart(uri: PackURI("/ppt/media/bad.png"), contentType: ContentType.png, blob: Data([1, 2, 3]))
        let part = owner("mutable", package: package)
        let original = part.rels.items
        let resources = RenderImageResources()
        _ = resources.resolve("unused-first", owner: part, package: package)
        _ = resources.resolve("unused-second", owner: part, package: package)
        #expect(resources.resolve("image1", owner: part, package: package)?.info != nil)
        #expect(resources.resolve("new-id", owner: part, package: package) == nil)
        part.rels.setItems(original.filter { !["image1", "image2"].contains($0.rId) }
            + [relationship("image1", target: "../media/bad.png"), relationship("new-id")])
        media.replaceBlob(Data([4, 5, 6]))
        resources.reset()
        #expect(resources.relationshipIndexEntryCount == 0 && resources.relationshipIndexBytes == 0)
        #expect(resources.relationshipOwnerCount == 0)
        #expect(resources.resolve("image0", owner: part, package: package)?.data == Data([4, 5, 6]))
        _ = resources.resolve("unused-first", owner: part, package: package)
        _ = resources.resolve("unused-second", owner: part, package: package)
        #expect(resources.resolve("image1", owner: part, package: package)?.data == Data([1, 2, 3]))
        #expect(resources.resolve("image2", owner: part, package: package) == nil)
        #expect(resources.resolve("new-id", owner: part, package: package)?.data == Data([4, 5, 6]))
        media.replaceBlob(png)
        part.rels.setItems(original)
        resources.reset()
        _ = resources.resolve("unused-first", owner: part, package: package)
        _ = resources.resolve("unused-second", owner: part, package: package)
        #expect(resources.resolve("image1", owner: part, package: package)?.data == png)
        #expect(resources.resolve("new-id", owner: part, package: package) == nil)
    }

    @Test func indexedImagesRetainPerShapeDiagnosticOrderAndRendererReset() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        let frame = Rect(x: .zero, y: .zero, width: .inches(1), height: .inches(1))
        var pictures: [Picture] = []
        for _ in 0..<20 { pictures.append(try slide.shapes.addPicture(png, frame: frame)) }
        // Late, actively used image IDs earn an index even though there are
        // only twenty pictures; unused arcs have no shape diagnostics.
        let part = slide.part
        part.rels.setItems((0..<512).map { relationship("unused\($0)") } + part.rels.items)
        let renderer = SVGRenderer(slidePart: slide.part, slideSize: deck.slideSize,
                                   theme: slide.resolvedTheme, package: deck.package, fonts: deck.fonts, slideNumber: 1)
        let original = try renderer.render(pixelWidth: 640)
        let media = try #require(pictures.first?.imagePart)
        media.replaceBlob(Data([1, 2, 3]))
        let broken = try renderer.render(pixelWidth: 640)
        #expect(broken.problems.fidelityIssues.map(\.code) == Array(repeating: .unsupportedImage, count: 20))
        let expectedIDs = pictures.map { $0.element.firstChild(named: "p:nvPicPr")?.firstChild(named: "p:cNvPr")?[attribute: "id"] }
        #expect(broken.problems.fidelityIssues.map(\.location.shapeID) == expectedIDs)
        media.replaceBlob(png)
        let restored = try renderer.render(pixelWidth: 640)
        #expect(restored.svg == original.svg && restored.problems == original.problems)
    }
}
