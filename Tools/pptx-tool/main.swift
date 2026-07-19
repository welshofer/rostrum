import Foundation
import Rostrum

// pptx-tool — a machine-checkable inspector/validator for .pptx files, built on
// Rostrum. `inspect` prints a structured report + exit code; `validate` is a
// terse pass/fail gate (the "PowerPoint will accept this" check for CI/tools).

func die(_ message: String, code: Int32 = 2) -> Never {
    FileHandle.standardError.write(Data("pptx-tool: \(message)\n".utf8))
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 3, args[1] == "inspect" || args[1] == "validate" else {
    print("usage: pptx-tool <inspect|validate> <file.pptx>")
    print("  inspect   structured report of the deck's parts + schema check (exit 1 on issues)")
    print("  validate  terse pass/fail schema gate (exit 1 on issues, 1 if it won't open)")
    exit(2)
}
let command = args[1]
let path = args[2]

let data: Data
do {
    data = try Data(contentsOf: URL(fileURLWithPath: path))
} catch {
    die("cannot read \(path): \(error)")
}

let deck: Presentation
do {
    deck = try Presentation(data: data)
} catch {
    print("INVALID: \(path) does not open — \(error)")
    exit(1)
}

let issues = (try? deck.validate()) ?? []

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
