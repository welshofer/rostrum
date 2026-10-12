import Foundation
import Rostrum
import RostrumLayout

/// A complete POTX -> plan -> compose -> save/reopen example. Its independently
/// saved input makes template preservation reviewable alongside the output.
enum TemplateFittingRecipe {
    static func append(to draft: LibraryLabDraft) throws -> LibraryLabDraft {
        var result = draft
        let source = try Presentation()
        source.slideSize = draft.deck.slideSize
        source.theme.majorFont = "DejaVu Sans"; source.theme.minorFont = "DejaVu Sans"
        let font = try PlatformLabRecipes.resource("DejaVuSans", "ttf")
        try source.embedFont("DejaVu Sans", faces: .init(regular: font))
        let layout = try PlatformLabRecipes.require(source.layout(type: "obj"), "Template layout missing")
        let tree = try PlatformLabRecipes.require(layout.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree"), "Template shapes missing")
        for node in tree.children(named: "p:sp") {
            guard let ph = node.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph") else { continue }
            let index = Int(ph[attribute: "idx"] ?? "0") ?? 0
            guard index == 0 || index == 1 else { continue }
            let x = 50.0, y = index == 0 ? 35.0 : 145.0
            let width = source.bounds.width.points - 100, height = index == 0 ? 65.0 : 155.0
            let transform = XML.Element("a:xfrm", children: [
                .element(XML.Element("a:off", attributes: [("x", String(EMU.points(x).rawValue)), ("y", String(EMU.points(y).rawValue))])),
                .element(XML.Element("a:ext", attributes: [("cx", String(EMU.points(width).rawValue)), ("cy", String(EMU.points(height).rawValue))]))])
            let properties = try PlatformLabRecipes.require(node.firstChild(named: "p:spPr"), "Template shape properties missing")
            properties.children.removeAll { if case .element(let e) = $0 { return e.name == "a:xfrm" }; return false }
            properties.children.insert(.element(transform), at: 0)
            let text = try XML.parse(Data("""
            <p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0" vertOverflow="clip"><a:normAutofit lnSpcReduction="10000"/></a:bodyPr><a:lstStyle>
            <a:lvl1pPr marL="0" marR="0" indent="0" algn="l"><a:lnSpc><a:spcPct val="110000"/></a:lnSpc><a:spcBef><a:spcPts val="0"/></a:spcBef><a:spcAft><a:spcPts val="800"/></a:spcAft><a:buNone/><a:tabLst><a:tab pos="2540000" algn="r"/></a:tabLst><a:defRPr sz="\(index == 0 ? 3000 : 2800)" b="0" i="0" kern="0" spc="0"><a:solidFill><a:srgbClr val="172B2A"/></a:solidFill><a:latin typeface="DejaVu Sans"/></a:defRPr></a:lvl1pPr>
            <a:lvl2pPr marL="304800" marR="0" indent="-152400" algn="l"><a:lnSpc><a:spcPct val="110000"/></a:lnSpc><a:spcBef><a:spcPts val="0"/></a:spcBef><a:spcAft><a:spcPts val="0"/></a:spcAft><a:buFont typeface="DejaVu Sans"/><a:buChar char="•"/><a:defRPr sz="2400" b="0" i="0" kern="0" spc="0"><a:solidFill><a:srgbClr val="172B2A"/></a:solidFill><a:latin typeface="DejaVu Sans"/></a:defRPr></a:lvl2pPr>
            </a:lstStyle><a:p/></p:txBody>
            """.utf8))
            node.children.removeAll { if case .element(let e) = $0 { return e.name == "p:txBody" }; return false }
            node.appendElement(text)
        }
        layout.part.markDirty()
        source.documentKind = .template
        let input = try source.serializedData()
        let deck = try Presentation.fromTemplate(data: input)
        _ = deck.registerEmbeddedFonts()
        let preserved = Dictionary(uniqueKeysWithValues: deck.package.parts.values.filter {
            $0.uri.value.hasPrefix("/ppt/slideLayouts/") || $0.uri.value.hasPrefix("/ppt/slideMasters/") || $0.uri.value.hasPrefix("/ppt/theme/")
        }.map { ($0.uri, $0.blob) })
        let selected = try PlatformLabRecipes.require(deck.layout(type: "obj"), "Reopened template layout missing")
        let engine = TemplateLayoutEngine(presentation: deck)
        let paragraphs = [LayoutParagraph("Text in inherited template slots"), LayoutParagraph("Alpha\t12.5\nBeta\t38.0\nGamma\t7.25"), LayoutParagraph("Indented line retained", level: 1)]
        let plan = try engine.plan(title: "Template text: planned and saved", columns: [paragraphs], preferredTypes: ["obj"], layoutURI: selected.part.uri.value)
        let slide = try engine.compose(plan, title: "Template text: planned and saved", columns: [paragraphs])
        let expected = try geometry(slide: slide, deck: deck, slot: 1)
        let note = try PlatformLabRecipes.text("The template supplies fonts, tab stops, bullets and spacing. Planning checks the same text that the saved slide renders.\nThis computed example has not been visually accepted in PowerPoint.", on: slide,
            in: Rect(x: .points(50), y: .points(360), width: .points(deck.bounds.width.points - 100), height: .points(100)))
        note.textFrame?.paragraphs.first?.runs.first?.fontName = "DejaVu Sans"
        note.textFrame?.paragraphs.first?.runs.first?.fontSize = 18
        let output = try deck.serializedData()
        let unchanged = preserved.allSatisfy { deck.package.parts[$0.key]?.blob == $0.value }
        let page = draft.deck.slides.count
        try draft.deck.fonts.register(font)
        try draft.deck.embedFont("DejaVu Sans", faces: .init(regular: font))
        try draft.deck.slides.importAll(from: deck)
        result.extraFiles["fitting-template.potx"] = input
        result.extraFiles["planned-template-output.pptx"] = output
        result.checks += [
            .init("Template fitting preserves source parts", unchanged, "All master, layout and theme payloads remain byte-identical after planning, composition and serialization."),
            .init("Template fit uses complete text geometry", expected.fits && (plan.textFits[1]?.fontScale ?? 1) < 1, "Inherited tabs, bullets and paragraph levels fit after a computed normal-autofit scale.")
        ]
        let originalVerify = draft.verify
        result.verify = { reopened in
            var checks = try originalVerify(reopened)
            _ = reopened.registerEmbeddedFonts()
            let saved = try reopened.slides[page]
            let actual = try geometry(slide: saved, deck: reopened, slot: 1)
            let shape = try PlatformLabRecipes.require(saved.placeholder(idx: 1), "Saved template text missing")
            checks += [
                .init("Template geometry survives reopening", actual.fits && actual.lines == expected.lines, "The imported, saved slide reproduces the measured lines, positions, sizes and styles with its embedded face."),
                .init("Template content and inheritance retained", shape.textFrame?.paragraphs.map(\.plainText) == paragraphs.map(\.text)
                    && shape.textFrame?.paragraphs.allSatisfy { $0.runs.allSatisfy { $0.fontSize == nil } } == true,
                    "All words, tabs and breaks remain editable; font sizes stay inherited from the template.")
            ]
            return checks
        }
        return result
    }

    private static func geometry(slide: Slide, deck: Presentation, slot: Int) throws -> RichTextLayout {
        let layout = try PlatformLabRecipes.require(slide.layout, "Saved template binding missing")
        let shape = try PlatformLabRecipes.require(slide.placeholder(idx: slot), "Template placeholder missing")
        let frame = try PlatformLabRecipes.require(slide.effectiveFrame(of: shape), "Template frame missing")
        let node = try slide.part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.children(named: "p:sp").first {
            $0.firstChild(named: "p:nvSpPr")?.firstChild(named: "p:nvPr")?.firstChild(named: "p:ph")?[attribute: "idx"] == String(slot)
        }
        let text = try PlatformLabRecipes.require(node?.firstChild(named: "p:txBody"), "Template text body missing")
        let list = XML.Element("a:lstStyle")
        // This controlled fixture declares all geometry at levels 0 and 1.
        for level in 0...1 {
            let defaults = layout.textDefaults(for: slot, level: level).paragraph
            list.appendElement(XML.Element("a:lvl\(level + 1)pPr", attributes: defaults.attributes, children: defaults.children))
        }
        return RichTextLayout(textBody: text, width: frame.width.points, height: frame.height.points,
            fonts: deck.fonts, theme: slide.master?.theme,
            inheritedStyles: [layout.textDefaults(for: slot).body, list], maxLines: 64)
    }
}
