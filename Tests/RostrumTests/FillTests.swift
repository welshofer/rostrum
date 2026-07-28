import Foundation
import Testing
@testable import Rostrum

@Suite struct FillTests {
    private var png: Data {
        var b: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        func be32(_ v: Int) -> [UInt8] { [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)] }
        b += be32(13); b += Array("IHDR".utf8); b += be32(40); b += be32(30); b += [8, 6, 0, 0, 0]; b += be32(0)
        b += be32(0); b += Array("IEND".utf8); b += be32(0)
        return Data(b)
    }
    private let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(4), height: .inches(3))

    private func lastSpPr(_ deck: Presentation) throws -> XML.Element {
        let tree = try deck.slides[0].part.dom()
            .firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!
        return tree.children(named: "p:sp").last!.firstChild(named: "p:spPr")!
    }

    @Test func shapeImageFillEmitsDrawingMLBlipFill() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .image(png))
        let spPr = try lastSpPr(deck)
        // The fill wrapper is a:blipFill (DrawingML), NOT p:blipFill (picture).
        let blip = try #require(spPr.firstChild(named: "a:blipFill"))
        #expect(spPr.firstChild(named: "p:blipFill") == nil)
        // r:embed resolves to a real image relationship + media part.
        let rId = try #require(blip.firstChild(named: "a:blip")?[attribute: "r:embed"])
        #expect(try deck.slides[0].part.rels.relationship(withId: rId)?.type == RelType.image)
        #expect(deck.package.parts.keys.contains { $0.value.hasPrefix("/ppt/media/") })
        // Schema order: a:blipFill precedes a:ln.
        let names = spPr.childElements.map(\.name)
        #expect(names.firstIndex(of: "a:blipFill")! < names.firstIndex(of: "a:ln")!)
    }

    @Test func stretchVsTile() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .image(png))                 // stretch
        try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .image(png, fit: .tile(scale: 0.5)))
        let shapes = try deck.slides[0].part.dom()
            .firstChild(named: "p:cSld")!.firstChild(named: "p:spTree")!.children(named: "p:sp")
        let stretch = shapes[shapes.count - 2].firstChild(named: "p:spPr")!.firstChild(named: "a:blipFill")!
        let tile = shapes[shapes.count - 1].firstChild(named: "p:spPr")!.firstChild(named: "a:blipFill")!
        #expect(stretch.firstChild(named: "a:stretch")?.firstChild(named: "a:fillRect") != nil)
        #expect(tile.firstChild(named: "a:tile")?[attribute: "sx"] == "50000")
    }

    @Test func slideBackgroundImage() throws {
        let deck = try Presentation()
        try deck.slides[0].setBackground(.image(png))
        let cSld = try deck.slides[0].part.dom().firstChild(named: "p:cSld")!
        // p:bg is the first child of p:cSld; a:blipFill lives in p:bgPr.
        #expect(cSld.childElements.first?.name == "p:bg")
        let bgPr = cSld.firstChild(named: "p:bg")!.firstChild(named: "p:bgPr")!
        let names = bgPr.childElements.map(\.name)
        #expect(names.firstIndex(of: "a:blipFill")! < names.firstIndex(of: "a:effectLst")!)
    }

    @Test func radialGradientEmitsPathNotLin() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addShape(.rectangle, frame: frame,
            fill: .gradient(.radial(from: Color("FF0000"), to: Color("0000FF"))))
        let grad = try lastSpPr(deck).firstChild(named: "a:gradFill")!
        let names = grad.childElements.map(\.name)
        #expect(names == ["a:gsLst", "a:path"])
        #expect(grad.firstChild(named: "a:path")?[attribute: "path"] == "circle")
        #expect(grad.firstChild(named: "a:lin") == nil)
    }

    @Test func pictureAndFillShareOneMediaPart() throws {
        let deck = try Presentation()
        try deck.slides[0].shapes.addPicture(png, x: .inches(1), y: .inches(1))
        try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .image(png))
        // Same bytes → one media part, but two distinct relationships.
        let media = deck.package.parts.keys.filter { $0.value.hasPrefix("/ppt/media/") }
        #expect(media.count == 1)
        let imageRels = try deck.slides[0].part.rels.items.filter { $0.type == RelType.image }
        #expect(imageRels.count == 2)
        #expect(Set(imageRels.map(\.rId)).count == 2)
        // Content type rides on an extension Default, not a per-part Override.
        #expect(deck.package.contentTypes.overrides[media.first!] == nil)
        #expect(deck.package.contentTypes.defaults["png"] != nil)
    }

    @Test func imageFillWithoutPackageThrows() throws {
        let deck = try Presentation()
        let table = try deck.slides[0].shapes.addTable(rows: 1, columns: 1, frame: frame)
        #expect(throws: RostrumError.self) {
            try table.cell(0, 0).setFill(.image(png))
        }
    }

    @Test func imageAndGradientDeckIsDeterministicAndReopens() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            try deck.slides[0].setBackground(.image(png))
            try deck.slides[0].shapes.addShape(.rectangle, frame: frame, fill: .image(png, fit: .tile()))
            try deck.slides[0].shapes.addShape(.rectangle,
                frame: Rect(x: .inches(6), y: .inches(1), width: .inches(3), height: .inches(3)),
                fill: .gradient(.radial(from: Color("18A999"), to: Color("0B1D33"))))
            return try deck.serializedData()
        }
        let a = try build(), b = try build()
        #expect(a == b)                          // same input → byte-identical
        _ = try Presentation(data: a)            // reopens (inflate + CRC verify)
        _ = try ZipReader(data: a)               // valid archive
    }
}
