import Foundation
import Testing
@testable import Rostrum

@Suite struct PictureMappingTests {
    // Valid 4×4 RGBA PNG, independently encoded with Python zlib: top-left
    // red, top-right green, bottom-left blue, bottom-right half-alpha yellow.
    private let quadrants = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAG0lEQVR4nGP4z8DwH4SRIJoAlA8EDA0gjCEAAE9EIeGwsrFwAAAAAElFTkSuQmCC")!
    private var frame: Rect { Rect(x: EMU(100000), y: EMU(200000), width: EMU(400000), height: EMU(200000)) }

    private func picture() throws -> (Presentation, Picture) {
        let deck = try Presentation()
        return (deck, try deck.slides[0].shapes.addPicture(quadrants, frame: frame))
    }
    private func reopen(_ deck: Presentation) throws -> (Presentation, Picture) {
        let copy = try Presentation(data: deck.serializedData())
        return (copy, try #require(copy.slides[0].shapes.all.first as? Picture))
    }
    private func descendants(_ element: XML.Element, named name: String) -> [XML.Element] {
        var result: [XML.Element] = [], stack = [element]
        while let node = stack.popLast() {
            if node.name == name { result.append(node) }
            stack.append(contentsOf: node.childElements.reversed())
        }
        return result
    }

    private func exportOracle(_ svg: String, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["ROSTRUM_IMAGE_ORACLE_OUTPUT"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(svg.utf8).write(to: directory.appendingPathComponent(name + ".svg"))
    }

    @Test func stretchDistortsWholeSourceInsteadOfCenterSlicing() throws {
        let (deck, picture) = try picture()
        #expect(picture.crop == nil)
        let before = picture.element.serialized()
        let svg = try deck.renderSVG(slideAt: 0)
        try exportOracle(svg, name: picture.crop == nil ? "stretch" : "asymmetric-crop")
        let root = try XML.parse(Data(svg.utf8))
        let image = try #require(descendants(root, named: "image").first)
        #expect(image[attribute: "preserveAspectRatio"] == "none")
        #expect(image[attribute: "width"] == "400000.0")
        #expect(image[attribute: "height"] == "200000.0")
        #expect(image[attribute: "href"] == "data:image/png;base64,\(quadrants.base64EncodedString())")
        #expect(picture.element.serialized() == before)
        let (copy, copied) = try reopen(deck)
        #expect(copied.imageData == quadrants)
        #expect(try copy.renderSVG(slideAt: 0) == svg)
    }

    @Test func asymmetricCropMapsOnlyRightHandQuadrantsToFrame() throws {
        let (deck, picture) = try picture()
        try picture.setCrop(PictureCrop(left: 0.5))
        let svg = try deck.renderSVG(slideAt: 0)
        try exportOracle(svg, name: picture.crop == nil ? "stretch" : "asymmetric-crop")
        let root = try XML.parse(Data(svg.utf8))
        let image = try #require(descendants(root, named: "image").first)
        // A source point at x=2/4 lands on the frame's left edge. The
        // remaining green/yellow half stretches into the entire 400000 EMU.
        #expect(image[attribute: "x"] == "-400000.0")
        #expect(image[attribute: "width"] == "800000.0")
        let clip = try #require(descendants(root, named: "clipPath").first?.firstChild(named: "rect"))
        #expect(clip[attribute: "width"] == "400000.0")
        let (copy, copied) = try reopen(deck)
        #expect(copied.crop == PictureCrop(left: 0.5))
        #expect(copied.imageData == quadrants)
        #expect(try copy.renderSVG(slideAt: 0) == svg)
    }

    @Test func negativeCropAddsTransparentSpaceAndFillRectInsetsDestination() throws {
        let (deck, picture) = try picture()
        try picture.setCrop(PictureCrop(left: -0.5, right: -0.5))
        let fill = try #require(picture.element.firstChild(named: "p:blipFill"))
        let fillRect = try #require(fill.firstChild(named: "a:stretch")?.firstChild(named: "a:fillRect"))
        fillRect[attribute: "t"] = "25000"
        fillRect[attribute: "b"] = "25000"
        let svg = try deck.renderSVG(slideAt: 0)
        let image = try #require(descendants(XML.parse(Data(svg.utf8)), named: "image").first)
        #expect(image[attribute: "x"] == "100000.0")
        #expect(image[attribute: "y"] == "50000.0")
        #expect(image[attribute: "width"] == "200000.0")
        #expect(image[attribute: "height"] == "100000.0")
        picture.part.markDirty()
        let (copy, copied) = try reopen(deck)
        #expect(copied.crop?.left == -0.5)
        #expect(try copy.renderSVG(slideAt: 0) == svg)
    }

    @Test func invalidPictureFrameRefusesBeforeEmbedding() throws {
        let deck = try Presentation()
        let before = try deck.serializedData()
        #expect(throws: RostrumError.self) {
            try deck.slides[0].shapes.addPicture(quadrants,
                frame: Rect(x: EMU(0), y: EMU(0), width: EMU(-100), height: EMU(0)), fit: .fill)
        }
        #expect(try deck.serializedData() == before)
    }

    @Test func invalidCropsAndUnsupportedReplacementAreAtomic() throws {
        let (deck, picture) = try picture()
        let before = try deck.serializedData()
        for crop in [PictureCrop(left: .nan), PictureCrop(top: .infinity), PictureCrop(left: 0.8, right: 0.3),
                     PictureCrop(left: 0.499999, right: 0.499999), PictureCrop(bottom: Double.greatestFiniteMagnitude)] {
            #expect(throws: RostrumError.self) { try picture.setCrop(crop) }
            #expect(try deck.serializedData() == before)
        }
        #expect(throws: RostrumError.self) { try picture.replaceImage(Data("unsupported".utf8)) }
        #expect(try deck.serializedData() == before)
        #expect(!picture.part.isDirty)
    }

    @Test func alternateOfficeSourcesRefuseReplacementAtomically() throws {
        for name in ["asvg:svgBlip", "a14:imgProps", "alternate:svgBlip"] {
            let (deck, picture) = try picture()
            let blip = try #require(picture.element.firstChild(named: "p:blipFill")?.firstChild(named: "a:blip"))
            let alternate = XML.Element(name, attributes: [("r:embed", "rIdAlternate")])
            let prefix = String(name.split(separator: ":")[0])
            alternate[attribute: "xmlns:" + prefix] = "http://schemas.microsoft.com/office/drawing/2016/SVG/main"
            blip.appendElement(XML.Element("a:extLst", children: [.element(alternate)]))
            picture.part.markDirty()
            let before = try deck.serializedData()
            let replacement = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!
            #expect(throws: RostrumError.self) { try picture.replaceImage(replacement) }
            #expect(try deck.serializedData() == before)
            #expect(!picture.part.isDirty)
        }
    }

    @Test func replacementPreservesCropUnknownMetadataAndSharedImage() throws {
        let (deck, picture) = try picture()
        let shared = try deck.slides[0].shapes.addPicture(quadrants, frame: frame)
        try picture.setCrop(PictureCrop(left: 0.25, bottom: 0.125))
        picture.rotation = 90
        let fill = try #require(picture.element.firstChild(named: "p:blipFill"))
        fill.firstChild(named: "a:blip")?.appendElement(XML.Element("a:extLst", children: [.comment("image extension")]))
        let relationship = try #require(picture.imageRelationshipID)
        let originalRelationships = picture.part.rels.items
        let replacement = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!
        try picture.replaceImage(replacement)
        #expect(picture.imageRelationshipID != relationship)
        #expect(picture.part.rels.items.starts(with: originalRelationships))
        #expect(shared.imageData == quadrants)
        let (_, copied) = try reopen(deck)
        #expect(copied.imageData == replacement)
        #expect(copied.crop == PictureCrop(left: 0.25, bottom: 0.125))
        #expect(copied.rotation == 90)
        #expect(copied.element.serialized().contains("image extension"))
    }

    @Test func tiledCellAndShapeFillsUseNativeSizeAndMirrorOffsets() throws {
        let deck = try Presentation()
        let shape = try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .image(quadrants, fit: .tile(scale: 2)))
        let tile = try #require(shape.element.firstChild(named: "p:spPr")?.firstChild(named: "a:blipFill")?.firstChild(named: "a:tile"))
        tile[attribute: "flip"] = "xy"
        tile[attribute: "tx"] = "100"
        tile[attribute: "ty"] = "200"
        shape.part.markDirty()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: frame)
        table.clearBuiltInStyle()
        try table.cell(0, 0).setFill(.image(quadrants, fit: .tile(scale: 2)))
        let svg = try deck.renderSVG(slideAt: 0)
        try exportOracle(svg, name: "tile")
        #expect(!svg.contains("#DDDDDD"))
        let patterns = descendants(try XML.parse(Data(svg.utf8)), named: "pattern")
        #expect(patterns.count == 2)
        // Four pixels at 72dpi = 50800 EMU, scaled 2x; mirrored repeat 2x.
        #expect(patterns[0][attribute: "width"] == "203200.0")
        #expect(patterns[0][attribute: "height"] == "203200.0")
        #expect(patterns[0][attribute: "x"] == "100100.0")
        #expect(patterns[0][attribute: "y"] == "200200.0")
        #expect(patterns[0].serialized().contains("scale(-1 -1)"))
        #expect(patterns[1][attribute: "width"] == "101600.0")
        let copy = try Presentation(data: deck.serializedData())
        #expect(try copy.renderSVG(slideAt: 0) == svg)
    }

    @Test func pictureRotationFlipsAndGeometryClipTogether() throws {
        let (deck, picture) = try picture()
        picture.rotation = 90
        let properties = try #require(picture.element.firstChild(named: "p:spPr"))
        properties.firstChild(named: "a:xfrm")?[attribute: "flipH"] = "true"
        properties.firstChild(named: "a:xfrm")?[attribute: "flipV"] = "1"
        properties.firstChild(named: "a:prstGeom")?[attribute: "prst"] = "ellipse"
        try picture.setCrop(PictureCrop(top: 0.5))
        let svg = try deck.renderSVG(slideAt: 0)
        try exportOracle(svg, name: "rotation-flips")
        #expect(svg.contains("rotate(90.0) scale(-1 -1)"))
        #expect(svg.contains("<ellipse"))
        #expect(svg.contains("preserveAspectRatio=\"none\""))
        let (copy, _) = try reopen(deck)
        #expect(try copy.renderSVG(slideAt: 0) == svg)
    }
}
