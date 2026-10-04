import Foundation
import Rostrum

/// Native PowerPoint common-word cases; standalone TextShaper defaults are separate.
extension PlatformLabRecipes {
    static func paragraphLigatureReferences() throws -> ParagraphBoundaryReferences {
        try JSONDecoder().decode(ParagraphBoundaryReferences.self, from: resource("ParagraphLigatureReferences", "json"))
    }

    static func paragraphLigatures(_ deck: Presentation, narrow: Bool) throws -> (checks: [LibraryLabCheck], verify: (Presentation) throws -> [LibraryLabCheck]) {
        let samples = try paragraphLigatureReferences().cases.filter { $0.id == "mixed-size-edge" || $0.narrow == narrow }
        let slide = try deck.slides.add()
        let title = try text("Common Latin words at a native wrap boundary", on: slide, in: LibraryLabSupport.frame(0.6, 0.3, 12, 0.6))
        title.textFrame?.paragraphs.first?.runs.first?.fontSize = 26
        for (x, label) in [(0.6, "Original size"), (4.8, "Fit in shape"), (9.0, "Fit in text frame")] {
            let heading = try text(label, on: slide, in: LibraryLabSupport.frame(x, 1.0, 3.7, 0.5))
            heading.textFrame?.paragraphs.first?.runs.first?.fontSize = 20
        }
        var checks: [LibraryLabCheck] = []
        var originals: [String: [RichTextLine]] = [:]
        var fitted: [String: [RichTextLine]] = [:]
        var fits: [String: Autofit] = [:]
        for (row, sample) in samples.enumerated() {
            let y = row == 0 ? 1.9 : 4.0
            let caption = try text("\(sample.title) | \(sample.widthPoints) pt wide", on: slide, in: LibraryLabSupport.frame(0.6, y - 0.45, 11.9, 0.4))
            caption.textFrame?.paragraphs.first?.runs.first?.fontSize = 15
            let natural = try ligatureBox(sample, on: slide, x: 0.6, y: y, height: 60, role: "original")
            let shapeFit = try ligatureBox(sample, on: slide, x: 4.8, y: y, height: 22, role: "shape fit")
            let frameFit = try ligatureBox(sample, on: slide, x: 9.0, y: y, height: 22, role: "frame fit")
            let selected = try require(shapeFit.fitText(fonts: deck.fonts, theme: deck.theme), "Ligature shape fit missing")
            let textFrame = try require(frameFit.textFrame, "Ligature text frame missing")
            let selectedFrame = textFrame.fitText(in: frameFit.frame, fonts: deck.fonts, theme: deck.theme)
            let originalLayout = try paragraphGeometry(deck, named: natural.name, slideAt: 3)
            let shapeLayout = try paragraphGeometry(deck, named: shapeFit.name, slideAt: 3)
            let frameLayout = try paragraphGeometry(deck, named: frameFit.name, slideAt: 3)
            originals[natural.name] = originalLayout.lines
            fitted[shapeFit.name] = shapeLayout.lines
            fitted[frameFit.name] = frameLayout.lines
            fits[shapeFit.name] = selected
            fits[frameFit.name] = selectedFrame
            checks += [
                .init("Native Latin wrap: \(sample.id)", boundaryLineStrings(originalLayout) == sample.nativeLines && originalLayout.diagnostics.isEmpty, "The unfitted line strings match the independently captured PowerPoint PDF at \(sample.widthPoints) pt."),
                .init("Public ligature fits: \(sample.id)", selected == selectedFrame && selected.fits && selected.fontScale < 100 && shapeLayout.lines == frameLayout.lines && shapeLayout.fits && shapeLayout.diagnostics.isEmpty && boundaryLineStrings(shapeLayout).joined() == sample.runs.map(\.text).joined(), "Both public fit paths preserve every character and select the same computed scale: \(selected.fontScale)%. This is not an assertion about PowerPoint's chosen autofit step.")
            ]
            let observed = sample.nativeLines.joined(separator: " / ")
            let nativeNote = try text("Native reference: \(observed)", on: slide, in: LibraryLabSupport.frame(0.6, y + 0.95, 3.9, 0.45))
            nativeNote.textFrame?.paragraphs.first?.runs.first?.fontSize = 13
            for x in [4.8, 9.0] {
                let note = try text("Computed scale: \(selected.fontScale)%", on: slide, in: LibraryLabSupport.frame(x, y + 0.55, 3.7, 0.45))
                note.textFrame?.paragraphs.first?.runs.first?.fontSize = 13
            }
        }
        let note = try text("The alternative changes only the officeZ row by 0.02 pt. The mixed 18/12 pt row stays at 39.01 pt.\nIndependent PowerPoint references use regular DejaVu Sans and separate Latin letter glyphs. Both fitting scales are computed by Rostrum, not native autofit choices. Left alignment, zero insets; no broad script or Office pixel-parity claim.", on: slide, in: LibraryLabSupport.frame(0.6, 6.15, 12.1, 0.9))
        note.textFrame?.paragraphs.first?.runs.first?.fontSize = 13
        note.fitText(fonts: deck.fonts)
        let svg = try deck.renderSVG(slideAt: 3)
        return (checks, { reopened in
            var result: [LibraryLabCheck] = []
            for sample in samples {
                let originalName = sample.id + " original"
                let original = try paragraphGeometry(reopened, named: originalName, slideAt: 3)
                let shape = try paragraphGeometry(reopened, named: sample.id + " shape fit", slideAt: 3)
                let frame = try paragraphGeometry(reopened, named: sample.id + " frame fit", slideAt: 3)
                let properties = try ["original", "shape fit", "frame fit"].allSatisfy { role in
                    try ligaturePropertiesMatch(reopened, sample: sample, role: role, fit: fits[sample.id + " " + role])
                }
                result += [
                    .init("Saved native Latin wrap: \(sample.id)", boundaryLineStrings(original) == sample.nativeLines && original.lines == originals[originalName], "Saved-file line contents retain the independent native expectation and all measured spans."),
                    .init("Saved ligature styles and fit: \(sample.id)", properties && shape.lines == fitted[sample.id + " shape fit"] && frame.lines == fitted[sample.id + " frame fit"], "Original run text, sizes, black color and tracking survive; both stored autofit attributes and fitted spans match the selected result.")
                ]
            }
            result.append(.init("Ligature SVG survives reopening", try reopened.renderSVG(slideAt: 3) == svg, "The saved ligature slide preview is byte-identical."))
            return result
        })
    }

