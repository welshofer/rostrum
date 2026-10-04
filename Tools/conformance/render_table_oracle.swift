import Foundation
import Rostrum
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let deck = try Presentation(contentsOf: source)
let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
for index in 0..<deck.slides.count {
    let result = try deck.renderSVGReportingProblems(slideAt: index, pixelWidth: 1200)
    try Data(result.svg.utf8).write(to: output.appendingPathComponent("Slide\(index + 1).svg"))
    try encoder.encode(result.problems.fidelityIssues).write(to: output.appendingPathComponent("Slide\(index + 1).issues.json"))
}
