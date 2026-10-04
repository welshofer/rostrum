import Foundation
import Rostrum

/// Owned DrawingML specimens and marker positions captured independently in PowerPoint.
struct ParagraphBreakReferences: Decodable {
    struct Marker: Decodable { let text: String; let baseline: Double }
    struct Sample: Decodable {
        let id: String
        let large: Bool
        let title: String
        let widthPoints: Double
        let heightPoints: Double
        let textBodyXML: String
        let nativeMarkers: [Marker]
    }
    let source: String
    let sourceSHA256: String
    let nativePDF: String
    let nativePDFSHA256: String
    let fontSHA256: String
    let scope: String
    let cases: [Sample]
}

extension PlatformLabRecipes {
    // The source uses a 160 pt frame. Top alignment keeps its marker origins
    // unchanged in this shorter display frame, whose height still exceeds 72 pt.
    static let breakDisplayHeight = 120.0

    static func paragraphBreakReferences() throws -> ParagraphBreakReferences {
        try JSONDecoder().decode(ParagraphBreakReferences.self, from: resource("ParagraphBreakReferences", "json"))
    }

    static func paragraphBreaks(_ deck: Presentation, large: Bool) throws -> (checks: [LibraryLabCheck], verify: (Presentation) throws -> [LibraryLabCheck]) {
        let samples = try paragraphBreakReferences().cases.filter { $0.large == large }
        let slide = try deck.slides.add()
        let title = try text("Empty lines keep their own typography", on: slide, in: LibraryLabSupport.frame(0.6, 0.3, 12, 0.6))
        title.textFrame?.paragraphs.first?.runs.first?.fontSize = 26
        for (x, label) in [(0.6, "Original spacing"), (4.8, "Fit in shape"), (9.0, "Fit in text frame")] {
            let heading = try text(label, on: slide, in: LibraryLabSupport.frame(x, 1.0, 3.8, 0.5))
            heading.textFrame?.paragraphs.first?.runs.first?.fontSize = 20
        }
        var checks: [LibraryLabCheck] = []
        var layouts: [String: [RichTextLine]] = [:]
        var fits: [String: Autofit] = [:]
        for (row, sample) in samples.enumerated() {
            let y = row == 0 ? 1.9 : 4.3
            let caption = try text(sample.title, on: slide, in: LibraryLabSupport.frame(0.6, y - 0.45, 12, 0.4))
            caption.textFrame?.paragraphs.first?.runs.first?.fontSize = 15
            let original = try breakBox(sample, deck: deck, on: slide, x: 0.6, y: y, height: breakDisplayHeight, role: "original")
            let shape = try breakBox(sample, deck: deck, on: slide, x: 4.8, y: y, height: 28, role: "shape fit")
            let frame = try breakBox(sample, deck: deck, on: slide, x: 9.0, y: y, height: 28, role: "frame fit")
            let selected = try require(shape.fitText(fonts: deck.fonts, theme: deck.theme), "Break shape fit missing")
            let selectedFrame = try require(frame.textFrame, "Break text frame missing")
                .fitText(in: frame.frame, fonts: deck.fonts, theme: deck.theme)
            let natural = try paragraphGeometry(deck, named: original.name, slideAt: 4)
            let shapeLayout = try paragraphGeometry(deck, named: shape.name, slideAt: 4)
            let frameLayout = try paragraphGeometry(deck, named: frame.name, slideAt: 4)
            layouts[original.name] = natural.lines
            layouts[shape.name] = shapeLayout.lines
            layouts[frame.name] = frameLayout.lines
            fits[shape.name] = selected
            fits[frame.name] = selectedFrame
            checks += [
                .init("Native empty-line spacing: \(sample.id)", breakMarkersMatch(natural, sample: sample) && natural.fits && natural.diagnostics.isEmpty, "Every visible marker matches the independently captured native baseline within 0.121 pt. The empty line retains its own metrics."),
                .init("Public break fits: \(sample.id)", selected == selectedFrame && selected.fits && selected.fontScale < 100 && shapeLayout.lines == frameLayout.lines && shapeLayout.fits && shapeLayout.diagnostics.isEmpty && boundaryLineStrings(shapeLayout) == boundaryLineStrings(natural), "Both public fitting paths preserve the manual empty line and visible text, selecting \(selected.fontScale)% scale and \(selected.lineSpacingReduction)% line-spacing reduction.")
            ]
            let baselines = sample.nativeMarkers.map { "\($0.text): \(String(format: "%.2f", $0.baseline)) pt" }.joined(separator: "; ")
            let nativeNote = try text("PowerPoint baselines\n" + baselines, on: slide, in: LibraryLabSupport.frame(1.2, y + 0.55, 3.1, 0.75))
            nativeNote.textFrame?.paragraphs.first?.runs.first?.fontSize = 12
            for x in [4.8, 9.0] {
                let note = try text("Computed scale: \(selected.fontScale)%\nEmpty-line formatting is preserved.", on: slide, in: LibraryLabSupport.frame(x, y + 0.55, 3.8, 0.75))
                note.textFrame?.paragraphs.first?.runs.first?.fontSize = 13
            }
        }
        let note = try text("The alternative selects 36 pt empty lines; the default selects 6 pt empty lines. Authored markers are 12 pt; fitted copies apply the displayed scale.\nOwned DrawingML breaks and paragraph-end properties; regular DejaVu Sans, top alignment, zero insets. Slide 6 demonstrates bounded exact/percentage spacing. Native-selected autofit remains separate fidelity work.", on: slide, in: LibraryLabSupport.frame(0.6, 6.85, 12.1, 0.6))
        note.textFrame?.paragraphs.first?.runs.first?.fontSize = 12
        note.fitText(fonts: deck.fonts)
        let svg = try deck.renderSVG(slideAt: 4)
        return (checks, { reopened in
            var result: [LibraryLabCheck] = []
            for sample in samples {
                let natural = try paragraphGeometry(reopened, named: sample.id + " original", slideAt: 4)
                var preserved = true
                for role in ["original", "shape fit", "frame fit"] {
                    let name = sample.id + " " + role
                    let layout = try paragraphGeometry(reopened, named: name, slideAt: 4)
                    let properties = try breakPropertiesMatch(reopened, sample: sample, role: role, fit: fits[name])
                    preserved = preserved && layout.lines == layouts[name] && properties
                }
                result += [
                    .init("Saved native empty-line spacing: \(sample.id)", breakMarkersMatch(natural, sample: sample), "The saved-file path retains the independent PowerPoint marker positions."),
                    .init("Saved break properties and fits: \(sample.id)", preserved, "All imported paragraphs, break and paragraph-end properties, inherited list defaults and chosen autofit attributes survive reopening with identical layout.")
                ]
            }
            result.append(.init("Break SVG survives reopening", try reopened.renderSVG(slideAt: 4) == svg, "The saved empty-line slide preview is byte-identical."))
            return result
        })
    }

