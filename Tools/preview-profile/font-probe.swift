// Compile with the production InstalledFonts.swift and the selected Rostrum build.
import Foundation
import Rostrum
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main struct FontProbe {
    struct Input: Decodable {
        let paths: [String]
        let families: [String]
    }
    struct Sample: Encodable {
        let stage: String
        let elapsedSeconds: Double
        let cpuSeconds: Double
    }
    struct Report: Encodable {
        let stages: [Sample]
        let peakRSSBytes: Int
    }
    static func main() throws {
        precondition(CommandLine.arguments.count == 3)
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf:
            URL(fileURLWithPath: CommandLine.arguments[1])))
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let urls = input.paths.map { URL(fileURLWithPath: $0) }
        var samples: [Sample] = []
        for operation in 1...2 {
            let deck = try Presentation()
            let cpu = Double(clock()) / Double(CLOCKS_PER_SEC)
            let start = ProcessInfo.processInfo.systemUptime
            // Fresh lookup/parsed-file state each time; only candidate discovery
            // is injected. File reads, validation and registration are production.
            let report = InstalledFonts.Session(candidates: { _ in urls.map { .init(url: $0) } }, officeDirectories: [])
                .register(in: deck, families: input.families)
            samples.append(Sample(stage: "registration\(operation)",
                elapsedSeconds: ProcessInfo.processInfo.systemUptime - start,
                cpuSeconds: Double(clock()) / Double(CLOCKS_PER_SEC) - cpu))

            var registered: [[String: Any]] = []
            for family in input.families {
                let slide = try deck.slides.add()
                for (index, style) in InstalledFonts.styles.enumerated() {
                    let face = FontFaceKey(family: family, bold: style.bold, italic: style.italic)
                    let shape = try slide.shapes.addTextBox(Rect(x: .points(30), y: .points(Double(30 + index * 70)),
                        width: .points(450), height: .points(65)))
                    let run = shape.textFrame!.addParagraph().addRun("AV office café x́ — 123.45 العربية")
                    run.fontName = family; run.fontSize = 18; run.bold = style.bold; run.italic = style.italic
                    if let metrics = deck.fonts.metrics(for: face) {
                        let bytes = deck.fonts.data(for: face)!
                        let unchanged = try urls.contains { try Data(contentsOf: $0) == bytes }
                        precondition(unchanged)
                        registered.append(["family": family, "bold": style.bold, "italic": style.italic,
                            "names": metrics.familyNames, "upem": metrics.unitsPerEm,
                            "advances": "AV office café x́ العربية".unicodeScalars.map { metrics.advance(of: $0) }])
                    }
                }
            }
            let prefix = directory.appendingPathComponent("operation-\(operation)")
            try deck.save(to: prefix.appendingPathExtension("pptx"))
            var diagnostics: [[FidelityIssue]] = []
            for index in 0..<deck.slides.count {
                let rendered = try deck.renderSVGReportingProblems(slideAt: index)
                try rendered.svg.write(to: directory.appendingPathComponent("operation-\(operation)-slide-\(index + 1).svg"), atomically: true, encoding: .utf8)
                diagnostics.append(rendered.problems.fidelityIssues)
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(diagnostics).write(to: prefix.appendingPathExtension("diagnostics.json"))
            try JSONSerialization.data(withJSONObject: ["registered": registered, "missing": report.missing,
                "approximations": report.approximations], options: [.sortedKeys])
                .write(to: prefix.appendingPathExtension("registration.json"))
        }
        var usage = rusage()
        #if canImport(Darwin)
        precondition(getrusage(RUSAGE_SELF, &usage) == 0)
        let rss = Int(usage.ru_maxrss)
        #else
        precondition(getrusage(__rusage_who_t(RUSAGE_SELF.rawValue), &usage) == 0)
        let rss = Int(usage.ru_maxrss) * 1024
        #endif
        print(String(decoding: try JSONEncoder().encode(Report(stages: samples, peakRSSBytes: rss)), as: UTF8.self))
    }
}
