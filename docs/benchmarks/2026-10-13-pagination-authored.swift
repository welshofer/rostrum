import Foundation
import Rostrum
import LecternCore

// Production authored continuation, inspector and export preservation specimen.
// Compile against Lectern's Debug modules/objects, with -parse-as-library.
@main struct AuthoredPaginationSpecimen {
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        func facts(_ prefix: String, _ count: Int) -> [String] {
            (0..<count).map { "\(prefix) \($0): exact evidence é e\u{301} remains readable across continuation slides without losing source words." }
        }
        let input = DeckIR(meta: Meta(title: "Authored continuation evidence"),
            sections: [.init(id: "s", title: "Evidence", slideIds: ["agenda", "bullets", "comparison", "image"])],
            slides: [
                IRSlide(id: "agenda", layout: "agenda", title: "Agenda", body: Body(items: facts("Agenda", 20)), notes: "Agenda notes"),
                IRSlide(id: "bullets", layout: "bullets", title: "Evidence", body: Body(bullets: facts("Fact", 24).map { Bullet(text: $0) },
                    lead: "A source-preserving introduction.", source: "Original source."), notes: "Evidence notes"),
                IRSlide(id: "comparison", layout: "comparison", title: "Two views", body: Body(
                    left: .init(heading: "Left evidence", bullets: facts("Left", 14)),
                    right: .init(heading: "Right evidence", bullets: facts("Right", 11))), notes: "Comparison notes"),
                IRSlide(id: "image", layout: "imageRight", title: "Illustrated evidence", body: Body(
                    bullets: facts("Image", 12).map { Bullet(text: $0) }), notes: "Image notes",
                    image: .init(prompt: "Offline specimen"))
            ])
        // A fixed valid one-pixel PNG; no generated or network resources.
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: true,
            into: root, images: ["image": png])
        precondition(result.schemaIssues.isEmpty && result.droppedContent.isEmpty)
        try Data(contentsOf: result.url).write(to: root.appendingPathComponent("saved.pptx"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(input).write(to: root.appendingPathComponent("input.json"))
        let report: [String: Any] = ["slide_count": result.slideCount, "warnings": result.warnings,
            "schema_issues": result.schemaIssues, "dropped_content": result.droppedContent,
            "unmeasured_fonts": result.unmeasuredFonts, "preview_warnings": result.previewWarnings,
            "preview_titles": result.previewTitles, "preview_slide_numbers": result.previewSlideNumbers,
            "diagnostics": result.previewDiagnostics.map { d in
                ["slide_number": d.slideNumber, "failure": d.failure ?? "", "messages": d.messages,
                 "layout_unresolved": d.layoutUnresolved, "master_unresolved": d.masterUnresolved,
                 "issues": d.issues.map { i in
                    ["code": i.code, "impact": i.impact, "message": i.message, "part": i.partURI,
                     "shape": i.shapeID ?? "", "path": i.path]
                 }] as [String: Any]
            }]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
            .write(to: root.appendingPathComponent("report.json"))
        for (index, svg) in result.previews.enumerated() {
            try Data(svg.utf8).write(to: root.appendingPathComponent("slide-\(index).svg"))
        }
        print("Saved \(result.slideCount) slides; \(result.schemaIssues.count) schema issues; \(result.droppedContent.count) dropped content")
    }
}