    private static func ligatureBox(_ sample: ParagraphBoundaryReferences.Sample, on slide: Slide, x: Double, y: Double, height: Double, role: String) throws -> Shape {
        let rect = Rect(x: .inches(x), y: .inches(y), width: .points(sample.widthPoints), height: .points(height))
        try slide.shapes.addShape(.rectangle, frame: rect, fill: .none, line: Line(color: Color("276D89")))
        let box = try slide.shapes.addTextBox(rect)
        box.name = sample.id + " " + role
        let frame = try require(box.textFrame, "Ligature text frame missing")
        frame.clear()
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.wordWrap = true
        // Public full-size authoring; the native reference uses noAutofit.
        frame.setAutoFit(fontScale: 1)
        let paragraph = frame.addParagraph()
        paragraph.alignment = .left
        paragraph.setNoBullet()
        for value in sample.runs {
            let run = paragraph.addRun(value.text)
            run.fontName = value.font
            run.fontSize = value.size
            run.letterSpacing = value.tracking
            run.color = .black
        }
        return box
    }

    static func ligaturePropertiesMatch(_ deck: Presentation, sample: ParagraphBoundaryReferences.Sample, role: String, fit: Autofit?) throws -> Bool {
        let name = sample.id + " " + role
        let shape = try require(deck.slides[3].shapes.all.first { $0.name == name }, "Saved ligature shape missing")
        guard let frame = shape.textFrame, let paragraph = frame.paragraphs.first,
              paragraph.runs.count == sample.runs.count, paragraph.alignment == .left,
              shape.frame.width == .points(sample.widthPoints) else { return false }
        let styles = zip(paragraph.runs.enumerated(), sample.runs).allSatisfy { pair, expected in
            let (_, run) = pair
            return run.text == expected.text && run.fontName == expected.font && run.fontSize == expected.size
                && run.letterSpacing == expected.tracking && run.color == .black
        }
        let textBody = try paragraphBody(deck, named: name, slideAt: 3)
        let omittedKerning = DrawingLabFixtures.nodes(textBody, "a:rPr").allSatisfy { $0[attribute: "kern"] == nil }
        let body = textBody.firstChild(named: "a:bodyPr")
        guard omittedKerning, body?[attribute: "wrap"] == "square",
              ["lIns", "rIns", "tIns", "bIns"].allSatisfy({ body?[attribute: $0] == "0" }) else { return false }
        let norm = body?.firstChild(named: "a:normAutofit")
        if let fit {
            let scale = Double(norm?[attribute: "fontScale"] ?? "100000").map { $0 / 1000 }
            let reduction = Double(norm?[attribute: "lnSpcReduction"] ?? "0").map { $0 / 1000 }
            return styles && norm != nil && scale == fit.fontScale && reduction == fit.lineSpacingReduction
        }
        return styles && norm != nil && norm?[attribute: "fontScale"] == "100000" && norm?[attribute: "lnSpcReduction"] == nil
    }
}
