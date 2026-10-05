import Foundation
import Rostrum

/// Public table fitting reads live cell properties, even through a retained frame.
/// The stored 50% scale is preserved but does not shrink native cell text.
enum TableContextRecipe {
    static let sample = "BBBBBBBBBBBBZ Agjp BBBBBBBBBBBBZ"
    static let ignoredScale = ShapingDiagnostic.unsupportedLayoutFeature("Native table cells ignore stored fontScale; rendering at full size")
    static let unverifiedReduction = ShapingDiagnostic.unsupportedLayoutFeature("Native table line-spacing reduction is not verified")

    static func append(to deck: Presentation, alternative: Bool, accent: Color) throws -> (checks: [LibraryLabCheck], verify: (Presentation) throws -> [LibraryLabCheck]) {
        let font = try PlatformLabRecipes.resource("DejaVuSans", "ttf")
        try deck.fonts.register(font)
        try deck.embedFont("DejaVu Sans", faces: .init(regular: font))
        let slide = try deck.slides.add()
        try PlatformLabRecipes.text("Table cells measure full-size text", on: slide)
        let table = try slide.shapes.addTable(rows: 1, columns: 1,
            frame: LibraryLabSupport.frame(0.8, 1.8, 6, 2.3))
        table.clearBuiltInStyle()
        let cell = try table.cell(0, 0)
        cell.setText(sample, style: style(size: 18, color: accent), align: .left)
        cell.setPadding(left: .points(210), top: .zero, right: .points(210), bottom: .zero)
        let retained = cell.textFrame
        retained.wordWrap = true
        retained.setAutoFit(fontScale: 0.5)
        let initialBytes = try deck.serializedData()
        let beforeEdits = retained.fitText(in: try frame(deck), fonts: deck.fonts, theme: deck.theme)
        let initialUnchanged = try initialBytes == deck.serializedData()
        // Mutate the cell after retaining its TextFrame. Fitting must resolve
        // these current properties rather than the handle's earlier state.
        cell.setPadding(left: .points(alternative ? 32 : 18), top: .points(12), right: .points(14), bottom: .points(10))
        cell.applyTextStyle(style(size: 20, color: accent), align: .left)
        cell.verticalAnchor = .middle
        cell.setBorders(Line(color: accent))
        let bytes = try deck.serializedData()
        let selected = retained.fitText(in: try frame(deck), fonts: deck.fonts, theme: deck.theme)
        let unchanged = try bytes == deck.serializedData()
        let layout = try geometry(deck, context: .tableCell)
        let shape = try geometry(deck, context: .shape)
        let explanation = "Stored scale: 50%. Native cell text: 20 pt.\n\nCell fit: \(selected.fontScale)% scale, \(selected.lineSpacingReduction)% line reduction, fits: \(selected.fits).\n\nThe retained text frame reads the updated padding and style. Fitting leaves the stored body unchanged."
        let note = try PlatformLabRecipes.text(explanation, on: slide, in: LibraryLabSupport.frame(7.3, 1.6, 5.2, 3.7))
        note.textFrame?.paragraphs.forEach { $0.runs.forEach { $0.fontSize = 18 } }
        let footer = try PlatformLabRecipes.text("Explicit .tableCell layout matches the rendered cell. .shape honors the same stored 50% scale.\nStored table scale is diagnosed and ignored; nonzero stored line reduction is unverified and cell fitting refuses it. No native autofit selection is claimed.", on: slide, in: LibraryLabSupport.frame(0.8, 5.25, 11.8, 1.35))
        footer.textFrame?.paragraphs.forEach { $0.runs.forEach { $0.fontSize = 16 } }
        let svg = try deck.renderSVG(slideAt: 2)
        // XML parsing orders attributes canonically; compare exact parsed
        // trees so authoring insertion order is not mistaken for lost state.
        let bodyXML = try XML.parse(Data(body(deck).serialized().utf8)).serialized()
        let propertiesXML = try XML.parse(Data(properties(deck).serialized().utf8)).serialized()
        let checks: [LibraryLabCheck] = [
            .init("Cell context retains full-size text", layout.fits && layout.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 20 } && shape.lines.flatMap(\.spans).allSatisfy { $0.run.fontSize == 10 } && layout.diagnostics == [ignoredScale], "The identical body has native table semantics at 20 pt and shape semantics at its stored 50% scale; the table warning remains visible."),
            .init("Retained cell fitting uses live properties without mutation", !beforeEdits.fits && beforeEdits.fontScale == 100 && beforeEdits.lineSpacingReduction == 0 && selected.fontScale == 100 && selected.lineSpacingReduction == 0 && selected.fits == layout.fits && initialUnchanged && unchanged, "The retained frame first rejects a 12 pt content width, then accepts the updated padding, style and middle anchor at full size; both calls preserve package bytes."),
            .init("Explicit table context agrees with actual SVG", try matchesSVG(deck, svg: svg, layout: layout), "Actual table-rendered text matches the explicit context's lines, first scalar origins and baselines, with 20 pt paint and no glyph stretching.")
        ]
        return (checks, { reopened in
            let recovered = reopened.registerEmbeddedFonts()
            let current = try geometry(reopened, context: .tableCell)
            let saved = try reopened.serializedData()
            let cell = try self.cell(reopened)
            let fit = cell.textFrame.fitText(in: try frame(reopened), fonts: reopened.fonts, theme: reopened.theme)
            return [
                .init("Saved table context and live fit persist", try recovered.contains("DejaVu Sans") && current.lines == layout.lines && current.diagnostics == layout.diagnostics && fit == selected && (try body(reopened).serialized()) == bodyXML && (try properties(reopened).serialized()) == propertiesXML && (try reopened.serializedData()) == saved, "The exact text body, scale, padding, run style, geometry and read-only fit survive saved-file reopening."),
                .init("Saved cell SVG remains deterministic", try reopened.renderSVG(slideAt: 2) == svg && matchesSVG(reopened, svg: svg, layout: current), "The reopened actual table renderer agrees with the public context and original SVG bytes.")
            ]
        })
    }

    static func style(size: Double, color: Color) -> TextStyle {
        .init(font: "DejaVu Sans", sizePt: size, weight: 400, trackingPt: 0, lineHeight: 1, color: color)
    }
    static func cell(_ deck: Presentation) throws -> TableCell {
        let table = try PlatformLabRecipes.require(deck.slides[2].shapes.all.compactMap { ($0 as? TableFrame)?.table }.first, "Context table missing")
        return try table.cell(0, 0)
    }
    static func frame(_ deck: Presentation) throws -> Rect {
        try PlatformLabRecipes.require(deck.slides[2].shapes.all.compactMap { $0 as? TableFrame }.first, "Context table frame missing").frame
    }
    static func body(_ deck: Presentation) throws -> XML.Element {
        try PlatformLabRecipes.require(DrawingLabFixtures.nodes(deck.slides[2].part.dom(), "a:txBody").first, "Context table body missing")
    }
    static func properties(_ deck: Presentation) throws -> XML.Element {
        try PlatformLabRecipes.require(DrawingLabFixtures.nodes(deck.slides[2].part.dom(), "a:tcPr").first, "Context cell properties missing")
    }
    static func geometry(_ deck: Presentation, context: RichTextLayout.Context) throws -> RichTextLayout {
        let properties = try properties(deck)
        func margin(_ name: String) -> Double { (properties[attribute: name].flatMap(Double.init) ?? 0) / Double(EMU.perPoint) }
        let box = try frame(deck)
        return try RichTextLayout(textBody: body(deck), width: box.width.points, height: box.height.points,
            fonts: deck.fonts, theme: deck.theme,
            insets: (margin("marL"), margin("marT"), margin("marR"), margin("marB")),
            verticalAnchor: properties[attribute: "anchor"], context: context)
    }
    static func matchesSVG(_ deck: Presentation, svg: String, layout: RichTextLayout) throws -> Bool {
        guard let glyphs = PlatformLabRecipes.paintGlyphs(svg: svg, frame: try frame(deck)), !glyphs.isEmpty else { return false }
        var offset = 0
        for line in layout.lines {
            for span in line.spans {
                let text = span.run.text.filter { !$0.isWhitespace }
                guard !text.isEmpty else { continue }
                let count = text.unicodeScalars.count
                guard offset + count <= glyphs.count else { return false }
                let actual = Array(glyphs[offset..<(offset + count)])
                guard actual.map(\.text).joined() == text,
                      abs(actual[0].x - span.x) < 0.001,
                      actual.allSatisfy({ abs($0.baseline - line.baseline) < 0.001 && $0.size == 20 }) else { return false }
                offset += count
            }
        }
        return offset == glyphs.count
    }
}
