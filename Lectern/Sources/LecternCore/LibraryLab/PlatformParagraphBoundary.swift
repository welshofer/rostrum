import Foundation
import Rostrum

/// A small, source-cited subset of independently captured native line contents.
/// Expectations come from the PowerPoint PDF, never from RichTextLayout itself.
struct ParagraphBoundaryReferences: Decodable {
    struct Run: Decodable {
        let text: String
        let font: String
        let size: Double
        let tracking: Double
    }
    struct Sample: Decodable {
        let id: String
        let title: String
        let narrow: Bool
        let widthPoints: Double
        let runs: [Run]
        let nativeLines: [String]
    }
    let source: String
    let sourceSHA256: String
    let nativePDF: String
    let nativePDFSHA256: String
    let font: String
    let fontSHA256: String
    let scope: String
    let kerningEquivalenceSource: String?
    let kerningEquivalenceSHA256: String?
    let cases: [Sample]
}

extension PlatformLabRecipes {
    static func paragraphBoundaryReferences() throws -> ParagraphBoundaryReferences {
        try JSONDecoder().decode(ParagraphBoundaryReferences.self, from: resource("ParagraphBoundaryReferences", "json"))
    }

    static func paragraphBoundary(_ deck: Presentation, narrow: Bool) throws -> (checks: [LibraryLabCheck], verify: (Presentation) throws -> [LibraryLabCheck]) {
        let samples = try paragraphBoundaryReferences().cases.filter { $0.narrow == narrow }
        let slide = try deck.slides.add()
        let title = try text("Small width changes move line breaks", on: slide, in: LibraryLabSupport.frame(0.6, 0.3, 12, 0.6))
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
            let natural = try boundaryBox(sample, on: slide, x: 0.6, y: y, height: 60, role: "original")
            let shapeFit = try boundaryBox(sample, on: slide, x: 4.8, y: y, height: 22, role: "shape fit")
            let frameFit = try boundaryBox(sample, on: slide, x: 9.0, y: y, height: 22, role: "frame fit")
            let selected = try require(shapeFit.fitText(fonts: deck.fonts, theme: deck.theme), "Boundary shape fit missing")
            let textFrame = try require(frameFit.textFrame, "Boundary text frame missing")
            let selectedFrame = textFrame.fitText(in: frameFit.frame, fonts: deck.fonts, theme: deck.theme)
            let originalLayout = try paragraphGeometry(deck, named: natural.name, slideAt: 2)
            let shapeLayout = try paragraphGeometry(deck, named: shapeFit.name, slideAt: 2)
            let frameLayout = try paragraphGeometry(deck, named: frameFit.name, slideAt: 2)
            originals[natural.name] = originalLayout.lines
            fitted[shapeFit.name] = shapeLayout.lines
            fitted[frameFit.name] = frameLayout.lines
            fits[shapeFit.name] = selected
            fits[frameFit.name] = selectedFrame
            checks += [
                .init("Native boundary: \(sample.id)", boundaryLineStrings(originalLayout) == sample.nativeLines && originalLayout.diagnostics.isEmpty, "The unfitted line strings match the independently captured PowerPoint PDF at \(sample.widthPoints) pt."),
                .init("Public boundary fits: \(sample.id)", selected == selectedFrame && selected.fits && selected.fontScale < 100 && shapeLayout.lines == frameLayout.lines && shapeLayout.fits && shapeLayout.diagnostics.isEmpty && boundaryLineStrings(shapeLayout).joined() == sample.runs.map(\.text).joined(), "Both public fit paths preserve every character and select the same computed scale: \(selected.fontScale)%. This is not an assertion about PowerPoint's chosen autofit step.")
            ]
            let observed = sample.nativeLines.joined(separator: " / ")
            let nativeNote = try text("Native reference: \(observed)", on: slide, in: LibraryLabSupport.frame(0.6, y + 0.95, 3.9, 0.45))
            nativeNote.textFrame?.paragraphs.first?.runs.first?.fontSize = 13
            for x in [4.8, 9.0] {
                let note = try text("Computed scale: \(selected.fontScale)%", on: slide, in: LibraryLabSupport.frame(x, y + 0.55, 3.7, 0.45))
                note.textFrame?.paragraphs.first?.runs.first?.fontSize = 13
            }
        }
        let note = try text("The alternative selects widths 0.02 pt narrower. Native line strings come from independent PowerPoint exports; scales are computed by Rostrum.\nBounded ASCII with one scalar per shaped glyph, regular DejaVu Sans, left alignment and zero insets. No template inheritance or general PowerPoint pixel-parity claim.", on: slide, in: LibraryLabSupport.frame(0.6, 6.15, 12.1, 0.9))
        note.textFrame?.paragraphs.first?.runs.first?.fontSize = 14
        note.fitText(fonts: deck.fonts)
        let svg = try deck.renderSVG(slideAt: 2)
        return (checks, { reopened in
            var result: [LibraryLabCheck] = []
            for sample in samples {
                let originalName = sample.id + " original"
                let original = try paragraphGeometry(reopened, named: originalName, slideAt: 2)
                let shape = try paragraphGeometry(reopened, named: sample.id + " shape fit", slideAt: 2)
                let frame = try paragraphGeometry(reopened, named: sample.id + " frame fit", slideAt: 2)
                let properties = try ["original", "shape fit", "frame fit"].allSatisfy { role in
                    try boundaryPropertiesMatch(reopened, sample: sample, role: role, fit: fits[sample.id + " " + role])
                }
                result += [
                    .init("Saved native boundary: \(sample.id)", boundaryLineStrings(original) == sample.nativeLines && original.lines == originals[originalName], "Saved-file line contents retain the independent native expectation and all measured spans."),
                    .init("Saved boundary styles and fit: \(sample.id)", properties && shape.lines == fitted[sample.id + " shape fit"] && frame.lines == fitted[sample.id + " frame fit"], "Original run text, sizes, colors and tracking survive; both stored autofit attributes and fitted spans match the selected result.")
                ]
            }
            result.append(.init("Boundary SVG survives reopening", try reopened.renderSVG(slideAt: 2) == svg, "The saved boundary slide preview is byte-identical."))
            return result
        })
    }

    static func boundaryLineStrings(_ layout: RichTextLayout) -> [String] {
        layout.lines.map { $0.spans.map(\.run.text).joined() }
    }

    private static func boundaryBox(_ sample: ParagraphBoundaryReferences.Sample, on slide: Slide, x: Double, y: Double, height: Double, role: String) throws -> Shape {
        let rect = Rect(x: .inches(x), y: .inches(y), width: .points(sample.widthPoints), height: .points(height))
        try slide.shapes.addShape(.rectangle, frame: rect, fill: .none, line: Line(color: Color("276D89")))
        let box = try slide.shapes.addTextBox(rect)
        box.name = sample.id + " " + role
        let frame = try require(box.textFrame, "Boundary text frame missing")
        frame.clear()
        frame.setMargins(left: .zero, top: .zero, right: .zero, bottom: .zero)
        frame.wordWrap = true
        let paragraph = frame.addParagraph()
        paragraph.alignment = .left
        paragraph.setNoBullet()
        for (index, value) in sample.runs.enumerated() {
            let run = paragraph.addRun(value.text)
            run.fontName = value.font
            run.fontSize = value.size
            run.letterSpacing = value.tracking
            run.color = Color(index == 0 ? "276D89" : "963D61")
        }
        return box
    }

    static func boundaryPropertiesMatch(_ deck: Presentation, sample: ParagraphBoundaryReferences.Sample, role: String, fit: Autofit?) throws -> Bool {
        let name = sample.id + " " + role
        let shape = try require(deck.slides[2].shapes.all.first { $0.name == name }, "Saved boundary shape missing")
        guard let frame = shape.textFrame, let paragraph = frame.paragraphs.first,
              paragraph.runs.count == sample.runs.count, paragraph.alignment == .left,
              shape.frame.width == .points(sample.widthPoints) else { return false }
        let styles = zip(paragraph.runs.enumerated(), sample.runs).allSatisfy { pair, expected in
            let (index, run) = pair
            return run.text == expected.text && run.fontName == expected.font && run.fontSize == expected.size
                && run.letterSpacing == expected.tracking && run.color == Color(index == 0 ? "276D89" : "963D61")
        }
        let body = try paragraphBody(deck, named: name, slideAt: 2).firstChild(named: "a:bodyPr")
        let norm = body?.firstChild(named: "a:normAutofit")
        if let fit {
            let scale = Double(norm?[attribute: "fontScale"] ?? "100000").map { $0 / 1000 }
            let reduction = Double(norm?[attribute: "lnSpcReduction"] ?? "0").map { $0 / 1000 }
            return styles && norm != nil && scale == fit.fontScale && reduction == fit.lineSpacingReduction
        }
        return styles && norm != nil && norm?[attribute: "fontScale"] == nil && norm?[attribute: "lnSpcReduction"] == nil
    }
}
