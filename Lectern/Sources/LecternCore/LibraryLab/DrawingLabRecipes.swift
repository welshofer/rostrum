import Foundation
import Rostrum

/// Small, deterministic documents that exercise the public drawing APIs.
/// XML is read only for properties without a typed read-back API.
enum DrawingLabRecipes {
    static let catalog: [LibraryLabRecipe] = [
        .init(.shapes, title: "178 shape presets", summary: "A labeled gallery with editable frames, rotation and rounded corners.",
              operations: ["ShapeGeometry.allCases", "ShapeCollection.addShape", "ShapeCollection.addRoundedRectangle", "Shape.frame", "Shape.rotation", "Shape.name"],
              limitations: ["The document stores every preset; SVG approximates unsupported geometries and shape rotations. Group/connector creation and flip setters are not public APIs."],
              inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Rotate presets 15 degrees"),
        .init(.fillsAndLines, title: "Fills, outlines and shadows", summary: "Solid, alpha, theme, linear/radial gradient and image fills; every dash and compound stroke.",
              operations: ["Shape.setFill", "Shape.setLine", "Shape.enableSoftShadow", "Fill.themeColor", "GradientFill.radial", "LineDash.allCases", "LineCompound.allCases"],
              limitations: ["Preview gradient geometry and compound strokes may be approximated; the authored document retains their settings."],
              inputs: [.text, .accent, .alternative], alternativeLabel: "Reverse gradient colors"),
        .init(.text, title: "Rich text and live fields", summary: "Paragraphs, lists, formatted runs, external/internal links, slide numbers and dates.",
              operations: ["TextFrame.clear", "TextFrame.addParagraph", "TextFrame.setMargins", "TextFrame.wordWrap", "TextFrame.verticalAnchor", "Paragraph.setSpacing", "Paragraph.setLineSpacing", "Paragraph.indentLevel", "Paragraph.setBullet", "Paragraph.setNumbered", "Paragraph.setNoBullet", "Paragraph.alignment", "Paragraph.addRun", "Run.fontName", "Run.fontSize", "Run.bold", "Run.italic", "Run.underline", "Run.strikethrough", "Run.letterSpacing", "Run.color", "Run.setSuperscript", "Run.setSubscript", "Run.setHyperlink", "Run.setSlideLink", "Presentation.showSlideNumbers", "Presentation.showDate"],
              limitations: ["Office evaluates live fields; previews show stored field text. Font availability and text shaping can affect layout."],
              inputs: [.text, .accent, .sampleSize, .alternative], alternativeLabel: "Right-align paragraphs"),
        .init(.pictures, title: "Pictures and image fills", summary: "Cover/stretch, source crop, rotation, independent replacement, deduplication and stretch/tile fills.",
              operations: ["ShapeCollection.addPicture", "Picture.setCrop", "Picture.replaceImage", "Picture.imageData", "Picture.imagePart", "Shape.rotation", "Fill.image", "Presentation.renderSVG"],
              limitations: ["Only owned PNG/GIF pixels are used. Tiling belongs to image fills, not picture fit. Unsupported replacement bytes and empty crop regions are refused."],
              inputs: [.text, .accent, .alternative], alternativeLabel: "Use asymmetric crop and negative rotation"),
        .init(.tableStructure, title: "Edit a table grid", summary: "Merge, expand, split, insert, delete, move and reorder rows and columns with atomic refusal checks.",
              operations: ["ShapeCollection.addTable", "Table.setContents", "Table.columnWidths", "Table.rowHeights", "Table.setColumnWidth", "Table.setRowHeight", "Table.merge", "Table.mergeInfo", "Table.mergedRegions", "Table.unmerge", "Table.insertRow", "Table.insertColumn", "Table.removeRow", "Table.removeColumn", "Table.moveRow", "Table.moveColumn", "Table.reorderRows", "Table.reorderColumns"],
              limitations: ["Unmerge preserves the origin; text discarded by merge cannot be recovered. Moves that split a merge are refused."],
              inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Leave a final horizontal merge"),
        .init(.tableStyles, title: "74 native table styles", summary: "Every native style with visible names and paired header/banding variants.",
              operations: ["BuiltInTableStyle.allCases", "Table.applyBuiltInStyle", "Table.builtInStyle", "Table.firstRowHeader", "Table.lastRowFooter", "Table.firstColumnHeader", "Table.lastColumnFooter", "Table.bandedRows", "Table.bandedColumns", "Table.rightToLeft"],
              limitations: ["Native styles use theme colors. SVG is a preview; PowerPoint remains the document rendering authority."],
              inputs: [.text, .sampleSize, .alternative], alternativeLabel: "Column bands, footers and RTL"),
        .init(.tableAppearance, title: "Cell appearance", summary: "All six border edges, stroke styles, fill types, padding, vertical text and style inheritance.",
              operations: ["Table.clearBuiltInStyle", "Table.cellPadding", "TableCell.setFill", "TableCell.setPadding", "TableCell.setText", "TableCell.applyTextStyle", "TableCell.setBorders", "TableCell.setBorder", "TableCell.clearBorder", "TableCell.verticalAnchor", "TableCell.textDirection", "Table.rightToLeft"],
              limitations: ["Vertical text and gradient fills can be approximated by previews. Explicit no-border and inherited border are verified separately."],
              inputs: [.text, .accent, .alternative], alternativeLabel: "RTL table and vertical-270 text")
    ]

    static func make(_ id: LibraryDemoID, options: LibraryLabOptions) throws -> LibraryLabDraft {
        switch id {
        case .shapes: return try shapes(options)
        case .fillsAndLines: return try fills(options)
        case .text: return try text(options)
        case .pictures: return try pictures(options)
        case .tableStructure: return try tableStructure(options)
        case .tableStyles: return try tableStyles(options)
        case .tableAppearance: return try tableAppearance(options)
        default: throw RostrumError.packageInvalid("Not a drawing recipe: \(id.rawValue)")
        }
    }

    private static func page(_ deck: Presentation, _ title: String) throws -> Slide {
        // Presentation starts with one blank slide; use it before adding pages.
        let slide: Slide
        if deck.slides.count == 1, try deck.slides[0].shapes.count == 0 {
            slide = try deck.slides[0]
        } else {
            slide = try deck.slides.add()
        }
        try LibraryLabSupport.text(title, on: slide)
        return slide
    }

    private static func nodes(_ root: XML.Element, _ name: String) -> [XML.Element] {
        (root.name == name ? [root] : []) + root.childElements.flatMap { nodes($0, name) }
    }

    private static func shapes(_ o: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Shape preset gallery")
        var slide = try page(deck, "\(o.text) — 178 presets")
        let before = try deck.serializedData()
        let perPage = min(24, max(12, o.sampleSize * 3))
        let presets = ShapeGeometry.allCases
        for (index, preset) in presets.enumerated() {
            if index > 0 && index % perPage == 0 { slide = try page(deck, "Presets \(index + 1)–\(min(index + perPage, presets.count))") }
            let slot = index % perPage
            let x = 0.45 + Double(slot % 6) * 2.1
            let y = 1.0 + Double(slot / 6) * 1.35
            let shape = try slide.shapes.addShape(preset, frame: LibraryLabSupport.frame(x, y, 1.65, 0.82), fill: .solid(Color(o.accentHex)))
            shape.name = "Preset: \(preset.rawValue)"
            shape.frame = LibraryLabSupport.frame(x + 0.04, y, 1.6, 0.8)
            shape.rotation = o.alternative ? 15 : 0
            let label = try slide.shapes.addTextBox(LibraryLabSupport.frame(x, y + 0.84, 2, 0.45))
            label.textFrame?.text = preset.rawValue
            label.textFrame?.paragraphs.first?.runs.first?.fontSize = 10
        }
        let rounded = try slide.shapes.addRoundedRectangle(LibraryLabSupport.frame(0.5, 6.6, 3.5, 0.45), cornerRadius: .inches(0.2), fill: .solid(Color(o.accentHex)))
        rounded.name = "Explicit corner radius"
        rounded.textFrame?.text = "Explicit corner radius"
        return LibraryLabDraft(deck: deck, before: before, verify: { reopened in
            let actual = try reopened.slides.flatMap { nodes(try $0.part.dom(), "a:prstGeom") }.compactMap { $0[attribute: "prst"] }
            let all = reopened.slides.flatMap { $0.shapes.all }.filter { $0.name.hasPrefix("Preset: ") }
            return [
                .init("All 178 preset geometries persist", Set(presets.map(\.rawValue)).isSubset(of: Set(actual)) && presets.count == 178, "Compared actual a:prstGeom tokens with the complete public preset catalog."),
                .init("Edited frames and rotation persist", all.count == 178 && all.allSatisfy { $0.frame.width == .inches(1.6) && $0.rotation == (o.alternative ? 15 : 0) }, "Every preset has the edited width and selected rotation."),
                .init("Explicit rounded corner persists", try reopened.slides.contains { nodes(try $0.part.dom(), "a:gd").contains { $0[attribute: "name"] == "adj" && $0[attribute: "fmla"] == "val 44444" } }, "Radius 0.2 inches / short side 0.45 inches.")
            ]
        })
    }

    private static func fills(_ o: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Fills and lines")
        let slide = try page(deck, o.text)
        let before = try deck.serializedData()
        let accent = Color(o.accentHex)
        let start = o.alternative ? Color.white : accent
        let end = o.alternative ? accent : Color.white
        let stops = [GradientStop(position: 0, color: start), GradientStop(position: 1, color: end)]
        let choices: [(String, Fill)] = [
            ("Solid", .solid(accent)), ("Alpha 40%", .solidAlpha(accent, 0.4)),
            ("Theme accent", .themeColor(.accent1)), ("No fill", .none),
            ("Linear", .gradient(GradientFill(stops: stops, angleDegrees: 35))),
            ("Radial", .gradient(.radial(stops: stops))),
            ("Image stretch", .image(LibraryLabSupport.pixels, fit: .stretch)),
            ("Image tile", .image(LibraryLabSupport.pixels, fit: .tile(scale: 12)))
        ]
        for (i, entry) in choices.enumerated() {
            let shape = try slide.shapes.addShape(.rectangle, frame: LibraryLabSupport.frame(0.5 + Double(i % 4) * 3.1, 1 + Double(i / 4) * 1.3, 2.8, 1), fill: .none)
            shape.name = entry.0
            try shape.setFill(entry.1)
            shape.setLine(Line(color: accent, width: .points(2)))
            shape.textFrame?.text = entry.0
            if i == 0 { shape.enableSoftShadow() }
        }
        let outlines = try page(deck, "Dash and compound stroke catalog")
        for (i, dash) in LineDash.allCases.enumerated() {
            let shape = try outlines.shapes.addShape(.rectangle, frame: LibraryLabSupport.frame(0.5 + Double(i % 4) * 3.1, 1 + Double(i / 4), 2.7, 0.65), fill: .none)
            shape.name = "Dash: \(dash.rawValue)"
            shape.textFrame?.text = dash.rawValue
            shape.setLine(Line(color: accent, width: .points(2), dash: dash))
        }
        for (i, compound) in LineCompound.allCases.enumerated() {
            let shape = try outlines.shapes.addShape(.rectangle, frame: LibraryLabSupport.frame(0.5 + Double(i) * 2.5, 4.7, 2.2, 0.9), fill: .none)
            shape.name = "Compound: \(compound.rawValue)"
            shape.textFrame?.text = compound.rawValue
            shape.setLine(Line(color: accent, width: .points(5), compound: compound))
        }
        return LibraryLabDraft(deck: deck, before: before, verify: { reopened in
            let first = try reopened.slides[0].shapes.all
            let outline = try reopened.slides[1].shapes.all
            guard first.count == 9 else { return [.init("Fill specimens survive", false, "Expected title and eight fill specimens.")] }
            return [
                .init("Solid, alpha, theme and no-fill read back", first[1].fill == .solid(accent, alpha: 1) && first[2].fill == .solid(accent, alpha: 0.4) && first[3].fill == .themeScheme("accent1") && first[4].fill == .noFill, "Four distinct fill semantics survive."),
                .init("Both gradients preserve stops", first[5].fill == .gradient(stops) && first[6].fill == .gradient(stops), "Stop positions and colors match the selected variant."),
                .init("Radial path and tiling persist", try nodes(reopened.slides[0].part.dom(), "a:path").contains { $0[attribute: "path"] == "circle" } && nodes(reopened.slides[0].part.dom(), "a:tile").contains { $0[attribute: "sx"] == "1200000" }, "Verified radial gradient and image tile settings in document XML."),
                .init("Shadow survives", first[1].hasShadow, "Outer shadow is present."),
                .init("Every dash and compound survives", Set(outline.compactMap { $0.line?.dashStyle }) == Set(LineDash.allCases.map(\.rawValue)) && Set(outline.compactMap { $0.line?.compoundStyle }) == Set(LineCompound.allCases.map(\.rawValue)), "Compared every public dash and compound token.")
            ]
        })
    }

    private static func text(_ o: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Rich text")
        let slide = try page(deck, "Rich text — \(o.text)")
        let destination = try page(deck, "Internal link destination")
        let box = try slide.shapes.addTextBox(LibraryLabSupport.frame(0.6, 1, 11.8, 5.6))
        box.name = "Rich text specimen"
        let frame = box.textFrame!
        frame.text = o.text
        let before = try deck.serializedData()
        frame.clear()
        frame.wordWrap = true
        frame.verticalAnchor = .middle
        frame.setMargins(left: .points(12), top: .points(6), right: .points(12), bottom: .points(6))
        let p = frame.addParagraph()
        p.alignment = o.alternative ? .right : .left
        p.setNoBullet()
        p.setSpacing(beforePoints: 3, afterPoints: 9)
        p.setLineSpacing(1.2)
        let run = p.addRun(o.text)
        run.fontName = "Arial"; run.fontSize = 24; run.bold = true; run.italic = true
        run.underline = true; run.strikethrough = true; run.letterSpacing = 1.5; run.color = Color(o.accentHex)
        p.addRun(" x").setSuperscript()
        p.addRun(" y").setSubscript()
        for i in 0..<o.sampleSize {
            let list = frame.addParagraph()
            list.alignment = o.alternative ? .right : .left
            list.indentLevel = i % 3
            if i.isMultiple(of: 2) { list.setBullet("•", font: "Arial") } else { list.setNumbered("arabicPeriod") }
            list.addRun("List item \(i + 1)").fontSize = 16
        }
        let links = frame.addParagraph()
        links.addRun("External reference").setHyperlink("https://example.com/lectern")
        links.addRun(" · Go to destination").setSlideLink(to: destination)
        try deck.showSlideNumbers()
        try deck.showDate()
        return LibraryLabDraft(deck: deck, before: before, verify: { reopened in
            let source = try reopened.slides[0]
            let target = try reopened.slides[1]
            let body = source.shapes.all.first { $0.name == "Rich text specimen" }?.textFrame
            let first = body?.paragraphs.first?.runs.first
            let xml = try reopened.slides[0].part.dom()
            let runs = body?.paragraphs.first?.runs ?? []
            let internalLink = nodes(xml, "a:hlinkClick").first { $0[attribute: "action"] == "ppaction://hlinksldjump" }
            let rel = internalLink?[attribute: "r:id"].flatMap { source.part.rels.relationship(withId: $0) }
            return [
                .init("Run formatting persists", first?.text == o.text && first?.fontName == "Arial" && first?.fontSize == 24 && first?.bold == true && first?.italic == true && first?.underline == true && first?.strikethrough == true && first?.letterSpacing == 1.5 && first?.color == Color(o.accentHex), "Text, font, size, emphasis, tracking and accent match."),
                .init("Baseline and paragraphs persist", runs.count == 3 && runs[1].baselinePercent == 30 && runs[2].baselinePercent == -25 && body?.paragraphs.count == o.sampleSize + 2 && body?.paragraphs.first?.alignment == (o.alternative ? .right : .left), "Superscript/subscript and chosen alignment survive."),
                .init("Bullet and numbered lists persist", nodes(xml, "a:buChar").count == (o.sampleSize + 1) / 2 && nodes(xml, "a:buAutoNum").count == o.sampleSize / 2, "Both list forms retain their authored paragraph counts."),
                .init("External and slide links resolve", body?.paragraphs.last?.runs.first?.hyperlink == "https://example.com/lectern" && rel.map { PackURI.resolve(target: $0.target, relativeTo: source.part.uri.baseURI) == target.part.uri } == true, "External URL and internal slide relationship are correct."),
                .init("Live fields persist", Set(nodes(xml, "a:fld").compactMap { $0[attribute: "type"] }) == Set(["slidenum", "datetime"]), "Date and slide-number fields retain their field types."),
                .init("Margins and vertical anchor persist", body?.wordWrap == true && body?.verticalAnchor == .middle && nodes(xml, "a:bodyPr").contains { $0[attribute: "lIns"] == "152400" && $0[attribute: "tIns"] == "76200" }, "12-point horizontal and 6-point vertical insets.")
            ]
        })
    }

    private static func refused(_ name: String, deck: Presentation, operation: () throws -> Void) throws -> LibraryLabCheck {
        let before = try deck.serializedData()
        var threw = false
        do { try operation() } catch { threw = true }
        return .init(name, try threw && deck.serializedData() == before, "The operation must throw and leave the serialized package unchanged.")
    }

    private static func pictures(_ o: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Picture edits")
        let slide = try page(deck, o.text)
        let original = LibraryLabSupport.pixels
        // An owned, complete 1×1 GIF; changing media format also exercises content types.
        let replacement = Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")!
        let first = try slide.shapes.addPicture(original, frame: LibraryLabSupport.frame(0.5, 1, 3, 2), fit: .fill)
        let second = try slide.shapes.addPicture(original, frame: LibraryLabSupport.frame(4.5, 1, 3, 2), fit: .stretch)
        first.name = "Edited picture"; second.name = "Shared original"
        let natural = try slide.shapes.addPicture(original, x: .inches(12), y: .inches(1))
        natural.name = "Natural size"
        let before = try deck.serializedData()
        var checks = [LibraryLabCheck("Identical pictures share a media part", first.imagePart?.uri == second.imagePart?.uri && second.imagePart?.uri == natural.imagePart?.uri, "All three pictures initially reference the same PNG.")]
        let crop = o.alternative ? PictureCrop(left: 0.1, top: 0.2, right: 0.3, bottom: 0.1) : PictureCrop(left: 0.2, top: 0.1, right: 0.2, bottom: 0.1)
        try first.setCrop(nil)
        try first.setCrop(crop)
        first.rotation = o.alternative ? -20 : 20
        try first.replaceImage(replacement)
        checks.append(try refused("Invalid replacement is atomic", deck: deck) { try first.replaceImage(Data("unsupported".utf8)) })
        checks.append(try refused("Empty source crop is atomic", deck: deck) { try first.setCrop(PictureCrop(left: 0.6, right: 0.6)) })
        for (i, mode) in [ImageFillMode.stretch, .tile(scale: 16)].enumerated() {
            let shape = try slide.shapes.addShape(.ellipse, frame: LibraryLabSupport.frame(0.5 + Double(i) * 4, 4, 3, 2), fill: .image(original, fit: mode), line: Line(color: Color(o.accentHex)))
            shape.name = i == 0 ? "Stretch image fill" : "Tile image fill"
        }
        return LibraryLabDraft(deck: deck, before: before, checks: checks, verify: { reopened in
            let images = try reopened.slides[0].shapes.all.compactMap { $0 as? Picture }
            guard images.count == 3 else { return [.init("Picture specimens survive", false, "Expected three independent picture shapes.")] }
            let svg = try reopened.renderSVG(slideAt: 0)
            let xml = try reopened.slides[0].part.dom()
            return [
                .init("Replacement is independent", images.count == 3 && images[0].imageData == replacement && images[0].imageFormat == "gif" && images[1].imageData == original && images[2].imageData == original && images[0].imagePart?.uri != images[1].imagePart?.uri, "Only the edited picture changed; shared original pixels survive."),
                .init("Crop, frame and rotation persist", images[0].crop == crop && images[0].frame == LibraryLabSupport.frame(0.5, 1, 3, 2) && images[0].rotation == (o.alternative ? -20 : 20) && images[1].crop == nil, "Replacement keeps crop and transforms, while stretch has no source crop."),
                .init("Image media remain deduplicated", reopened.package.parts.values.filter { $0.uri.description.hasPrefix("/ppt/media/") }.count == 2, "One original PNG and one replacement GIF serve all uses."),
                .init("Image fills and clipping render", nodes(xml, "a:tile").contains { $0[attribute: "sx"] == "1600000" } && svg.contains("clipPath") && svg.contains("rotate(") && svg.contains("data:image/gif"), "SVG contains crop clipping, transformed image and replacement media.")
            ]
        })
    }

    private static func table(in deck: Presentation, slide: Int = 0) throws -> Table {
        guard let table = try deck.slides[slide].shapes.all.compactMap({ ($0 as? TableFrame)?.table }).first else {
            throw RostrumError.packageInvalid("Expected a table in drawing recipe")
        }
        return table
    }

    private static func tableStructure(_ o: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Table structural edits")
        let slide = try page(deck, o.text)
        let n = max(3, min(6, o.sampleSize))
        let table = try slide.shapes.addTable(rows: n, columns: n, frame: LibraryLabSupport.frame(0.7, 1, 11, 4.8))
        var expected = (0..<n).map { r in (0..<n).map { c in "R\(r + 1)C\(c + 1)" } }
        expected[0][0] = o.text
        table.setContents(expected).columnWidths(Array(repeating: .inches(11 / Double(n)), count: n)).rowHeights(Array(repeating: .inches(4.8 / Double(n)), count: n))
        let before = try deck.serializedData()
        try table.merge(row: 0, column: 0, rowSpan: 2, columnSpan: 2)
        expected[0][1] = ""; expected[1][0] = ""; expected[1][1] = ""
        var checks = [LibraryLabCheck("Merge reports covered cells", try table.mergeInfo(row: 1, column: 1) == TableMergeRegion(row: 0, column: 0, rowSpan: 2, columnSpan: 2), "Covered cells resolve to their origin and span.")]
        checks.append(try refused("Overlapping merge is atomic", deck: deck) { try table.merge(row: 1, column: 1, rowSpan: 1, columnSpan: 2) })
        checks.append(try refused("Move splitting a merge is atomic", deck: deck) { try table.moveRow(from: 0, to: n - 1) })
        try table.insertRow(at: 1, height: .inches(0.4))
        try table.insertColumn(at: 1, width: .inches(0.5))
        checks.append(.init("Insertion expands a crossed merge", try table.mergedRegions == [TableMergeRegion(row: 0, column: 0, rowSpan: 3, columnSpan: 3)], "Inserting within both axes expands the merge to 3×3."))
        try table.removeRow(at: 1); try table.removeColumn(at: 1)
        try table.unmerge(row: 1, column: 1)
        checks.append(.init("Unmerge retains origin only", try table.mergedRegions.isEmpty && table.cell(0, 0).text == o.text && table.cell(1, 1).text.isEmpty, "Merge-discarded text is not fabricated by unmerge."))
        try table.moveRow(from: n - 1, to: 0); expected.insert(expected.removeLast(), at: 0)
        try table.moveColumn(from: n - 1, to: 0)
        for r in 0..<n { expected[r].insert(expected[r].removeLast(), at: 0) }
        let reverse = Array((0..<n).reversed())
        try table.reorderRows(reverse); expected.reverse()
        try table.reorderColumns(reverse)
        for r in 0..<n { expected[r].reverse() }
        table.setColumnWidth(0, .inches(1.7)); table.setRowHeight(0, .inches(0.9))
        if o.alternative { try table.merge(row: 0, column: 0, rowSpan: 1, columnSpan: 2); expected[0][1] = "" }
        let expectedGrid = expected
        return LibraryLabDraft(deck: deck, before: before, checks: checks, verify: { reopened in
            let t = try self.table(in: reopened)
            let grid = try (0..<t.rowCount).map { r in try (0..<t.columnCount).map { try t.cell(r, $0).text } }
            return [
                .init("Grid edits preserve the expected cell identities", grid == expectedGrid, "Every surviving cell matches the independently computed permutation."),
                .init("Edited dimensions persist", try t.columnWidth(0) == .inches(1.7) && t.rowHeight(0) == .inches(0.9), "Column width and row height are read from the reopened grid."),
                .init("Final topology matches variant", try t.mergedRegions == (o.alternative ? [TableMergeRegion(row: 0, column: 0, rowSpan: 1, columnSpan: 2)] : []), "Variant either leaves a horizontal merge or a fully split grid.")
            ]
        })
    }

    private static func tableStyles(_ o: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "74 native table styles")
        var slide = try page(deck, "\(o.text) — native styles")
        let before = try deck.serializedData()
        let perPage = min(6, max(2, o.sampleSize))
        let styles = BuiltInTableStyle.allCases
        for (i, style) in styles.enumerated() {
            if i > 0 && i % perPage == 0 { slide = try page(deck, "Native styles \(i + 1)–\(min(i + perPage, styles.count))") }
            let slot = i % perPage
            let x = 0.5 + Double(slot % 2) * 6.3
            let y = 1.1 + Double(slot / 2) * 1.85
            try LibraryLabSupport.text(style.name, on: slide, frame: LibraryLabSupport.frame(x, y - 0.3, 6, 0.3))
            let t = try slide.shapes.addTable(rows: 3, columns: 3, frame: LibraryLabSupport.frame(x, y, 5.8, 1.35))
            t.setContents([["Name", "Value", "Status"], ["Alpha", "12", "Ready"], ["Beta", "24", "Review"]]).applyBuiltInStyle(style)
            t.firstRowHeader = !o.alternative; t.lastRowFooter = o.alternative
            t.firstColumnHeader = !o.alternative; t.lastColumnFooter = o.alternative
            t.bandedRows = !o.alternative; t.bandedColumns = o.alternative; t.rightToLeft = o.alternative
        }
        return LibraryLabDraft(deck: deck, before: before, verify: { reopened in
            let tables = reopened.slides.flatMap { $0.shapes.all.compactMap { ($0 as? TableFrame)?.table } }
            return [
                .init("All 74 native style identities persist", tables.compactMap(\.builtInStyle) == styles && styles.count == 74, "Ordered style GUIDs match every public built-in style."),
                .init("All style flags persist", tables.allSatisfy { $0.firstRowHeader == !o.alternative && $0.lastRowFooter == o.alternative && $0.firstColumnHeader == !o.alternative && $0.lastColumnFooter == o.alternative && $0.bandedRows == !o.alternative && $0.bandedColumns == o.alternative && $0.rightToLeft == o.alternative }, "Headers, footers, both banding axes and RTL match the selected variant."),
                .init("Style assignment preserves content", try tables.allSatisfy { try $0.cell(1, 0).text == "Alpha" && $0.cell(2, 1).text == "24" }, "Changing style leaves table values intact.")
            ]
        })
    }

    private static func tableAppearance(_ o: LibraryLabOptions) throws -> LibraryLabDraft {
        let deck = try LibraryLabSupport.deck(title: "Table cell appearance")
        let slide = try page(deck, o.text)
        let t = try slide.shapes.addTable(rows: 3, columns: 3, frame: LibraryLabSupport.frame(0.7, 1, 11.6, 5.4))
        t.setContents([["All borders", "No top border", "Inherited top"], ["Gradient", "Image", "Transparent"], ["Direction", "Theme fill", "Plain"]])
        let before = try deck.serializedData()
        t.clearBuiltInStyle().cellPadding(.points(8))
        t.rightToLeft = o.alternative
        let accent = Color(o.accentHex)
        let cell = try t.cell(0, 0)
        cell.setText(o.text, style: deck.style.type(.body), align: .center)
        cell.applyTextStyle(deck.style.type(.body), align: .center)
        cell.setPadding(left: .points(12), top: .points(9), right: .points(12), bottom: .points(9))
        cell.verticalAnchor = .middle
        try cell.setFill(.solid(accent))
        for (i, edge) in TableCellBorder.allCases.enumerated() {
            cell.setBorder(edge, line: Line(color: accent, width: .points(Double(i + 1)), compound: .double, dash: .dash))
        }
        try t.cell(0, 1).setBorders(Line(color: accent)).setBorder(.top, line: nil)
        try t.cell(0, 2).setBorders(Line(color: accent)).clearBorder(.top)
        try t.cell(1, 0).setFill(.gradient(GradientFill(from: accent, to: .white)))
        try t.cell(1, 1).setFill(.image(LibraryLabSupport.pixels, fit: .stretch))
        try t.cell(1, 2).setFill(.solidAlpha(accent, 0.3))
        try t.cell(2, 0).textDirection = o.alternative ? .vertical270 : .vertical
        try t.cell(2, 1).setFill(.themeColor(.accent2))
        try t.cell(2, 2).setFill(Fill.none)
        return LibraryLabDraft(deck: deck, before: before, verify: { reopened in
            let table = try self.table(in: reopened)
            let cell = try table.cell(0, 0)
            let root = try reopened.slides[0].part.dom()
            return [
                .init("All six borders preserve stroke properties", TableCellBorder.allCases.enumerated().allSatisfy { i, edge in let border = cell.border(edge); return border?.color == accent && border?.width == .points(Double(i + 1)) && border?.compoundStyle == "dbl" && border?.dashStyle == "dash" }, "Four outer edges and both diagonals retain their individual widths."),
                .init("Suppressed and inherited borders remain distinct", try table.cell(0, 1).border(.top)?.isNone == true && table.cell(0, 2).border(.top) == nil, "Explicit no-fill differs from absent/inherited line."),
                .init("Cell fills persist", try cell.fill == .solid(accent, alpha: 1) && table.cell(1, 2).fill == .solid(accent, alpha: 0.3) && table.cell(2, 1).fill == .themeScheme("accent2") && table.cell(2, 2).fill == .noFill, "Solid, alpha, theme and no-fill retain their semantics."),
                .init("Cell layout and text persist", try cell.text == o.text && cell.verticalAnchor == .middle && table.cell(2, 0).textDirection == (o.alternative ? .vertical270 : .vertical) && table.rightToLeft == o.alternative && table.builtInStyle == .noStyleNoGrid && nodes(root, "a:tcPr").contains { $0[attribute: "marL"] == "152400" && $0[attribute: "marT"] == "114300" }, "Text, padding, anchor, direction and No Style, No Grid identity survive.")
            ]
        })
    }
}
