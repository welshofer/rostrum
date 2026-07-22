import Foundation
import Testing
@testable import Rostrum

#if os(macOS) || os(Linux)

/// The interpreter that can `import pptx`, if any. CI installs python-pptx on
/// macOS and Linux so the oracle gate is real there; locally the suite passes
/// (and says nothing) without it.
private let pythonWithPptx: String? = {
    for python in ["python3", "python"] {
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        probe.arguments = [python, "-c", "import pptx"]
        probe.standardOutput = Pipe()
        probe.standardError = Pipe()
        do { try probe.run() } catch { continue }
        probe.waitUntilExit()
        if probe.terminationStatus == 0 { return python }
    }
    return nil
}()

/// The standing quality gate, automated: every Rostrum-written deck opens in
/// python-pptx without exception. The script walks all slides and text frames
/// so lazy part loading actually parses what we wrote.
@Suite struct PythonPptxOracleTests {
    private static let script = """
        import sys
        from pptx import Presentation
        p = Presentation(sys.argv[1])
        n = 0
        for slide in p.slides:
            n += 1
            for shape in slide.shapes:
                if shape.has_text_frame:
                    _ = shape.text_frame.text
        print(n)
        """

    private func assertOpens(_ deck: Presentation, _ name: String) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rostrum-oracle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("\(name).pptx")
        try deck.save(to: file)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [pythonWithPptx!, "-c", Self.script, file.path]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let diagnostics = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(process.terminationStatus == 0,
                "\(name): python-pptx rejected the deck: \(diagnostics)")
    }

    @Test(.enabled(if: pythonWithPptx != nil))
    func pythonPptxOpensRepresentativeDecks() throws {
        let builders = try Presentation()
        try builders.titleSlide("Oracle", subtitle: "gate", kicker: "CI")
        try builders.bulletSlide("Bullets", ["alpha", "beta"])
        try assertOpens(builders, "builders")

        let chart = try Presentation()
        try chart.chartSlide("Chart", .line,
                             ChartData(categories: ["A", "B"], name: "S", values: [1, 2]))
        try assertOpens(chart, "chart")

        let merged = try Presentation()
        let source = try Presentation()
        try source.bulletSlide("Imported", ["slide"])
        try merged.slides.importAll(from: source)
        try assertOpens(merged, "merged")
    }
}

#endif
