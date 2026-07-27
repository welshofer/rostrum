import Foundation
import Testing
@testable import Rostrum

@Suite struct DocumentPropertiesTests {
    /// A fixed instant, so every assertion is deterministic.
    private let stamp = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func corePropertiesRoundTrip() throws {
        let deck = try Presentation()
        let properties = deck.documentProperties
        properties.title = "Quarterly Review"
        properties.author = "A. Person"
        properties.subject = "Revenue"
        properties.keywords = "q3, revenue, plan"
        properties.comments = "Draft for the board"
        properties.category = "Reports"
        properties.contentStatus = "Draft"
        properties.lastModifiedBy = "B. Reviewer"
        properties.revision = 7
        properties.created = stamp
        properties.modified = stamp

        let reopened = try Presentation(data: try deck.serializedData()).documentProperties
        #expect(reopened.title == "Quarterly Review")
        #expect(reopened.author == "A. Person")
        #expect(reopened.subject == "Revenue")
        #expect(reopened.keywords == "q3, revenue, plan")
        #expect(reopened.comments == "Draft for the board")
        #expect(reopened.category == "Reports")
        #expect(reopened.contentStatus == "Draft")
        #expect(reopened.lastModifiedBy == "B. Reviewer")
        #expect(reopened.revision == 7)
        #expect(reopened.created == stamp)
        #expect(reopened.modified == stamp)
    }

    @Test func corePropertiesKeepSchemaOrder() throws {
        // CT_CoreProperties is an xsd:sequence: writing in a scattered order
        // must still serialize in schema order, or PowerPoint repairs.
        let deck = try Presentation()
        let properties = deck.documentProperties
        properties.category = "Reports"
        properties.title = "Later"
        properties.revision = 2
        properties.subject = "Ordering"

        let root = try #require(try deck.package.parts[PackURI("/docProps/core.xml")]?.dom())
        let names = root.childElements.map(\.name)
        let expected = ["dc:title", "dc:subject", "dc:creator", "cp:keywords",
                        "cp:lastModifiedBy", "cp:revision",
                        "dcterms:created", "dcterms:modified", "cp:category"]
        let present = expected.filter(names.contains)
        #expect(names.filter(present.contains) == present, "core properties out of schema order: \(names)")
        #expect(try deck.validate().isEmpty)
    }

    @Test func clearingAPropertyRemovesTheElement() throws {
        let deck = try Presentation()
        deck.documentProperties.title = "Temporary"
        deck.documentProperties.title = nil
        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.documentProperties.title == nil)
    }

    @Test func extendedPropertiesRoundTrip() throws {
        let deck = try Presentation()
        #expect(deck.documentProperties.application == "Rostrum")
        deck.documentProperties.company = "Example Ltd"
        deck.documentProperties.manager = "C. Manager"

        let reopened = try Presentation(data: try deck.serializedData()).documentProperties
        #expect(reopened.company == "Example Ltd")
        #expect(reopened.manager == "C. Manager")
        #expect(reopened.application == "Rostrum")
    }

    @Test func customPropertiesRoundTripEveryVariant() throws {
        let deck = try Presentation()
        let properties = deck.documentProperties
        #expect(properties.custom.isEmpty)
        properties.setCustomValue(.text("Legal"), for: "Department")
        properties.setCustomValue(.number(42), for: "Answer")
        properties.setCustomValue(.decimal(1.5), for: "Ratio")
        properties.setCustomValue(.boolean(true), for: "Approved")
        properties.setCustomValue(.date(stamp), for: "ReviewedOn")

        let reopened = try Presentation(data: try deck.serializedData()).documentProperties
        #expect(reopened.customValue("Department") == .text("Legal"))
        #expect(reopened.customValue("Answer") == .number(42))
        #expect(reopened.customValue("Ratio") == .decimal(1.5))
        #expect(reopened.customValue("Approved") == .boolean(true))
        #expect(reopened.customValue("ReviewedOn") == .date(stamp))
        #expect(reopened.custom.count == 5)
        #expect(reopened.customValue("Missing") == nil)
    }

    @Test func customPropertyIDsStayContiguousAcrossEdits() throws {
        // pid values must be unique and start at 2; a stale or duplicated one
        // makes PowerPoint offer to repair the file.
        let deck = try Presentation()
        let properties = deck.documentProperties
        properties.setCustomValue(.text("one"), for: "A")
        properties.setCustomValue(.text("two"), for: "B")
        properties.setCustomValue(.text("three"), for: "C")
        properties.setCustomValue(nil, for: "B")
        properties.setCustomValue(.text("four"), for: "D")

        let root = try #require(try deck.package.parts[DocumentProperties.customURI]?.dom())
        let pids = root.children(named: "property").compactMap { $0[attribute: "pid"] }
        #expect(pids == ["2", "3", "4"])
        #expect(properties.custom.map(\.name) == ["A", "C", "D"])
        #expect(try deck.validate().isEmpty)
    }

    @Test func customPartIsCreatedOnlyOnWrite() throws {
        let deck = try Presentation()
        // Reading must not create the part…
        _ = deck.documentProperties.custom
        _ = deck.documentProperties.customValue("Nothing")
        deck.documentProperties.setCustomValue(nil, for: "AlsoNothing")
        #expect(deck.package.parts[DocumentProperties.customURI] == nil)

        // …and writing wires up the content type and the package relationship.
        deck.documentProperties.setCustomValue(.text("now"), for: "Something")
        #expect(deck.package.parts[DocumentProperties.customURI] != nil)
        #expect(deck.package.rels.first(ofType: RelType.customProperties) != nil)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.documentProperties.customValue("Something") == .text("now"))
    }

    @Test func setterCreatesAMissingDocPropsPart() throws {
        // Both parts are optional in OPC and often absent from decks other
        // tooling wrote; a setter that silently vanished there would be worse
        // than useless.
        let deck = try Presentation()
        deck.package.removePart(at: PackURI("/docProps/app.xml"))
        #expect(deck.package.parts[PackURI("/docProps/app.xml")] == nil)

        deck.documentProperties.company = "Example Ltd"
        #expect(deck.package.parts[PackURI("/docProps/app.xml")] != nil)
        #expect(deck.package.rels.first(ofType: RelType.extendedProperties) != nil)

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.documentProperties.company == "Example Ltd")
        #expect(try reopened.validate().isEmpty)
    }

    @Test func propertiesAreDeterministicAndReadsArePristine() throws {
        func build() throws -> Data {
            let deck = try Presentation()
            deck.documentProperties.title = "Same every time"
            deck.documentProperties.modified = stamp
            deck.documentProperties.setCustomValue(.number(1), for: "Build")
            return try deck.serializedData()
        }
        #expect(try build() == build())

        // Reading metadata must not dirty the package.
        let original = try build()
        let reopened = try Presentation(data: original)
        let properties = reopened.documentProperties
        _ = (properties.title, properties.author, properties.created, properties.modified,
             properties.company, properties.custom)
        #expect(try reopened.serializedData() == original)
    }
}
