import Foundation
import Testing
@testable import Rostrum

/// `.rels` parts and `[Content_Types].xml` used to be the one documented
/// exception to the byte-identity rule: they were parsed into models and
/// deterministically rebuilt, so a foreign package's own attribute order,
/// spacing and element order changed on every save. They are parts too, and
/// the rule now covers them.
@Suite struct PristinePackageStreamsTests {
    /// A relationships stream written the way another producer might:
    /// attribute order, indentation and the standalone declaration all vary
    /// freely between producers, and a rebuild would normalize every one.
    private let foreignRels = Data("""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml" Id="rId1"/>
    </Relationships>
    """.utf8)

    @Test func untouchedRelationshipsReEmitVerbatim() throws {
        let rels = try Relationships.parse(foreignRels)
        #expect(rels.items.count == 1)
        // Attribute order here is Type/Target/Id, and the file is indented —
        // a rebuild would normalize both.
        #expect(rels.serialized() == foreignRels)
    }

    @Test func mutatingRelationshipsRebuildsThem() throws {
        let rels = try Relationships.parse(foreignRels)
        rels.add(type: RelType.slide, target: "slides/slide1.xml")
        let rebuilt = rels.serialized()
        #expect(rebuilt != foreignRels)
        // …and the rebuild is still correct and deterministic.
        let reparsed = try Relationships.parse(rebuilt)
        #expect(reparsed.items.count == 2)
        #expect(reparsed.serialized() == rebuilt)
    }

    @Test func removingARelationshipAlsoRebuilds() throws {
        let rels = try Relationships.parse(foreignRels)
        rels.remove(rId: "rId1")
        #expect(rels.serialized() != foreignRels)
        #expect(try Relationships.parse(rels.serialized()).items.isEmpty)
    }

    private let foreignContentTypes = Data("""
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
    </Types>
    """.utf8)

    @Test func untouchedContentTypesReEmitVerbatim() throws {
        let map = try ContentTypesMap.parse(foreignContentTypes)
        // Overrides before Defaults, and indented — a rebuild sorts and
        // reorders both.
        #expect(map.serialized() == foreignContentTypes)
        #expect(try map.contentType(for: PackURI("/ppt/presentation.xml"))
                == ContentType.presentationMain)
    }

    @Test func changingContentTypesRebuildsThem() throws {
        var map = try ContentTypesMap.parse(foreignContentTypes)
        map.setDefault(extension: "png", contentType: "image/png")
        #expect(map.serialized() != foreignContentTypes)

        // A no-op write must NOT dirty the map: setting a value it already
        // holds is how the writer re-asserts defaults on every save.
        var untouched = try ContentTypesMap.parse(foreignContentTypes)
        untouched.setDefault(extension: "xml", contentType: "application/xml")
        untouched.setOverride(partName: PackURI("/ppt/presentation.xml"),
                              contentType: ContentType.presentationMain)
        untouched.removeOverride(partName: PackURI("/ppt/nonexistent.xml"))
        #expect(untouched.serialized() == foreignContentTypes)
    }

    @Test func aDeckThatOnlyReadsKeepsEveryStreamByteIdentical() throws {
        // The end-to-end promise: open, read everything, save — identical
        // bytes for every zip entry including .rels and [Content_Types].xml.
        let deck = try Presentation()
        try deck.bulletSlide("Title", ["one", "two"])
        try deck.chartSlide("Chart", .line,
                            ChartData(categories: ["A", "B"], name: "S", values: [1, 2]))
        let original = try deck.serializedData()

        let reopened = try Presentation(data: original)
        for slide in reopened.slides {
            for shape in slide.shapes.all { _ = (shape.kind, shape.frame, shape.textFrame?.text) }
        }
        _ = reopened.charts.map(\.categories)
        _ = reopened.documentProperties.title
        _ = reopened.slideMasters.map(\.layouts)

        let resaved = try reopened.serializedData()
        let before = try ZipReader(data: original)
        let after = try ZipReader(data: resaved)
        #expect(Set(after.entryNames) == Set(before.entryNames))
        for name in before.entryNames {
            #expect(try after.data(forEntry: name) == before.data(forEntry: name),
                    "\(name) changed on a read-only round trip")
        }
    }

    @Test func editingOneSlideLeavesOtherStreamsUntouched() throws {
        let deck = try Presentation()
        try deck.bulletSlide("One", ["a"])
        try deck.bulletSlide("Two", ["b"])
        let original = try deck.serializedData()

        let reopened = try Presentation(data: original)
        try reopened.slides[1].shapes.addTextBox(
            Rect(x: .inches(1), y: .inches(1), width: .inches(2), height: .inches(1)))
            .textFrame?.text = "added"
        let resaved = try reopened.serializedData()

        let before = try ZipReader(data: original)
        let after = try ZipReader(data: resaved)
        // Adding a shape touches exactly one slide part. No new parts, so the
        // content-types stream and every .rels must be byte-identical.
        for name in before.entryNames where name != "ppt/slides/slide2.xml" {
            #expect(try after.data(forEntry: name) == before.data(forEntry: name),
                    "\(name) changed when only a slide body was edited")
        }
    }
}
