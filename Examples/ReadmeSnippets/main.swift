// The README's two code snippets, compiled and run by CI so the documentation
// can never rot: if a README example stops building or stops producing the
// deck it promises, this target breaks the build.
//
// KEEP IN SYNC WITH README.md — the bodies of `quickStart()` and
// `designAuthoring()` must match the snippets verbatim (only the output
// paths and the sunflower.md location are parameterized, since a README
// reader runs from their own directory).
//
// Run:  swift run ReadmeSnippets [output-directory]

import Foundation
import Rostrum

let outDir = URL(filePath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)

/// `#filePath`-anchored so the example runs from any working directory.
let sunflowerMD = URL(filePath: #filePath)
    .deletingLastPathComponent()                    // Examples/ReadmeSnippets
    .deletingLastPathComponent()                    // Examples
    .deletingLastPathComponent()                    // repo root
    .appending(path: "Lectern/App/Resources/Styles/sunflower.md")

// MARK: - README snippet 1: quick start

func quickStart() throws {
    let deck = try Presentation()                       // starts with one blank 16:9 slide
    let slide = try deck.slides.add(layout: deck.layout(type: "title")!)
    slide.title?.textFrame?.text = "Hello, Rostrum"
    try deck.slides.remove(at: 0)                       // drop the blank starter slide
    try deck.save(to: outDir.appending(path: "hello.pptx"))
}

// MARK: - README snippet 2: the design-authoring layer

func designAuthoring() throws {
    let deck = try Presentation()   // or open your brand template: Presentation(contentsOf: URL(filePath: "brand.potx"))
    deck.applyDesign(try Design(contentsOf: sunflowerMD))

    let arr = ChartData(categories: ["Q1", "Q2", "Q3", "Q4"],
                        series: [ChartData.Series(name: "ARR", values: [12.1, 14.6, 16.8, 18.4])])

    try deck.titleSlide("Q3 Business Review", subtitle: "Northwind", kicker: "FY26")
    try deck.bulletSlide("Highlights", ["ARR $18.4M", "Retention 91%", "NPS 47"], kicker: "Results")
    try deck.chartSlide("Revenue", .line, arr, options: ChartOptions(legend: .bottom))
    try deck.setSections([("Cover", 0), ("The Quarter", 1)])
    try deck.footer("Confidential").showSlideNumbers()
    try deck.slides.remove(at: 0)   // drop the blank starter slide
    try deck.save(to: outDir.appending(path: "review.pptx"))
}

try quickStart()
try designAuthoring()

// Reopen both to prove they are structurally valid, not just written.
for name in ["hello.pptx", "review.pptx"] {
    let url = outDir.appending(path: name)
    _ = try Presentation(contentsOf: url)
    print("wrote and reopened \(url.path)")
}
