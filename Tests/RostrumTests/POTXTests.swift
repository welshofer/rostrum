import Foundation
import Testing
@testable import Rostrum

@Suite struct POTXTests {
    /// Build a synthetic document by retyping a normal deck's main part —
    /// structurally what PowerPoint writes for a template or a show.
    private func documentBytes(_ mainType: String) throws -> Data {
        let base = try Presentation()
        base.package.contentTypes.setOverride(
            partName: PackURI("/ppt/presentation.xml"), contentType: mainType)
        return try base.serializedData()
    }

    /// What the saved package says its main part is.
    private func mainKind(in data: Data) throws -> DocumentKind? {
        let types = String(
            decoding: try ZipReader(data: data).data(forEntry: "[Content_Types].xml"),
            as: UTF8.self)
        for kind in [DocumentKind.template, .slideShow, .presentation]
        where types.contains(kind.mainContentType) {
            return kind
        }
        return nil
    }

    // MARK: - A template opens, and stays, a template

    @Test func openingATemplateKeepsItATemplate() throws {
        let deck = try Presentation(data: try documentBytes(ContentType.presentationTemplateMain))
        #expect(deck.documentKind == .template)
        #expect(deck.presentationPart.contentType == ContentType.presentationTemplateMain)
    }

    /// The regression the real-deck corpus caught: opening a `.potx` and saving
    /// it with no edits used to hand back a `.pptx`. A round trip must not
    /// change what the document is.
    @Test func aTemplateSurvivesARoundTripAsATemplate() throws {
        let original = try documentBytes(ContentType.presentationTemplateMain)
        let resaved = try Presentation(data: original).serializedData()
        #expect(try mainKind(in: resaved) == .template)

        // Not merely "still a template" — byte-identical. Retyping the main
        // part rebuilds [Content_Types].xml and reorders every Override along
        // the way, which is a loss even when the type comes out right.
        let before = try ZipReader(data: original)
        let after = try ZipReader(data: resaved)
        #expect(
            try after.data(forEntry: "[Content_Types].xml")
                == before.data(forEntry: "[Content_Types].xml"))
    }

    @Test func aSlideShowSurvivesARoundTripAsASlideShow() throws {
        let resaved = try Presentation(data: try documentBytes(ContentType.slideShowMain))
            .serializedData()
        #expect(try mainKind(in: resaved) == .slideShow)
    }

    // MARK: - Conversion is available, just no longer automatic

    @Test func documentKindConvertsATemplateIntoAPresentation() throws {
        let deck = try Presentation(data: try documentBytes(ContentType.presentationTemplateMain))
        deck.documentKind = .presentation

        let out = try deck.serializedData()
        #expect(try mainKind(in: out) == .presentation)
        #expect(try Presentation(data: out).documentKind == .presentation)
    }

    /// A template is fully usable *as* a template — which is why converting is
    /// a choice rather than a precondition.
    @Test func aTemplatesLayoutsBuildSlidesWithoutConverting() throws {
        let deck = try Presentation(data: try documentBytes(ContentType.presentationTemplateMain))
        let slide = try deck.slides.add(layout: deck.layout(type: "title")!)
        slide.title?.textFrame?.text = "Built from a template"

        let reopened = try Presentation(data: try deck.serializedData())
        #expect(reopened.documentKind == .template)
        #expect(reopened.slides.contains { $0.title?.textFrame?.text == "Built from a template" })
    }

    // MARK: - The kind mapping itself

    @Test func documentKindRoundTripsThroughItsContentType() {
        for kind in [DocumentKind.presentation, .template, .slideShow] {
            #expect(DocumentKind(mainContentType: kind.mainContentType) == kind)
        }
        #expect(DocumentKind(mainContentType: ContentType.theme) == nil)
    }

    @Test func rejectsGenuinelyNonPresentationMainPart() throws {
        // Not a presentation, a template or a show — no DocumentKind at all.
        let bogus = try documentBytes(ContentType.theme)
        #expect(throws: RostrumError.self) {
            try Presentation(data: bogus)
        }
    }
}
