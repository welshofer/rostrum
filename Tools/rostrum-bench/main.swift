import Foundation
import Rostrum

// Emits one JSON sample per invocation. The Python driver repeats fresh
// processes, records RSS and computes distributions without timing the build.
struct Sample: Codable {
    var scenario: String
    var phases: [String: Double] = [:]
    var outputBytes = 0
    var slideCount = 0
    var checksum = 0
}
let args = Array(CommandLine.arguments.dropFirst())
let scenario = args.first ?? "slides-10"
// Output identity helper, outside the timed scenario path. Compile this same
// driver against each release object to compare every slide and ordered issue
// array, including renders after direct DOM edits in the unit-test suite.
if scenario == "proof", args.count == 3 {
    let deck = try Presentation(contentsOf: URL(fileURLWithPath: args[1]))
    if let paths = ProcessInfo.processInfo.environment["ROSTRUM_PROFILE_FONTS"] {
        for path in paths.split(separator: "|") {
            try deck.fonts.register(Data(contentsOf: URL(fileURLWithPath: String(path))))
        }
    }
    let directory = URL(fileURLWithPath: args[2], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let saved = try deck.serializedData()
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    for index in 0..<deck.slideCount {
        let result = try deck.renderSVGReportingProblems(slideAt: index)
        try Data(result.svg.utf8).write(to: directory.appendingPathComponent("slide-\(index).svg"))
        try encoder.encode(result.problems.fidelityIssues)
            .write(to: directory.appendingPathComponent("slide-\(index)-issues.json"))
        let inheritance = ["layoutUnresolved": result.problems.layoutUnresolved,
                           "masterUnresolved": result.problems.masterUnresolved]
        try JSONSerialization.data(withJSONObject: inheritance, options: [.sortedKeys])
            .write(to: directory.appendingPathComponent("slide-\(index)-inheritance.json"))
    }
    guard try deck.serializedData() == saved else { fatalError("render changed saved bytes") }
    try saved.write(to: directory.appendingPathComponent("saved.pptx"))
    FileHandle.standardOutput.write(Data("{\"slideCount\":\(deck.slideCount)}\n".utf8))
    exit(0)
}
var sample = Sample(scenario: scenario)
let clock = ContinuousClock()
@MainActor func measure<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
    let start = clock.now
    let result = try body()
    let d = start.duration(to: clock.now).components
    sample.phases[name] = Double(d.seconds) * 1_000 + Double(d.attoseconds) / 1e15
    return result
}
let frame = Rect(x: .inches(1), y: .inches(1), width: .inches(10), height: .inches(5))
let deck: Presentation
if scenario == "file", args.count > 1 {
    deck = try measure("open") { try Presentation(contentsOf: URL(fileURLWithPath: args[1])) }
} else {
    deck = try Presentation()
    if scenario.hasPrefix("slides-") {
        let count = Int(scenario.dropFirst(7)) ?? 10
        try measure("construct") {
            for i in 0..<count {
                let slide = i == 0 ? try deck.slides[0] : try deck.slides.add()
                let text = try slide.shapes.addTextBox(frame).textFrame!
                text.text = "Performance fixture \(i): Latin café, Ελληνικά, العربية, 中文."
                let run = text.paragraphs[0].addRun(" Mixed bold text")
                run.bold = true; run.fontSize = 24; run.fontName = "Arial"
            }
        }
    } else if scenario == "richtext-fit" {
        let text = try deck.slides[0].shapes.addTextBox(frame).textFrame!
        text.text = String(repeating: "office AV typed text café. ", count: 100)
        for run in text.paragraphs[0].runs { run.fontName = "Arial"; run.fontSize = 24 }
    } else if scenario.hasPrefix("table-") || scenario.hasPrefix("shaped-table-") {
        let size = scenario.dropFirst(scenario.hasPrefix("shaped-") ? 13 : 6).split(separator: "x").compactMap { Int($0) }
        guard size.count == 2 else { fatalError("table-ROWSxCOLS required") }
        let table = try deck.slides[0].shapes.addTable(rows: size[0], columns: size[1], frame: frame)
        measure("table-populate") { _ = table.setContents((0..<size[0]).map { r in (0..<size[1]).map { "R\(r) C\($0)" } }) }
        measure("table-style") { _ = table.styleBanded(style: deck.style).cellPadding(.points(4)) }
        if scenario.hasPrefix("shaped-") {
            for r in 0..<size[0] {
                for c in 0..<size[1] {
                    let text = try table.cell(r, c).textFrame
                    text.text = "R\(r) C\(c) office AV text"
                    for run in text.paragraphs[0].runs { run.fontName = "Arial" }
                }
            }
        }
    } else if scenario.hasPrefix("images-") {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        let slide = try deck.slides[0]
        try measure("image-insert") {
            for i in 0..<250 {
                // Distinct ancillary bytes keep the image decodable; identity
                // remains byte-based, matching the package dedup contract.
                var image = png
                if scenario == "images-unique" { image.append(contentsOf: String(i).utf8) }
                try slide.shapes.addPicture(image, frame: frame)
            }
        }
        let other = try Presentation()
        try measure("image-import") { _ = try other.slides.importAll(from: deck) }
    }
}
let bytes = try measure("initial-save") { try deck.serializedData() }
let archive = try measure("lazy-open") { try OPCArchive(data: bytes, validation: .onAccess) }
if let uri = archive.mainPartURI { _ = try measure("lazy-first-part") { try archive.xml(forPart: uri) } }
let reopened = try measure("reopen") { try Presentation(data: bytes) }
try measure("first-slide") { sample.checksum += try reopened.slides[0].shapes.count }
measure("traversal") { for slide in reopened.slides { sample.checksum += slide.shapes.count } }
if scenario.hasPrefix("shaped-") || scenario == "richtext-fit" {
    guard let fontPath = ProcessInfo.processInfo.environment["ROSTRUM_BENCH_FONT"] else {
        fatalError("registered-font scenarios require ROSTRUM_BENCH_FONT")
    }
    try reopened.fonts.register(Data(contentsOf: URL(fileURLWithPath: fontPath)))
    if scenario == "richtext-fit", let text = try reopened.slides[0].shapes.first(where: { $0.textFrame != nil })?.textFrame {
        measure("richtext-fitting") {
            sample.checksum += Int(text.fitText(in: frame, fonts: reopened.fonts).fontScale)
        }
    }
}
let svg = try measure("render") { try reopened.renderSVG(slideAt: 0) }
sample.checksum += svg.utf8.count
let saved = try measure("unchanged-save") { try reopened.serializedData() }
let second = try measure("warm-unchanged-save") { try reopened.serializedData() }
guard saved == second else { fatalError("non-deterministic save") }
if let table = try reopened.slides[0].shapes.compactMap({ ($0 as? TableFrame)?.table }).first {
    let edited = try measure("one-cell-edit-save") { () -> Data in
        try table.cell(0, 0).text = "edited"
        return try reopened.serializedData()
    }
    let check = try Presentation(data: edited)
    guard try (Array(check.slides[0].shapes).first as? TableFrame)?.table?.cell(0, 0).text == "edited" else {
        fatalError("edited cell did not survive")
    }
}
if let fontPath = ProcessInfo.processInfo.environment["ROSTRUM_BENCH_FONT"] {
    let metrics = try FontMetrics(contentsOf: URL(fileURLWithPath: fontPath))
    measure("text-fitting") {
        let result = TextMeasurer(metrics).autofit(paragraphs: [(String(repeating: "Mixed café typography ", count: 100), 24)], width: 600, height: 300)
        sample.checksum += Int(result.fontScale)
    }
}
sample.outputBytes = saved.count
sample.slideCount = reopened.slideCount
if let output = ProcessInfo.processInfo.environment["ROSTRUM_BENCH_OUTPUT"] {
    try saved.write(to: URL(fileURLWithPath: output), options: .atomic)
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(sample))
FileHandle.standardOutput.write(Data([10]))