    private static func breakBox(_ sample: ParagraphBreakReferences.Sample, deck: Presentation, on slide: Slide, x: Double, y: Double, height: Double, role: String) throws -> Shape {
        let rect = Rect(x: .inches(x), y: .inches(y), width: .points(sample.widthPoints), height: .points(height))
        try slide.shapes.addShape(.rectangle, frame: rect, fill: .none, line: Line(color: Color("276D89")))
        let box = try slide.shapes.addTextBox(rect)
        box.name = sample.id + " " + role
        // a:br has no dedicated authoring wrapper. Exercise the public owned-DOM
        // import path, retaining the independent specimen's exact properties.
        let imported = try XML.parse(Data(sample.textBodyXML.utf8))
        let body = try paragraphBody(deck, named: box.name, slideAt: 4)
        body.children = imported.children
        slide.part.markDirty()
        return box
    }

    static func breakMarkersMatch(_ layout: RichTextLayout, sample: ParagraphBreakReferences.Sample) -> Bool {
        let visible = layout.lines.filter { !$0.spans.isEmpty }
        return visible.count == sample.nativeMarkers.count && zip(visible, sample.nativeMarkers).allSatisfy { line, marker in
            line.spans.map(\.run.text).joined() == marker.text && abs(line.baseline - marker.baseline) <= 0.121
        }
    }

    static func breakPropertiesMatch(_ deck: Presentation, sample: ParagraphBreakReferences.Sample, role: String, fit: Autofit?) throws -> Bool {
        let name = sample.id + " " + role
        let shape = try require(deck.slides[4].shapes.all.first { $0.name == name }, "Saved break shape missing")
        let body = try paragraphBody(deck, named: name, slideAt: 4)
        let source = try XML.parse(Data(sample.textBodyXML.utf8))
        let contentNames = ["a:lstStyle", "a:p"]
        guard body.childElements.filter({ contentNames.contains($0.name) }).map({ $0.serialized() })
            == source.childElements.filter({ contentNames.contains($0.name) }).map({ $0.serialized() }),
              shape.frame.width == .points(sample.widthPoints),
              shape.frame.height == .points(fit == nil ? breakDisplayHeight : 28),
              let properties = body.firstChild(named: "a:bodyPr"),
              ["lIns", "rIns", "tIns", "bIns"].allSatisfy({ properties[attribute: $0] == "0" }),
              properties[attribute: "anchor"] == "t", properties[attribute: "wrap"] == "square" else { return false }
        let norm = properties.firstChild(named: "a:normAutofit")
        if let fit {
            let scale = Double(norm?[attribute: "fontScale"] ?? "100000").map { $0 / 1000 }
            let reduction = Double(norm?[attribute: "lnSpcReduction"] ?? "0").map { $0 / 1000 }
            return norm != nil && scale == fit.fontScale && reduction == fit.lineSpacingReduction
                && properties.firstChild(named: "a:noAutofit") == nil
        }
        return norm == nil && properties.firstChild(named: "a:noAutofit") != nil
    }
}
