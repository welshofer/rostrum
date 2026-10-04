import Foundation
import Rostrum

// Compile unchanged against both eras with -O -parse-as-library. Only the
// modern binary defines ROSTRUM_HAS_FIDELITY; that changes post-timing capture,
// never the render call. @main avoids requiring this file to be named main.swift.
@main
struct HistoricalRenderCompare {
    @MainActor
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 4, let iterations = Int(args[1]), (2...100).contains(iterations),
              let pixelWidth = Int(args[3]), (1...16384).contains(pixelWidth) else {
            throw NSError(domain: "HistoricalRenderCompare", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "input.pptx iterations output-prefix pixel-width required"])
        }
        let input = URL(fileURLWithPath: args[0]).standardizedFileURL
        let prefix = args[2]
        let suffixes = [".svg", "-inheritance.json", "-issues.json"]
        for suffix in suffixes {
            let output = URL(fileURLWithPath: prefix + suffix).standardizedFileURL
            guard output != input, !FileManager.default.fileExists(atPath: output.path) else {
                throw NSError(domain: "HistoricalRenderCompare", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Refusing to overwrite an input or existing artifact"])
            }
        }
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: prefix).deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let deck = try Presentation(data: Data(contentsOf: input))
        // Match rostrum-bench's pre-render first-slide/traversal preparation.
        // Fonts are deliberately never registered: its timed table render also
        // uses an empty registry (ROSTRUM_BENCH_FONT only affects text-fitting).
        var shapeCount = try deck.slides[0].shapes.count
        for slide in deck.slides { shapeCount += slide.shapes.count }
        let clock = ContinuousClock()
        var milliseconds: [Double] = []
        var svgBytes: [Int] = []
        var issueCount: Int?
        for iteration in 0..<iterations {
            let start = clock.now
            // Common public API. Omitting strictRendering compiles in the old
            // era and uses the modern API's default false; diagnostics still run.
            let result = try deck.renderSVGReportingProblems(slideAt: 0, pixelWidth: pixelWidth)
            let duration = start.duration(to: clock.now).components
            milliseconds.append(Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15)
            svgBytes.append(result.svg.utf8.count)
            if iteration == 0 {
                // All serialization and file I/O are outside the measured call.
                try result.svg.write(toFile: prefix + ".svg", atomically: true, encoding: .utf8)
                let inheritance = ["layoutUnresolved": result.problems.layoutUnresolved,
                                   "masterUnresolved": result.problems.masterUnresolved]
                try JSONSerialization.data(withJSONObject: inheritance, options: [.sortedKeys])
                    .write(to: URL(fileURLWithPath: prefix + "-inheritance.json"))
                #if ROSTRUM_HAS_FIDELITY
                issueCount = result.problems.fidelityIssues.count
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
                try encoder.encode(result.problems.fidelityIssues)
                    .write(to: URL(fileURLWithPath: prefix + "-issues.json"))
                #else
                // Unavailable is distinct from an empty modern issue list.
                try Data("null\n".utf8).write(to: URL(fileURLWithPath: prefix + "-issues.json"))
                #endif
            }
        }
        #if ROSTRUM_HAS_FIDELITY
        let supportsFidelityIssues = true
        #else
        let supportsFidelityIssues = false
        #endif
        let report: [String: Any] = [
            "milliseconds": milliseconds, "svgBytes": svgBytes,
            "slideCount": deck.slideCount, "preRenderShapeChecksum": shapeCount,
            "pixelWidth": pixelWidth, "registeredFonts": false,
            "fidelityIssuesSupported": supportsFidelityIssues,
            "fidelityIssueCount": issueCount.map { $0 as Any } ?? NSNull(),
            "preparation": "Open immutable PPTX and traverse shapes before first render",
            "timedAPI": "renderSVGReportingProblems(slideAt: 0, pixelWidth: supplied); permissive default",
        ]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]))
        FileHandle.standardOutput.write(Data([10]))
    }
}
