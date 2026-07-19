import Foundation
import Testing
@testable import Rostrum

@Suite struct POTXTests {
    /// Build a synthetic `.potx` by retyping a normal deck's main part to the
    /// template content type — structurally what PowerPoint writes for a
    /// template.
    private func templateBytes(_ mainType: String) throws -> Data {
        let base = try Presentation()
        base.package.contentTypes.setOverride(
            partName: PackURI("/ppt/presentation.xml"), contentType: mainType)
        return try base.serializedData()
    }

    @Test func opensTemplateAndNormalizesToPresentation() throws {
        let potx = try templateBytes(ContentType.presentationTemplateMain)
        let deck = try Presentation(data: potx)
        // Normalized in place: the main part is now a plain presentation.
        #expect(deck.presentationPart.contentType == ContentType.presentationMain)

        // The template's layouts are usable to build slides.
        let slide = try deck.slides.add(layout: deck.layout(type: "title")!)
        slide.title?.textFrame?.text = "Built from a template"

        // Saving emits a .pptx: presentation content type, no template type.
        let out = try deck.serializedData()
        let ct = String(decoding: try ZipReader(data: out).data(forEntry: "[Content_Types].xml"),
                        as: UTF8.self)
        #expect(ct.contains("presentation.main+xml"))
        #expect(!ct.contains("template.main+xml"))

        // And PowerPoint/python-pptx would see an ordinary presentation.
        let reopened = try Presentation(data: out)
        #expect(reopened.presentationPart.contentType == ContentType.presentationMain)
        #expect(reopened.slides.contains { $0.title?.textFrame?.text == "Built from a template" })
    }

    @Test func opensSlideShowToo() throws {
        let ppsx = try templateBytes(ContentType.slideShowMain)
        let deck = try Presentation(data: ppsx)
        #expect(deck.presentationPart.contentType == ContentType.presentationMain)
    }

    @Test func rejectsGenuinelyNonPresentationMainPart() throws {
        let bogus = try templateBytes(ContentType.theme)   // not a presentation at all
        #expect(throws: RostrumError.self) {
            try Presentation(data: bogus)
        }
    }
}
