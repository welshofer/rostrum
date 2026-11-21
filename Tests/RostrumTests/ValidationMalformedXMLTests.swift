import Foundation
import Testing
@testable import Rostrum

@Suite("ValidationMalformedXMLTests")
struct ValidationMalformedXMLTests {

    @Test func truncatedSlideXMLProducesValidationIssueAfterRoundTripOpen() throws {
        let deck = try Presentation()
        let slide = try deck.slides[0]
        slide.part.replaceBlob(Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:sld><p:cSld>".utf8))

        let archiveBytes = try deck.serializedData()
        let reopened = try Presentation(data: archiveBytes)
        let issues = try reopened.validate()

        #expect(issues.count == 1)
        #expect(issues.first?.part == "/ppt/slides/slide1.xml")
        #expect(issues.first?.element == "#document")
        #expect(issues.first?.message.contains("malformed XML") == true)
    }

    @Test func malformedChartAndCustomXMLPartsAreReportedWithoutFalsePositivesOnBinaryParts() throws {
        let deck = try Presentation()
        deck.package.addPart(
            uri: PackURI("/customXml/item1.xml"),
            contentType: "application/xml; charset=utf-8",
            blob: Data("<broken attr=".utf8)
        )
        deck.package.addPart(
            uri: PackURI("/ppt/charts/chart99.xml"),
            contentType: "application/vnd.openxmlformats-officedocument.drawingml.chart+xml",
            blob: Data([0xFF, 0xFE, 0x00])
        )
        // Binary part whose filename ends in .xml and SVG media asset with <!DOCTYPE svg>.
        deck.package.addPart(
            uri: PackURI("/ppt/embeddings/opaque.xml"),
            contentType: "application/octet-stream",
            blob: Data([0x89, 0x50, 0x4E, 0x47, 0xFF, 0x00])
        )
        deck.package.addPart(
            uri: PackURI("/ppt/media/image1.svg"),
            contentType: ContentType.svg,
            blob: Data("<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\"><svg/>".utf8)
        )
        deck.package.addPart(
            uri: PackURI("/ppt/embeddings/empty-ct.xml"),
            contentType: "",
            blob: Data([0xFF, 0x00])
        )
        deck.package.addPart(
            uri: PackURI("/ppt/embeddings/semicolon-ct.xml"),
            contentType: ";",
            blob: Data([0xFF, 0x00])
        )
        deck.package.addPart(
            uri: PackURI("/ppt/embeddings/param-only-ct.xml"),
            contentType: "; application/xml",
            blob: Data("<unclosed".utf8)
        )

        let reopened = try Presentation(data: try deck.serializedData())
        let issues = try reopened.validate()
        let flaggedParts = issues.map(\.part)

        #expect(flaggedParts == ["/customXml/item1.xml", "/ppt/charts/chart99.xml"])
        #expect(issues.allSatisfy { $0.element == "#document" && $0.message.contains("malformed XML") })
        #expect(!flaggedParts.contains("/ppt/embeddings/opaque.xml"))
        #expect(!flaggedParts.contains("/ppt/media/image1.svg"))
        #expect(!flaggedParts.contains("/ppt/embeddings/empty-ct.xml"))
        #expect(!flaggedParts.contains("/ppt/embeddings/semicolon-ct.xml"))
        #expect(!flaggedParts.contains("/ppt/embeddings/param-only-ct.xml"))
    }
}
