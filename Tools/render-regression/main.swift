import Foundation
import Rostrum

let args = Array(CommandLine.arguments.dropFirst())
let scenario = args.first ?? "table-banded"
let iterations = args.count > 1 ? Int(args[1])! : 12
let output = args.count > 2 ? args[2] : "/tmp/isolated-render"
let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(10), height: .inches(5))
let deck: Presentation
if scenario.hasPrefix("file:") {
    deck = try Presentation(contentsOf: URL(fileURLWithPath: String(scenario.dropFirst(5))))
} else {
    deck = try Presentation()
    if scenario.hasPrefix("table-") {
        let table = try deck.slides[0].shapes.addTable(rows: 200, columns: 50, frame: frame)
        table.setContents((0..<200).map { r in (0..<50).map { "R\(r) C\($0)" } })
        if scenario == "table-grid" { table.applyBuiltInStyle(.noStyleTableGrid) }
        else { table.styleBanded(style: deck.style).cellPadding(.points(4)) }
    } else {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        for i in 0..<250 {
            var image = png
            if scenario == "images-unique" { image.append(contentsOf: String(i).utf8) }
            try deck.slides[0].shapes.addPicture(image, frame: frame)
        }
    }
}
if let fonts = ProcessInfo.processInfo.environment["ROSTRUM_PROFILE_FONTS"] {
    for path in fonts.split(separator: "|") {
        try deck.fonts.register(Data(contentsOf: URL(fileURLWithPath: String(path))))
    }
}
let clock = ContinuousClock()
var samples: [Double] = []
for iteration in 0..<iterations {
    let start = clock.now
    let result = try deck.renderSVGReportingProblems(slideAt: 0, pixelWidth: 1200)
    let duration = start.duration(to: clock.now).components
    samples.append(Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15)
    if iteration == 0 {
        try result.svg.write(toFile: output + ".svg", atomically: true, encoding: .utf8)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(result.problems.fidelityIssues).write(to: URL(fileURLWithPath: output + "-issues.json"))
        try JSONSerialization.data(withJSONObject: ["layoutUnresolved": result.problems.layoutUnresolved, "masterUnresolved": result.problems.masterUnresolved], options: [.sortedKeys]).write(to: URL(fileURLWithPath: output + "-inheritance.json"))
    }
}
let report: [String: Any] = ["scenario": scenario, "millisecondsIncludingWarmup": samples]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]))
FileHandle.standardOutput.write(Data([10]))
