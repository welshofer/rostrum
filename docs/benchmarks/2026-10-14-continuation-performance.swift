import Foundation
import Rostrum
import LecternCore
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Compile against the same Release modules/objects before and after the change.
// Runs the production renderer without a model or network request.
@main struct ContinuationPerformanceSpecimen {
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let name = CommandLine.arguments[2]
        func facts(_ prefix: String, _ count: Int) -> [String] {
            (1...count).map { "\(prefix) \($0): preserve the complete evidence and its original wording while keeping the presentation readable." }
        }
        let slides: [IRSlide]
        switch name {
        case "comparison":
            slides = [IRSlide(id: "a", layout: "comparison", title: "Two views of the evidence", body: Body(
                left: .init(heading: "Detailed observations", bullets: facts("Left", 17)),
                right: .init(heading: "Summary observations", bullets: facts("Right", 3))), notes: "Keep these speaker notes.")]
        case "cited-dense":
            slides = [IRSlide(id: "a", layout: "bullets", title: "Cited evidence", body: Body(
                bullets: facts("Fact", 25).map { Bullet(text: $0) }, source: "Research notes."), notes: "Keep these speaker notes.")]
        case "dense":
            slides = [IRSlide(id: "a", layout: "bullets", title: "Evidence", body: Body(
                bullets: facts("Fact", 25).map { Bullet(text: $0) }), notes: "Keep these speaker notes.")]
        case "repeated-source":
            slides = (1...8).map { IRSlide(id: "a-\($0)", layout: "closing", title: "Evidence \($0)", body: Body(
                callToAction: "Keep context, evaluation and provenance connected.",
                source: String(repeating: "Synthetic source: Workflow research and implementation guide; reference edition, chapters 2, 4, 7 and 9, pages 18–29 and 34–42. ", count: 2))) }
        case "table":
            slides = [IRSlide(id: "a", layout: "table", title: "Evidence", body: Body(table: .init(
                headers: ["ID", "Observation", "Value"], rows: (1...24).map { ["R\($0)", "Preserve complete native cell geometry and every original word.", "1,234"] })))]
        case "source":
            slides = [IRSlide(id: "a", layout: "closing", title: "Make the workflow explicit", body: Body(
                callToAction: "Keep context, evaluation and provenance connected.",
                source: String(repeating: "Synthetic source: Workflow research and implementation guide; reference edition, chapters 2, 4, 7 and 9, pages 18–29 and 34–42. ", count: 2)), notes: "Keep these speaker notes.")]
        case "long-source":
            slides = [IRSlide(id: "a", layout: "chart", title: "Evidence", body: Body(
                chart: .init(kind: "bar", categories: ["A", "B"], series: [.init(name: "Value", values: [1, 2])]),
                source: facts("Source", 16).joined(separator: " ")), notes: "Keep these speaker notes.")]
        default:
            slides = [IRSlide(id: "a", layout: "bullets", title: "Already fits", body: Body(
                bullets: [Bullet(text: "One short observation."), Bullet(text: "Another short observation.")])),
                IRSlide(id: "b", layout: "comparison", title: "Balanced", body: Body(
                    left: .init(heading: "Left", bullets: ["First observation."]),
                    right: .init(heading: "Right", bullets: ["Second observation."])))]
        }
        let input = DeckIR(meta: Meta(title: "Continuation \(name)"),
            sections: [.init(id: "evidence", title: "Evidence", slideIds: slides.map(\.id))], slides: slides)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let wall = DispatchTime.now().uptimeNanoseconds, cpu = clock()
        let result = try await DeckRenderer().render(input, designURL: nil, notesEnabled: true, into: root)
        let cpuSeconds = Double(clock() - cpu) / Double(CLOCKS_PER_SEC)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - wall) / 1e9
        let content = try RenderContentCheck.inspect(result.url, expected: input)
        precondition(result.schemaIssues.isEmpty && result.droppedContent.isEmpty && content.issues.isEmpty)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(input).write(to: root.appendingPathComponent("input.json"))
        try Data(contentsOf: result.url).write(to: root.appendingPathComponent("saved.pptx"))
        for (index, svg) in result.previews.enumerated() {
            try Data(svg.utf8).write(to: root.appendingPathComponent("slide-\(index + 1).svg"))
        }
        let diagnosticRecord: [String: Any] = ["warnings": result.warnings, "schemaIssues": result.schemaIssues,
            "droppedContent": result.droppedContent, "missingFonts": result.unmeasuredFonts,
            "previewWarnings": result.previewWarnings, "previewTitles": result.previewTitles,
            "previewSlideNumbers": result.previewSlideNumbers,
            "previewDiagnostics": result.previewDiagnostics.map { d -> [String: Any] in
                ["slideNumber": d.slideNumber, "layoutUnresolved": d.layoutUnresolved,
                 "masterUnresolved": d.masterUnresolved, "failure": d.failure as Any? ?? NSNull(),
                 "messages": d.messages, "issues": d.issues.map { issue in
                     ["code": issue.code, "impact": issue.impact, "message": issue.message,
                      "partURI": issue.partURI, "shapeID": issue.shapeID as Any? ?? NSNull(), "path": issue.path] }]
            }]
        try JSONSerialization.data(withJSONObject: diagnosticRecord, options: [.sortedKeys, .prettyPrinted])
            .write(to: root.appendingPathComponent("diagnostics.json"))
        let record: [String: Any] = ["case": name, "slides": result.slideCount, "cpuSeconds": cpuSeconds,
            "elapsedSeconds": elapsed, "missingFonts": result.unmeasuredFonts,
            "warnings": result.warnings, "contentIssues": content.issues.map { String(describing: $0) }]
        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted])
        try data.write(to: root.appendingPathComponent("result.json"))
        print(String(decoding: data, as: UTF8.self))
    }
}
