import Foundation
import Testing
@testable import Rostrum

/// `ShapeCollection.count` and `subscript` read `p:spTree` directly instead of
/// materialising `all` (R-PERF-1). The risk that buys is disagreement: four
/// entry points onto the same tree that could filter, order or — worst of all
/// — cache differently. Everything here pins them together.
///
/// A slide with one of everything, plus the two node kinds a shape tree may
/// legally carry that are not elements at all: an XML comment and a processing
/// instruction, interleaved among the shapes. Anything that assumed every
/// child of `p:spTree` is an element miscounts this fixture.
private let mixedSlideXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" \
xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree>\
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>\
<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>\
<!-- authored by something that comments its shape trees -->\
<p:sp><p:nvSpPr><p:cNvPr id="2" name="Title 1"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
<p:spPr><a:xfrm><a:off x="100" y="200"/><a:ext cx="300" cy="400"/></a:xfrm></p:spPr>\
<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Hello</a:t></a:r></a:p></p:txBody></p:sp>\
<p:pic><p:nvPicPr><p:cNvPr id="3" name="Photo 2" descr="A cat"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>\
<p:blipFill><a:blip r:embed="rId99"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\
<p:spPr><a:xfrm><a:off x="10" y="20"/><a:ext cx="30" cy="40"/></a:xfrm></p:spPr></p:pic>\
<?rostrum-marker keep-me?>\
<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="4" name="Table 3"/><p:cNvGraphicFramePr/>\
<p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x="1000" y="2000"/><a:ext cx="3000" cy="4000"/></p:xfrm>\
<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">\
<a:tbl><a:tblPr/><a:tblGrid><a:gridCol w="1500"/><a:gridCol w="1500"/></a:tblGrid>\
<a:tr h="370"><a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>R1C1</a:t></a:r></a:p></a:txBody></a:tc>\
<a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>R1C2</a:t></a:r></a:p></a:txBody></a:tc></a:tr>\
</a:tbl></a:graphicData></a:graphic></p:graphicFrame>\
<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="5" name="Chart 4"/><p:cNvGraphicFramePr/>\
<p:nvPr/></p:nvGraphicFramePr><p:xfrm><a:off x="5" y="6"/><a:ext cx="7" cy="8"/></p:xfrm>\
<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">\
<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" r:id="rId7"/>\
</a:graphicData></a:graphic></p:graphicFrame>\
<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="6" name="Connector 5"/>\
<p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>\
<p:spPr><a:xfrm><a:off x="11" y="12"/><a:ext cx="13" cy="14"/></a:xfrm></p:spPr></p:cxnSp>\
<p:grpSp><p:nvGrpSpPr><p:cNvPr id="7" name="Group 6"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>\
<p:grpSpPr><a:xfrm><a:off x="1000" y="1000"/><a:ext cx="2000" cy="2000"/>\
<a:chOff x="0" y="0"/><a:chExt cx="1000" cy="1000"/></a:xfrm></p:grpSpPr>\
<p:sp><p:nvSpPr><p:cNvPr id="8" name="In group"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>\
<p:spPr><a:xfrm><a:off x="500" y="500"/><a:ext cx="100" cy="100"/></a:xfrm></p:spPr>\
<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Nested</a:t></a:r></a:p></p:txBody></p:sp></p:grpSp>\
<p:extLst><p:ext uri="{X}"/></p:extLst>\
</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
"""

private func deckWithMixedSlide() throws -> Presentation {
    let deck = try Presentation()
    try deck.slides[0].part.replaceBlob(Data(mixedSlideXML.utf8))
    return deck
}

/// The identity of a shape as the four accessors must agree on it: same
/// element, same facade type, same z-order position.
private struct ShapeFingerprint: Equatable, CustomStringConvertible {
    let objectID: ObjectIdentifier
    let facade: String
    let name: String
    let kind: ShapeKind

    init(_ shape: Shape) {
        objectID = ObjectIdentifier(shape.element)
        facade = String(describing: type(of: shape))
        name = shape.name
        kind = shape.kind
    }

    var description: String { "\(facade)(\(name))" }
}

private func fingerprints(_ shapes: [Shape]) -> [ShapeFingerprint] {
    shapes.map(ShapeFingerprint.init)
}

/// Every accessor, over one collection: `all`, `subscript` driven by `count`,
/// and `Sequence` iteration.
private func everyView(of shapes: ShapeCollection)
    -> (all: [ShapeFingerprint], indexed: [ShapeFingerprint], iterated: [ShapeFingerprint], count: Int) {
    let count = shapes.count
    var indexed: [ShapeFingerprint] = []
    for index in 0..<count { indexed.append(ShapeFingerprint(shapes[index])) }
    var iterated: [ShapeFingerprint] = []
    for shape in shapes { iterated.append(ShapeFingerprint(shape)) }
    return (fingerprints(shapes.all), indexed, iterated, count)
}

@Suite struct ShapeCollectionAccessTests {
    @Test func countSubscriptIterationAndAllAgreeOnAMixedSlide() throws {
        let shapes = try deckWithMixedSlide().slides[0].shapes
        let view = everyView(of: shapes)

        #expect(view.count == 6)
        #expect(view.all.count == view.count)
        #expect(view.indexed == view.all)
        #expect(view.iterated == view.all)
        // The order, kinds and facade types the tree actually declares — a
        // picture, a table, a chart, a connector and a group, not just
        // autoshapes, and the tree's own p:nvGrpSpPr/p:grpSpPr/p:extLst and
        // its comment and processing instruction excluded.
        #expect(view.all.map(\.name) == ["Title 1", "Photo 2", "Table 3", "Chart 4",
                                         "Connector 5", "Group 6"])
        #expect(view.all.map(\.facade) == ["Shape", "Picture", "TableFrame", "ChartFrame",
                                           "Connector", "GroupShape"])
        #expect(view.all.map(\.kind) == [.autoShape, .picture, .table, .chart,
                                         .connector, .group])
    }

    /// The fixture really does contain the non-element nodes this is about —
    /// otherwise the agreement test above proves nothing new.
    @Test func theFixtureCarriesCommentAndProcessingInstructionChildren() throws {
        let deck = try deckWithMixedSlide()
        let spTree = try #require(Slide.existingSpTree(of: deck.slides[0].part))
        var comments = 0
        var instructions = 0
        for node in spTree.children {
            switch node {
            case .comment: comments += 1
            case .processingInstruction: instructions += 1
            default: break
            }
        }
        #expect(comments == 1)
        #expect(instructions == 1)
        // 6 shapes + p:nvGrpSpPr + p:grpSpPr + p:extLst + the two markup nodes.
        #expect(spTree.children.count == 11)
    }

    @Test func groupChildrenUseTheSameFilterAsTheSlideItself() throws {
        let shapes = try deckWithMixedSlide().slides[0].shapes
        let group = try #require(shapes[5] as? GroupShape)
        #expect(group.shapes.count == 1)
        #expect(group.shapes[0].name == "In group")
    }

    // MARK: - Anti-staleness

    @Test func addingSlideShapesIsVisibleToEveryAccessorImmediately() throws {
        let deck = try Presentation()
        let shapes = try deck.slides[0].shapes
        let before = shapes.count

        let added = try shapes.addTextBox(
            Rect(x: EMU(0), y: EMU(0), width: EMU(100), height: EMU(100)))

        // The SAME collection instance, not a freshly minted one: a memo that
        // is not invalidated would still be serving `before` here.
        #expect(shapes.count == before + 1)
        let view = everyView(of: shapes)
        #expect(view.count == before + 1)
        #expect(view.indexed == view.all)
        #expect(view.iterated == view.all)
        #expect(shapes[before].element === added.element)
        #expect(shapes.all.last?.element === added.element)

        // And again, so a memo populated by the reads above is caught too.
        let second = try shapes.addShape(
            .ellipse, frame: Rect(x: EMU(1), y: EMU(2), width: EMU(3), height: EMU(4)),
            fill: .solid(.black))
        #expect(shapes.count == before + 2)
        #expect(shapes[before + 1].element === second.element)
        #expect(fingerprints(shapes.all) == everyView(of: shapes).indexed)
    }

    @Test func addingAPictureIsVisibleToEveryAccessorImmediately() throws {
        let deck = try Presentation()
        let shapes = try deck.slides[0].shapes
        _ = shapes.count

        let picture = try shapes.addPicture(
            onePixelPNG, frame: Rect(x: EMU(0), y: EMU(0), width: EMU(10), height: EMU(10)))

        let view = everyView(of: shapes)
        #expect(view.count == 1)
        #expect(view.indexed == view.all)
        #expect(view.iterated == view.all)
        #expect(shapes[0].element === picture.element)
        #expect(shapes[0] is Picture)
    }

    @Test func removingAShapeIsVisibleToEveryAccessorImmediately() throws {
        let deck = try deckWithMixedSlide()
        let slide = try deck.slides[0]
        let shapes = slide.shapes
        let namesBefore = shapes.all.map(\.name)
        #expect(shapes.count == 6)

        // Remove the picture, straight out of the DOM the collection views.
        let spTree = try #require(Slide.existingSpTree(of: slide.part))
        let index = try #require(spTree.children.firstIndex { node in
            if case .element(let element) = node { return element.name == "p:pic" }
            return false
        })
        spTree.children.remove(at: index)
        slide.part.markDirty()

        let view = everyView(of: shapes)
        #expect(view.count == 5)
        #expect(view.all.map(\.name) == namesBefore.filter { $0 != "Photo 2" })
        #expect(view.indexed == view.all)
        #expect(view.iterated == view.all)
        // Indices shifted down: what was at 2 is now at 1.
        #expect(shapes[1].name == "Table 3")
    }

    @Test func mutatingAShapeInPlaceIsVisibleToEveryAccessorImmediately() throws {
        let deck = try deckWithMixedSlide()
        let shapes = try deck.slides[0].shapes
        #expect(shapes[0].name == "Title 1")

        shapes[0].name = "Renamed"

        #expect(shapes[0].name == "Renamed")
        #expect(shapes.all[0].name == "Renamed")
        #expect(Array(shapes).first?.name == "Renamed")
    }

    @Test func reorderingShapesIsVisibleToEveryAccessorImmediately() throws {
        let deck = try deckWithMixedSlide()
        let slide = try deck.slides[0]
        let shapes = slide.shapes
        _ = everyView(of: shapes)

        // Send the picture to the back of the z-order (first shape child).
        let spTree = try #require(Slide.existingSpTree(of: slide.part))
        let from = try #require(spTree.children.firstIndex { node in
            if case .element(let element) = node { return element.name == "p:pic" }
            return false
        })
        let node = spTree.children.remove(at: from)
        let to = try #require(spTree.children.firstIndex { child in
            if case .element(let element) = child { return element.name == "p:sp" }
            return false
        })
        spTree.children.insert(node, at: to)
        slide.part.markDirty()

        let view = everyView(of: shapes)
        #expect(view.count == 6)
        #expect(view.all.map(\.name) == ["Photo 2", "Title 1", "Table 3", "Chart 4",
                                         "Connector 5", "Group 6"])
        #expect(view.indexed == view.all)
        #expect(view.iterated == view.all)
    }

    /// A slide part with no `p:spTree` at all: `count` must say 0 rather than
    /// create the tree, matching `all`'s empty array.
    @Test func aTreelessPartCountsZeroWithoutCreatingXML() throws {
        let deck = try Presentation()
        let part = try deck.slides[0].part
        part.replaceBlob(Data("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" \
        xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>
        """.utf8))
        let shapes = try deck.slides[0].shapes

        #expect(shapes.count == 0)
        #expect(shapes.all.isEmpty)
        #expect(Array(shapes).isEmpty)
        #expect(Slide.existingSpTree(of: part) == nil)
    }

    /// The structural claim R-PERF-1 exists to make: reading `count`, and
    /// reading one shape by index, builds no facade the caller did not ask
    /// for. Asserted by counting `Shape` initialisations, not by a clock.
    @Test func countBuildsNoFacadesAndSubscriptBuildsExactlyOne() throws {
        let deck = try deckWithMixedSlide()
        let tally = Shape.FacadeTally()
        try Shape.$facadeTally.withValue(tally) {
            let shapes = try deck.slides[0].shapes

            let beforeCount = tally.built
            #expect(shapes.count == 6)
            #expect(tally.built - beforeCount == 0)

            let beforeSubscript = tally.built
            _ = shapes[4]
            #expect(tally.built - beforeSubscript == 1)

            // The whole indexed sweep the old code made quadratic: one facade
            // per shape in total, not one per shape per iteration.
            let beforeSweep = tally.built
            for index in 0..<shapes.count { _ = shapes[index] }
            #expect(tally.built - beforeSweep == 6)

            // `all` still builds the whole list, by design.
            let beforeAll = tally.built
            _ = shapes.all
            #expect(tally.built - beforeAll == 6)
        }
    }
}

/// A 1×1 PNG, enough for `addPicture` to sniff dimensions and embed a part.
private let onePixelPNG: Data = {
    func be32(_ value: Int) -> [UInt8] {
        [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
         UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }
    var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    bytes += be32(13) + Array("IHDR".utf8)
    bytes += be32(1) + be32(1) + [8, 6, 0, 0, 0] + be32(0)
    bytes += be32(0) + Array("IEND".utf8) + be32(0)
    return Data(bytes)
}()
