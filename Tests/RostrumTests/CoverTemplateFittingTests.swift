import Foundation
import Testing
@testable import Rostrum

@Suite struct CoverTemplateFittingTests {
    @Test(arguments: [10.0, 13.333333], [false, true])
    func coverFitsItsActualFaceAndHeightAfterTemplateReopen(width: Double, italic: Bool) throws {
        let source = try Presentation()
        source.documentKind = .template
        source.slideSize = (.inches(width), .inches(7.5))
        source.theme.majorFont = "Template Face"
        let layout = try #require(source.layout(type: "title"))
        // Real templates can contribute both italic formatting and list
        // defaults after the builder gives its text a placeholder identity.
        let shapes = try layout.part.dom().firstChild(named: "p:cSld")?
            .firstChild(named: "p:spTree")?.children(named: "p:sp") ?? []
        for shape in shapes {
            let list = try #require(shape.firstChild(named: "p:txBody")?.firstChild(named: "a:lstStyle"))
            let level = list.getOrAddChild("a:lvl1pPr")
            level.appendElement(XML.Element("a:buChar", attributes: [("char", "•")]))
            level.appendElement(XML.Element("a:defRPr", attributes: [("i", italic ? "1" : "0")]))
        }
        layout.part.markDirty()
        let deck = try Presentation(data: source.serializedData())
        try registerFaces(in: deck)
        let slide = try deck.titleSlide("A new presentation", subtitle: "Template branding is retained")
        let cover = try #require(slide.title)
        let titleBody = try #require(cover.textFrame?.txBody)
        let inherited = RichTextLayout.inheritedStyles(for: cover.element, owner: slide.part, package: deck.package)
        let unfitted = RichTextLayout(textBody: titleBody, width: cover.frame.width.points,
            height: cover.frame.height.points, fonts: deck.fonts, theme: deck.theme,
            inheritedStyles: inherited, fontScale: 100, lineSpacingReduction: 0)
        #expect(!unfitted.fits, "The original 96 pt title must reproduce the native overflow")

        let bytes = try deck.serializedData()
        let reopened = try Presentation(data: bytes)
        try registerFaces(in: reopened)
        let reopenedSlide = try reopened.slides[reopened.slides.count - 1]
        let title = try #require(reopenedSlide.title)
        let fitted = try measurement(of: title, in: reopenedSlide, deck: reopened)
        #expect(fitted.fits && !fitted.truncated)
        #expect(fitted.contentHeight <= title.frame.height.points + 0.01)
        #expect(fitted.lines.flatMap(\.spans).allSatisfy { $0.run.bold && $0.run.italic == italic })
        let scale = title.textFrame?.txBody.firstChild(named: "a:bodyPr")?
            .firstChild(named: "a:normAutofit")?[attribute: "fontScale"].flatMap(Int.init)
        #expect(scale != nil && scale! < 100_000)
        #expect(title.textFrame?.paragraphs.first?.runs.first?.fontSize == 96)
        #expect(try reopened.validate().isEmpty)

        for shape in reopenedSlide.placeholders {
            let paragraph = try #require(shape.textFrame?.txBody.firstChild(named: "a:p"))
            #expect(paragraph.firstChild(named: "a:pPr")?.firstChild(named: "a:buNone") != nil)
            let layout = try measurement(of: shape, in: reopenedSlide, deck: reopened)
            #expect(layout.fits && !layout.truncated)
            #expect(!layout.lines.flatMap(\.spans).contains { $0.run.text.contains("•") })
        }
        #expect(try reopened.serializedData() == bytes)
    }

    @Test(arguments: [false, true])
    func coverNeverEnlargesASmallConfiguredDisplayRole(registered: Bool) throws {
        let deck = try Presentation()
        deck.slideSize = (.inches(10), .inches(7.5))
        deck.theme.majorFont = "Template Face"
        if registered { try registerFaces(in: deck) }
        let style = deck.style.with(.display) { $0.sizePt = 22 }
        let slide = try deck.titleSlide("A deliberately long title that previously selected a sixty point fallback", style: style)
        let title = try #require(slide.title)
        let run = try #require(title.textFrame?.paragraphs.first?.runs.first)
        #expect(run.fontSize == 22)
        let layout = try measurement(of: title, in: slide, deck: deck)
        #expect(layout.fits && !layout.truncated)
        #expect(layout.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize <= 22 })
    }

    private func registerFaces(in deck: Presentation) throws {
        for (bold, italic, width) in [(false, false, 150), (true, false, 900), (true, true, 1100)] {
            try deck.fonts.register(FontFaceTests.font(width, bold: bold, italic: italic), aliases: ["Template Face"])
        }
    }

    private func measurement(of shape: Shape, in slide: Slide, deck: Presentation) throws -> RichTextLayout {
        RichTextLayout(textBody: try #require(shape.textFrame?.txBody),
            width: shape.frame.width.points, height: shape.frame.height.points,
            fonts: deck.fonts, theme: deck.theme,
            inheritedStyles: RichTextLayout.inheritedStyles(for: shape.element, owner: slide.part, package: deck.package))
    }
}
