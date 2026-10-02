import Foundation
import Rostrum

extension PlatformLabRecipes {
    static func layouts(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Layouts")
        let imported = try Presentation()
        imported.theme.majorFont = "Georgia"
        _ = try deck.slides.importAll(from: imported)
        try deck.slides.remove(at: deck.slides.count - 1)
        let main = try deck.package.mainDocumentPart()
        let masters = try require(try main.dom().firstChild(named: "p:sldMasterIdLst"), "Master order missing")
        // Keep relationship order unchanged while making the imported master
        // first in the presentation's ordered list. Public theme/layout access
        // and both slide creation paths must follow that same list.
        masters.children.reverse()
        main.markDirty()
        let selected = try require(deck.layout(type: options.alternative ? "obj" : "title"), "Bundled template layout missing")
        let before = try deck.serializedData()
        let cloned = try deck.slides.add(clonedFrom: selected)
        let bound = try options.alternative
            ? deck.bulletSlide("Bound canvas: " + label(options), ["Builder-authored content"])
            : deck.titleSlide("Bound canvas: " + label(options))
        let builderHasOnlyAuthoredTitle = bound.placeholders.count == 1
        let title = try require(cloned.title, "Cloned title missing")
        title.textFrame?.text = label(options)
        let inherited = cloned.effectiveFrame(of: title)
        let explicit = try require(bound.title, "Builder title missing")
        explicit.markAsPlaceholder(type: options.alternative ? "title" : "ctrTitle")
        let kind = selected.type, name = selected.name
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Cloned versus bound", cloned.placeholders.count > bound.placeholders.count && builderHasOnlyAuthoredTitle, "The clone copies layout placeholders; the public slide builder binds the layout and authors only its own title placeholder."),
            .init("Layout lookup and master", deck.layout(named: name)?.part.uri == selected.part.uri && selected.master != nil, "\(name); \(deck.slideMasters.count) master(s), \(deck.allLayouts.count) layouts."),
            .init("Inherited placeholder geometry", inherited != nil, "A clone has an effective frame supplied by its layout."),
            .init("Ordered master selection", deck.theme.majorFont == "Georgia" && selected.master?.part.uri == deck.slideMasters.first?.part.uri, "Theme and layout selection follow the first declared master, independently of relationship stream order.")
        ], verify: { reopened in
            let clone = try reopened.slides[1], bound = try reopened.slides[2]
            return [
                .init("Layout bindings reopened", clone.layout?.type == kind && bound.layout?.type == kind, "Both slides retain their selected layout relationship."),
                .init("Placeholder content reopened", clone.title?.textFrame?.text == label(options) && bound.title?.textFrame?.text == "Bound canvas: " + label(options), "Cloned and explicitly marked titles remain discoverable."),
                .init("Inherited geometry reopened", clone.title.flatMap { clone.effectiveFrame(of: $0) } == inherited, "The layout-provided frame survives serialization."),
                .init("Master hierarchy reopened", !reopened.slideMasters.isEmpty && reopened.slideMasters.allSatisfy { !$0.layouts.isEmpty && $0.theme != nil }, "All declared masters expose layouts and a theme."),
                .init("Ordered master selection reopened", reopened.theme.majorFont == "Georgia" && clone.master?.part.uri == reopened.slideMasters.first?.part.uri && bound.master?.part.uri == reopened.slideMasters.first?.part.uri, "Both generated slides and the deck theme use the first declared master.")
            ]
        })
    }

    static func fonts(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Fonts and fitting"), font = try resource("DejaVuSans", "ttf")
        let before = try deck.serializedData()
        try deck.fonts.register(font)
        let metrics = try require(deck.fonts.metrics(for: "DejaVu Sans", bold: false, italic: false), "Regular face missing")
        let measurer = TextMeasurer(metrics)
        let shaped = TextShaper(metrics).shape("AV office x́", pointSize: 24)
        let wrapped = measurer.wrap(label(options) + " measured text", pointSize: 24, width: 140)
        let body = Array(repeating: label(options), count: options.sampleSize).joined(separator: " ")
        let frame = LibraryLabSupport.frame(0.7, 1.4, options.alternative ? 4 : 10, 3.8)
        let box = try text(body, on: deck.slides[0], in: frame)
        let fit = try require(box.textFrame, "Text frame missing").fitText(in: frame, fonts: deck.fonts, theme: deck.theme, defaultPointSize: 24)
        try deck.embedFont("DejaVu Sans", faces: .init(regular: font))
        let fitScale = fit.fontScale
        let note = "Font: DejaVu Sans regular. Fit scale: \(fitScale)%; \(wrapped.count) measured line(s)."
        try text(note, on: deck.slides[0], in: LibraryLabSupport.frame(0.7, 0.4, 11, 0.8))
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Registered metrics and shaping", measurer.width(of: "AV", pointSize: 24) > 0 && shaped.isSupported && shaped.glyphs.count < "AV office x́".unicodeScalars.count, "Kerning, ligatures and an attached residual mark use real font metrics."),
            .init("Measured wrapping", !wrapped.isEmpty && wrapped.joined().filter { !$0.isWhitespace } == (label(options) + " measured text").filter { !$0.isWhitespace }, "\(wrapped.count) lines in 140 points; wrapping preserves every non-whitespace character, including across explicit newlines."),
            .init("Autofit calculated", fitScale >= 25 && fitScale <= 100, "Scale \(fitScale)%; fits at this ladder step: \(fit.fits)."),
            .init("Exact face availability", deck.fonts.metrics(for: "DejaVu Sans", bold: true, italic: false) == nil && deck.fonts.metrics(for: "DejaVu Sans", bold: false, italic: true) == nil, "Bold and italic are unavailable in the bundled fixture and are not misregistered.")
        ], verify: { reopened in
            let registered = reopened.registerEmbeddedFonts()
            let recovered = reopened.fonts.data(for: .init(family: "DejaVu Sans"))
            let body = try require(reopened.slides[0].shapes.all.first?.textFrame, "Reopened fitted frame missing")
            let norm = try reopened.slides[0].part.dom().firstChild(named: "p:cSld")?.firstChild(named: "p:spTree")?.firstChild(named: "p:sp")?.firstChild(named: "p:txBody")?.firstChild(named: "a:bodyPr")?.firstChild(named: "a:normAutofit")
            let persistedScale = Double(norm?[attribute: "fontScale"] ?? "100000").map { $0 / 1000 }
            return [
                .init("Embedded face bytes reopened", registered == ["DejaVu Sans"] && recovered == font, "EOT-wrapped regular font recovered byte-for-byte."),
                .init("Autofit persisted", norm != nil && persistedScale == fitScale && !body.text.isEmpty, "The serialized normAutofit matches the chosen scale."),
                .init("Reopened shaping", reopened.fonts.metrics(for: "DejaVu Sans").map { TextShaper($0).shape("AV office x́", pointSize: 24) == shaped } == true, "Registered embedded font reproduces glyph positions.")
            ]
        })
    }

    static func theme(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Theme"), accent = Color(options.accentHex)
        let before = try deck.serializedData()
        deck.theme.setColor(.dk1, options.alternative ? Color("18243A") : .black)
        deck.theme.setAccent(1, accent)
        deck.theme.majorFont = "DejaVu Sans"; deck.theme.minorFont = "DejaVu Sans"
        try text(label(options), on: deck.slides[0])
        let transforms: [ColorTransform] = options.alternative ? [.tint(0.35)] : []
        let expected = deck.theme.resolve(.accent1, transforms: transforms)
        for (i, cell) in LibraryLabSupport.frame(0.7, 2, 11, 3).columns(options.sampleSize, gutter: .inches(0.1)).enumerated() {
            let shape = try deck.slides[0].shapes.addShape(.rectangle, frame: cell, fill: .themeColor(.accent1, transforms))
            shape.name = "Scheme swatch \(i + 1)"
        }
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Scheme resolution", expected != nil && deck.theme.accent(1) == accent, "\(options.sampleSize) theme-linked swatches; resolved \(expected?.hex ?? "missing").")
        ], verify: { reopened in
            let shapes = try reopened.slides[0].shapes.all
            let xml = String(decoding: XML.document(try reopened.slides[0].part.dom()), as: UTF8.self)
            let svg = try reopened.renderSVG(slideAt: 0)
            return [
                .init("Palette and fonts reopened", reopened.theme.accent(1) == accent && reopened.theme.majorFont == "DejaVu Sans" && reopened.theme.minorFont == "DejaVu Sans", "Theme font families and accent survived."),
                .init("Scheme links preserved", xml.components(separatedBy: "<a:schemeClr val=\"accent1\"").count - 1 == options.sampleSize && shapes.count == options.sampleSize + 1, "Swatches still reference the theme rather than materialized RGB."),
                .init("Theme-linked rendering", expected.map { svg.contains($0.hex) } == true, "SVG resolves the current palette and tint.")
            ]
        })
    }

    static func templates(_ options: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: label(options)), before = try deck.serializedData()
        let size = options.alternative ? Rect.slide4x3 : Rect.slide16x9
        deck.slideSize = (size.width, size.height)
        let properties = deck.documentProperties
        properties.subject = "Offline Library Lab"; properties.comments = "Typed metadata demonstration"
        properties.company = "Lectern"; properties.manager = "Library Lab"
        properties.application = "Rostrum"; properties.revision = options.sampleSize
        properties.setCustomValue(.text(label(options)), for: "Lab text")
        properties.setCustomValue(.number(options.sampleSize), for: "Sample size")
        properties.setCustomValue(.decimal(1.25), for: "Ratio")
        properties.setCustomValue(.boolean(options.alternative), for: "Alternative")
        properties.setCustomValue(.date(Date(timeIntervalSince1970: 0)), for: "Epoch")
        properties.setCustomValue(.text("temporary"), for: "Removed")
        properties.setCustomValue(nil, for: "Removed")
        try text(label(options), on: deck.slides[0], in: deck.safeArea().inset(by: .inches(0.2)))
        deck.documentKind = .template
        let template = try deck.serializedData()
        deck.documentKind = .slideShow
        let slideshow = try deck.serializedData()
        deck.documentKind = .presentation
        return LibraryLabDraft(deck: deck, before: before, checks: [
            .init("Real document kinds", try Presentation(data: template).documentKind == .template && Presentation(data: slideshow).documentKind == .slideShow, "POTX/PPSX main content types are independently reopened.")
        ], extraFiles: ["template.potx": template, "slideshow.ppsx": slideshow], verify: { reopened in
            let p = reopened.documentProperties
            return [
                .init("Core and extended properties", p.title == label(options) && p.company == "Lectern" && p.revision == options.sampleSize && p.application == "Rostrum", "Title, revision, company and application read back."),
                .init("Typed custom properties", p.customValue("Lab text") == .text(label(options)) && p.customValue("Sample size") == .number(options.sampleSize) && p.customValue("Ratio") == .decimal(1.25) && p.customValue("Alternative") == .boolean(options.alternative) && p.customValue("Epoch") == .date(Date(timeIntervalSince1970: 0)) && p.customValue("Removed") == nil, "Text, integer, decimal, boolean, date and deletion verified."),
                .init("Canvas and final kind", reopened.slideSize.width == size.width && reopened.slideSize.height == size.height && reopened.documentKind == .presentation, "Final editable deck retains the selected canvas.")
            ]
        })
    }
}
