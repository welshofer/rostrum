import Foundation
import Rostrum
let args = CommandLine.arguments
let deck = try Presentation(contentsOf: URL(fileURLWithPath: args[1]))
let count = Int(args[2])!
let clock = ContinuousClock()
var samples: [Double] = []
for i in 0..<count {
    let start = clock.now
    let result = try deck.renderSVGReportingProblems(slideAt: 0)
    let elapsed = start.duration(to: clock.now).components
    samples.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
    if i == 0 && args.count > 3 {
        try Data(result.svg.utf8).write(to: URL(fileURLWithPath: args[3] + ".svg"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(result.problems.fidelityIssues).write(to: URL(fileURLWithPath: args[3] + ".issues.json"))
    }
}
print(samples)
