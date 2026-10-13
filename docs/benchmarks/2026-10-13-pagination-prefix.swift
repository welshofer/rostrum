import Foundation
import Rostrum
import RostrumLayout
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// mode(count|paragraphs|text), item count, capacity(count) or height(points),
// trial count, optional artifact directory. Run from the repository root.
let mode = CommandLine.arguments[1], count = Int(CommandLine.arguments[2])!
let capacity = Double(CommandLine.arguments[3])!, trials = Int(CommandLine.arguments[4])!
let deck = try Presentation()
deck.theme.minorFont = "DejaVu Sans"
for name in ["DejaVuSans", "DejaVuSans-Bold"] {
    try deck.fonts.register(contentsOf: URL(fileURLWithPath:
        "Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/\(name).ttf"))
}
let engine = TemplateLayoutEngine(presentation: deck)
var style = deck.style
style.type = style.type.overriding(.body) {
    $0.font = "DejaVu Sans"; $0.sizePt = 18; $0.lineHeight = 1.2
}
let values = (0..<count).map { index in
    mode == "text" ? "Word\(index) é e\u{301}\(index % 7 == 0 ? "\n" : "  ")"
        : "Item \(index): " + String(repeating: "Exact evidence stays readable. ", count: index % 3 + 1)
}
let originalText = values.joined()
func milliseconds(_ clock: clockid_t) -> Double {
    var value = timespec()
    precondition(clock_gettime(clock, &value) == 0)
    return Double(value.tv_sec) * 1000 + Double(value.tv_nsec) / 1e6
}
var samples: [[String: Any]] = [], accepted: [[String]] = []
for trial in 0..<trials {
    var calls = 0, visitedItems = 0
    let cpu = milliseconds(CLOCK_PROCESS_CPUTIME_ID), start = milliseconds(CLOCK_MONOTONIC)
    if mode == "text" {
        accepted = try MeasuredPaginator.text(originalText) { text in
            calls += 1
            return engine.measuredHeight(text, style: style.type(.body), width: 520) <= capacity
        }.map { [$0] }
    } else {
        accepted = try MeasuredPaginator.pages(values) { prefix in
            calls += 1; visitedItems += prefix.count
            return mode == "count" ? prefix.count <= Int(capacity)
                : engine.measuredHeight(prefix.joined(separator: "\n"), style: style.type(.body), width: 520) <= capacity
        }
    }
    samples.append(["trial": trial, "cpu_ms": milliseconds(CLOCK_PROCESS_CPUTIME_ID) - cpu,
        "elapsed_ms": milliseconds(CLOCK_MONOTONIC) - start, "calls": calls,
        "visited_items": visitedItems, "pages": accepted.count])
    if mode == "text" { precondition(accepted.flatMap { $0 }.joined().utf8.elementsEqual(originalText.utf8)) }
    else { precondition(accepted.flatMap { $0 } == values) }
}
if CommandLine.arguments.count > 5 {
    let directory = URL(fileURLWithPath: CommandLine.arguments[5])
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: accepted, options: [.sortedKeys])
        .write(to: directory.appendingPathComponent("pages.json"))
    let frame = Rect(x: .points(48), y: .points(96), width: .points(520), height: .points(capacity))
    for (index, page) in accepted.enumerated() {
        let slide = try deck.slides.add()
        try slide.addText("Evidence — page \(index + 1)", in: Rect(x: .points(48), y: .points(24),
            width: .points(520), height: .points(48)), role: .heading, style: style)
        try slide.addText(page.joined(separator: "\n"), in: frame, role: .body, style: style)
        try slide.setNotes("Original words and ordering retained.")
    }
    let bytes = try deck.serializedData()
    try bytes.write(to: directory.appendingPathComponent("saved.pptx"))
    for index in 0..<deck.slides.count {
        let output = try deck.renderSVGReportingProblems(slideAt: index)
        try Data(output.svg.utf8).write(to: directory.appendingPathComponent("slide-\(index).svg"))
        try JSONEncoder().encode(output.problems.fidelityIssues)
            .write(to: directory.appendingPathComponent("slide-\(index)-issues.json"))
    }
    let afterRendering = try deck.serializedData()
    precondition(afterRendering == bytes)
}
print(String(decoding: try JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys]), as: UTF8.self))
