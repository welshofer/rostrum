import Foundation
import LecternCore

// Offline, deterministic content. No provider, secret or network dependency.
@main struct CompositionRegression {
    static func fixture() -> DeckIR {
        DeckIR(meta: Meta(title: "Composition acceptance"), slides: [
            IRSlide(id: "cover", layout: "title", title: "Better decisions start with clear evidence", body: Body(subtitle: "Editable native content · visual regression fixture")),
            IRSlide(id: "metrics", layout: "metrics", title: "Three measures explain the change", body: Body(stats: [.init(value: "31%", label: "First group"), .init(value: "17%", label: "Second group"), .init(value: "14 pts", label: "Difference")], source: "Synthetic regression data; not a factual claim.")),
            IRSlide(id: "timeline", layout: "timeline", title: "Move from evidence to a decision", body: Body(milestones: [.init(label: "Observe", detail: "Collect the facts"), .init(label: "Compare", detail: "Evaluate alternatives"), .init(label: "Decide", detail: "Choose a next step")])),
            IRSlide(id: "process", layout: "diagram", title: "A repeatable process", body: Body(diagram: .init(kind: "process", items: ["Collect", "Evaluate", "Act"]))),
            IRSlide(id: "cycle", layout: "diagram", title: "Learning feeds the next decision", body: Body(diagram: .init(kind: "cycle", items: ["Observe", "Test", "Measure", "Learn"]))),
            IRSlide(id: "pyramid", layout: "diagram", title: "Build on a sound foundation", body: Body(diagram: .init(kind: "pyramid", items: ["Decision", "Analysis", "Evidence"]))),
            IRSlide(id: "quadrant", layout: "quadrant", title: "Consider impact and effort", body: Body(quadrants: [.init(heading: "Quick wins", detail: "High impact, low effort"), .init(heading: "Invest", detail: "High impact, high effort"), .init(heading: "Maintain", detail: "Low impact, low effort"), .init(heading: "Reconsider", detail: "Low impact, high effort")], xAxis: "Effort increases →", yAxis: "Impact increases ↑")),
            IRSlide(id: "bands", layout: "bands", title: "Three priorities", body: Body(items: ["Preserve the evidence", "Make the choice clear", "Agree on the next action"])),
            IRSlide(id: "chart", layout: "chart", title: "Compare groups using a common scale", body: Body(chart: .init(kind: "bar", categories: ["Group A", "Group B", "Group C"], series: [.init(name: "Share (%)", values: [31, 17, 25])]), source: "Synthetic regression data; the labels and values must remain editable.")),
            IRSlide(id: "table", layout: "table", title: "Definitions need room to breathe", body: Body(table: .init(headers: ["Term", "Meaning", "Example"], rows: [["Anomaly", "Difference from a baseline", "Temperature above reference"], ["Adaptation", "Reduce harm from impacts", "Heat-health action plans"], ["Net zero", "Emissions balanced by removals", "Balance residual emissions"]]), source: "Regression vocabulary; inspect wrapped rows and source clearance.")),
            IRSlide(id: "comparison", layout: "comparison", title: "Keep the alternatives distinct", body: Body(left: .init(heading: "First approach", bullets: ["A short statement", "A second supporting fact"]), right: .init(heading: "Second approach", bullets: ["Another statement", "A different supporting fact"]))),
            IRSlide(id: "image-fit", layout: "bullets", title: "Preserve every part of an explanatory image", body: Body(bullets: [.init(text: "Check all four corner labels."), .init(text: "Keep the original image aspect ratio.")]), image: ImageBrief(prompt: "Edge-label calibration diagram", aspect: "16:9")),
            IRSlide(id: "closing", layout: "closing", title: "Choose the next action", body: Body(callToAction: "Name an owner and a date."))
        ])
    }
    static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("Composition regression failed: \(error)\n".utf8))
            exit(1)
        }
    }
    enum Failure: Error, CustomStringConvertible {
        case usage(String)
        var description: String { switch self { case .usage(let message): return message } }
    }
    static func run() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let output = args.first else {
            throw Failure.usage("Usage: CompositionRegression OUTPUT [template.potx | design.md ...] [--replay deck.json]")
        }
        let root = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var deck = fixture(), images: [String: Data] = ["image-fit": try Data(contentsOf: Bundle.module.url(forResource: "image-fit", withExtension: "png", subdirectory: "Resources")!)], styles: [String] = []
        var i = 1
        while i < args.count {
            if args[i] == "--replay" {
                guard i + 1 < args.count else { throw Failure.usage("--replay requires a saved-content file") }
                let data = try Data(contentsOf: URL(fileURLWithPath: args[i + 1]))
                if let snapshot = try? JSONDecoder().decode(RenderSnapshot.self, from: data) { deck = snapshot.deck; images = snapshot.images }
                else { deck = try JSONDecoder().decode(DeckIR.self, from: data); images = [:] }
                i += 2
            } else { styles.append(args[i]); i += 1 }
        }
        if styles.isEmpty { styles = [""] }
        var records: [[String: Any]] = []
        for (n, path) in styles.enumerated() {
            let file = URL(fileURLWithPath: path)
            let isTemplate = file.pathExtension.lowercased() == "potx"
            let template = isTemplate ? try PowerPointTemplate(data: Data(contentsOf: file), name: file.lastPathComponent) : nil
            let directory = root.appendingPathComponent("\(n + 1)-" + (path.isEmpty ? "default" : file.deletingPathExtension().lastPathComponent))
            let start = Date()
            do {
                let result = try await DeckRenderer().render(deck, designURL: isTemplate || path.isEmpty ? nil : file,
                    notesEnabled: true, into: directory, images: images, template: template)
                let renderSeconds = Date().timeIntervalSince(start)
                let snapshot = RenderSnapshot(deck: deck, images: images, design: isTemplate || path.isEmpty ? nil : try String(contentsOf: file, encoding: .utf8), template: template)
                let saved = try snapshot.save(in: directory)
                records.append(["deck": result.url.path, "snapshot": saved.path, "slides": result.slideCount,
                    "renderSeconds": renderSeconds, "schemaIssues": result.schemaIssues,
                    "warnings": result.warnings, "missingFonts": result.unmeasuredFonts,
                    "visualStatus": "needs-powerpoint-review"])
                print("Wrote \(result.slideCount) slides: \(result.url.path)")
            } catch {
                records.append(["style": path, "error": String(describing: error), "visualStatus": "render-failed"])
                print("FAILED \(path): \(error)")
            }
        }
        let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("manifest.json"))
        if records.contains(where: { $0["error"] != nil }) { throw Failure.usage("One or more styles failed; see manifest.json for the rendering error") }
    }
}
