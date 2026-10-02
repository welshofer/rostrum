import Foundation
import Rostrum

// pptx-tool — a machine-checkable inspector/validator for .pptx files, built on
// Rostrum. `inspect` prints a structured report + exit code; `validate` is a
// terse lint gate. Office acceptance and visual fidelity require their own oracles.

let defaultBudget = 1 << 30

func die(_ message: String, code: Int32 = 2) -> Never {
    FileHandle.standardError.write(Data("pptx-tool: \(message)\n".utf8))
    exit(code)
}

let args = CommandLine.arguments
let commands = ["inspect", "validate", "extract", "render"]
guard args.count >= 3, commands.contains(args[1]) else {
    print("usage: pptx-tool <inspect|validate> <file.pptx> [--max-uncompressed BYTES]")
    print("       pptx-tool extract <file.pptx> <directory> [--max-uncompressed BYTES]")
    print("       pptx-tool render <file.pptx> <directory> [--font FONT_PATH ...] [--strict] [--notes]")
    print("  inspect   structured report of the deck's parts + schema check (exit 1 on issues)")
    print("  validate  required-attribute/schema lint (does not certify Office or rendering)")
    print("  extract   write the deck's text as Markdown, plus per-slide media and chart CSVs")
    print("  --max-uncompressed  read budget; default \(defaultBudget) bytes, 0 for unlimited")
    exit(2)
}
let command = args[1]
let path = args[2]

// This tool exists to point at files somebody else sent you, so it keeps a
// budget tighter than the library's own 4 GiB `.default`. A gigabyte is far
// above any real deck and far below what a zip bomb wants;
// `--max-uncompressed 0` lifts it for the rare legitimately enormous file.
var budget: Int? = defaultBudget
if let flag = args.firstIndex(of: "--max-uncompressed") {
    guard flag + 1 < args.count, let value = Int(args[flag + 1]), value >= 0 else {
        die("--max-uncompressed needs a non-negative byte count")
    }
    budget = value == 0 ? nil : value
}

let data: Data
do {
    data = try Data(contentsOf: URL(fileURLWithPath: path))
} catch {
    die("cannot read \(path): \(error)")
}

let deck: Presentation
do {
    deck = try Presentation(data: data, limits: .init(totalUncompressedBytes: budget))
} catch {
    print("INVALID: \(path) does not open — \(error)")
    exit(1)
}

if command == "extract" {
    guard args.count >= 4, !args[3].hasPrefix("--") else {
        die("extract needs a destination directory: pptx-tool extract \(path) <directory>")
    }
    let destination = URL(fileURLWithPath: args[3], isDirectory: true)
    let summary: DeckExport.Summary
    do {
        summary = try DeckExport.write(deck, to: destination)
    } catch {
        die("cannot write \(args[3]): \(error)")
    }
    print("wrote \(summary.markdownFile.path)")
    print("  \(deck.slides.count) slides, \(summary.slideFolders) slide folder(s), "
          + "\(summary.assetsWritten) media file(s), \(summary.chartsWritten) chart CSV(s)")
    // A deck that only partly came out says so, and says so loudly enough to
    // be caught by a script: the words are on stderr and the exit code is not 0.
    for warning in summary.warnings {
        FileHandle.standardError.write(Data("pptx-tool: \(warning)\n".utf8))
    }
    exit(summary.warnings.isEmpty ? 0 : 1)
}

if command == "render" {
    guard args.count >= 4, !args[3].hasPrefix("--") else { die("render needs a destination directory") }
    do {
        for index in args.indices where args[index] == "--font" {
            guard index + 1 < args.count else { die("--font needs a path") }
            try deck.fonts.register(contentsOf: URL(fileURLWithPath: args[index + 1]))
        }
        let directory = URL(fileURLWithPath: args[3], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<deck.slides.count {
            let notes = args.contains("--notes")
            if notes, try !deck.slides[index].hasNotes { continue }
            let result = try notes
                ? deck.renderNotesSVGReportingProblems(slideAt: index, strictRendering: args.contains("--strict"))
                : deck.renderSVGReportingProblems(slideAt: index, strictRendering: args.contains("--strict"))
            for issue in result.problems.fidelityIssues {
                FileHandle.standardError.write(Data("pptx-tool: slide \(index + 1) \(issue.code.rawValue) \(issue.location.path): \(issue.message)\n".utf8))
            }
            let url = directory.appendingPathComponent(String(format: notes ? "notes-%02d.svg" : "slide-%02d.svg", index + 1))
            try result.svg.write(to: url, atomically: true, encoding: .utf8)
            print(url.path)
        }
    } catch let error as StrictRenderingError {
        for issue in error.problems.fidelityIssues {
            FileHandle.standardError.write(Data("pptx-tool: \(issue.code.rawValue) \(issue.location.partURI)\(issue.location.path): \(issue.message)\n".utf8))
        }
        die(error.description, code: 1)
    } catch { die("render failed: \(error)", code: 1) }
    exit(0)
}

let issues: [Presentation.ValidationIssue]
do { issues = try deck.validate() }
catch { die("validation could not complete: \(error)", code: 1) }


func partCount(_ deck: Presentation, _ prefix: String) -> Int {
    deck.package.parts.keys.filter { $0.value.hasPrefix(prefix) }.count
}

if command == "validate" {
    if issues.isEmpty {
        print("OK: \(path) — \(deck.slides.count) slides, no schema issues")
        exit(0)
    }
    for issue in issues { print("ISSUE: \(issue)") }
    exit(1)
}

// inspect — a structured report.
let size = deck.slideSize
func field(_ label: String, _ value: String) { print("\(label.padding(toLength: 11, withPad: " ", startingAt: 0))\(value)") }
field("file:", path)
field("bytes:", String(data.count))
field("slides:", String(deck.slides.count))
field("layouts:", String(deck.layouts.count))
field("masters:", String(partCount(deck, "/ppt/slideMasters/")))
field("media:", String(partCount(deck, "/ppt/media/")))
field("charts:", String(partCount(deck, "/ppt/charts/")))
field("embeds:", String(partCount(deck, "/ppt/embeddings/")))     // chart workbooks / embedded objects
field("notes:", String(partCount(deck, "/ppt/notesSlides/")))
field("sections:", String(deck.sections.count))
field("size:", String(format: "%.2fin × %.2fin", size.width.inches, size.height.inches))
field("parts:", String(deck.package.parts.count))
if deck.sections.count > 0 {
    field("sectionList:", Array(deck.sections).map { "\($0.name)(\($0.slideCount))" }.joined(separator: ", "))
}
if issues.isEmpty {
    field("validate:", "OK")
    exit(0)
} else {
    field("validate:", "\(issues.count) issue(s)")
    for issue in issues.prefix(20) { print("  - \(issue)") }
    exit(1)
}
