import Foundation
import Rostrum

/// Marker coordinates come from independently captured native PowerPoint PDFs.
struct ParagraphSpacingReferences: Decodable {
    struct Marker: Decodable {
        let text: String
        let x: Double
        let baseline: Double
    }
    struct Sample: Decodable {
        let id: String
        let alternative: Bool
        let title: String
        let widthPoints: Double
        let heightPoints: Double
        let source: String
        let sourceSHA256: String
        let nativePDF: String
        let nativePDFSHA256: String
        let fontSHA256: String
        let textBodyXML: String
        let nativeMarkers: [Marker]
    }
    let scope: String
    let cases: [Sample]
}

extension PlatformLabRecipes {
    static func paragraphSpacingReferences() throws -> ParagraphSpacingReferences {
        try JSONDecoder().decode(ParagraphSpacingReferences.self, from: resource("ParagraphSpacingReferences", "json"))
    }

    static func paragraphSpacing(_ deck: Presentation, alternative: Bool) throws -> (checks: [LibraryLabCheck], verify: (Presentation) throws -> [LibraryLabCheck]) {
        let samples = try paragraphSpacingReferences().cases.filter { $0.alternative == alternative }
        let slide = try deck.slides.add()
        let title = try text("Line spacing keeps its own baseline rules", on: slide,
                             in: LibraryLabSupport.frame(0.6, 0.3, 12, 0.6))
        title.textFrame?.paragraphs.first?.runs.first?.fontSize = 26
        var checks: [LibraryLabCheck] = []
        var layouts: [String: [RichTextLine]] = [:]
        for (index, sample) in samples.enumerated() {
            let x = [0.6, 4.8, 9.0][index % 3], y = index < 3 ? 1.5 : 4.2
            let heading = try text(sample.title, on: slide,
                                   in: LibraryLabSupport.frame(x, y - 0.4, 4, 0.35))
            heading.textFrame?.paragraphs.first?.runs.first?.fontSize = 14
            let rect = Rect(x: .inches(x), y: .inches(y), width: .points(sample.widthPoints), height: .points(sample.heightPoints))
            try slide.shapes.addShape(.rectangle, frame: rect, fill: .none, line: Line(color: Color("276D89")))
            let box = try slide.shapes.addTextBox(rect)
            box.name = sample.id + " spacing"
            // Exercise the public owned-DOM import path without changing native
            // spacing, compatibility, anchor, run or autofit properties.
            let imported = try XML.parse(Data(sample.textBodyXML.utf8))
            try paragraphBody(deck, named: box.name, slideAt: 5).children = imported.children
            slide.part.markDirty()
            let layout = try paragraphGeometry(deck, named: box.name, slideAt: 5)
            layouts[sample.id] = layout.lines
            checks.append(.init("Native explicit spacing: \(sample.id)",
                spacingMarkersMatch(layout, sample: sample) && layout.fits && layout.diagnostics.isEmpty,
                "All visible markers match independent native positions within 0.121 pt in the original 290 by 160 pt frame."))
            let baselines = sample.nativeMarkers.map { "\($0.text): \(String(format: "%.2f", $0.baseline)) pt" }.joined(separator: "\n")
            let note = try text("PowerPoint baselines\n" + baselines, on: slide,
                                in: LibraryLabSupport.frame(x + 0.55, y + 0.3, 3.35, 1.3))
            note.textFrame?.paragraphs.first?.runs.first?.fontSize = 12
        }
        let note = try text("Exact spacing, percentage spacing and vertical anchors use the captured baseline rules. Frames retain their original height.\nRegular DejaVu Sans; calibrated left-to-right ASCII and zero insets. Native autofit selection and general Office pixel parity remain outside this sample.",
                            on: slide, in: LibraryLabSupport.frame(0.6, 6.65, 12.1, 0.6))
        note.textFrame?.paragraphs.first?.runs.first?.fontSize = 12
        note.fitText(fonts: deck.fonts)
        let rendered = try deck.renderSVGReportingProblems(slideAt: 5)
        checks.append(.init("Explicit spacing preview has no findings", rendered.problems.isEmpty,
                            "All six native specimens and their captions render without fallback diagnostics."))
        return (checks, { reopened in
            var result: [LibraryLabCheck] = []
            for sample in samples {
                let layout = try paragraphGeometry(reopened, named: sample.id + " spacing", slideAt: 5)
                let preserved = try spacingPropertiesMatch(reopened, sample: sample)
                result.append(.init("Saved native explicit spacing: \(sample.id)",
                    spacingMarkersMatch(layout, sample: sample) && layout.lines == layouts[sample.id]
                        && layout.fits && layout.diagnostics.isEmpty && preserved,
                    "Native baselines, exact imported text-body properties and original frame dimensions survive the saved-file path."))
            }
            let saved = try reopened.renderSVGReportingProblems(slideAt: 5)
            result.append(.init("Explicit spacing SVG survives reopening", saved.svg == rendered.svg && saved.problems.isEmpty,
                                "The saved preview is byte-identical and retains zero findings."))
            return result
        })
    }

    static func spacingMarkersMatch(_ layout: RichTextLayout, sample: ParagraphSpacingReferences.Sample) -> Bool {
        let visible = layout.lines.filter { !$0.spans.isEmpty }
        return visible.count == sample.nativeMarkers.count && zip(visible, sample.nativeMarkers).allSatisfy { line, marker in
            line.spans.map(\.run.text).joined() == marker.text
                && abs(line.baseline - marker.baseline) <= 0.121
                && abs((line.spans.first?.x ?? .infinity) - marker.x) <= 0.121
        }
    }

    static func spacingPropertiesMatch(_ deck: Presentation, sample: ParagraphSpacingReferences.Sample) throws -> Bool {
        let name = sample.id + " spacing"
        let shape = try require(deck.slides[5].shapes.all.first { $0.name == name }, "Saved spacing shape missing")
        let body = try paragraphBody(deck, named: name, slideAt: 5)
        let source = try XML.parse(Data(sample.textBodyXML.utf8))
        return body.childElements.map { $0.serialized() } == source.childElements.map { $0.serialized() }
            && shape.frame.width == .points(sample.widthPoints) && shape.frame.height == .points(sample.heightPoints)
    }
}
