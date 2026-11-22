import Foundation
import Rostrum

// pptx-tool — a machine-checkable inspector/validator for .pptx files, built on
// Rostrum. `inspect` prints a structured report + exit code; `validate` is a
// modeled structural lint. Success does not establish PowerPoint acceptance.

let defaultBudget = 1 << 30

let usageText = """
usage: pptx-tool <inspect|validate> <file.pptx> [--max-uncompressed BYTES]
       pptx-tool extract <file.pptx> <directory> [--include-poster] [--max-uncompressed BYTES]
       pptx-tool render <file.pptx> <directory> [--font FONT_PATH ...] [--strict] [--notes] [--max-uncompressed BYTES]
  inspect   structured report of the deck's parts + schema check (exit 1 on issues)
  validate  required-attribute/schema lint (does not certify Office or rendering)
  extract   write the deck's text as Markdown, plus per-slide media and chart CSVs
  render    write per-slide (or --notes) SVG previews; --strict exits 1 on fidelity issues
  --max-uncompressed  read budget; default \(defaultBudget) bytes, 0 for unlimited
"""

func die(_ message: String, code: Int32 = 2) -> Never {
    FileHandle.standardError.write(Data("pptx-tool: \(message)\n".utf8))
    exit(code)
}

enum Subcommand: String {
    case inspect
    case validate
    case extract
    case render
}

struct CLIOptions {
    let command: Subcommand
    let inputPath: String
    let outputDirectory: String?
    let budget: Int?
    let includePoster: Bool
    let fontPaths: [String]
    let strict: Bool
    let notes: Bool
}

func parseCLI(_ arguments: [String]) -> CLIOptions {
    guard arguments.count >= 2, let command = Subcommand(rawValue: arguments[1]) else {
        print(usageText)
        let detail = arguments.count < 2 ? "missing command" : "unknown command '\(arguments[1])'"
        die(detail)
    }

    var positionals: [String] = []
    var budget: Int? = defaultBudget
    var sawMaxUncompressed = false
    var includePoster = false
    var fontPaths: [String] = []
    var strict = false
    var notes = false
    var endOfOptions = false

    var index = 2
    while index < arguments.count {
        let arg = arguments[index]
        if !endOfOptions && arg == "--" {
            endOfOptions = true
            index += 1
            continue
        }
        if !endOfOptions && arg.hasPrefix("-") && arg != "-" {
            let name: String
            let inlineValue: String?
            if let equals = arg.firstIndex(of: "=") {
                name = String(arg[..<equals])
                inlineValue = String(arg[arg.index(after: equals)...])
            } else {
                name = arg
                inlineValue = nil
            }

            switch name {
            case "--max-uncompressed":
                guard !sawMaxUncompressed else {
                    die("--max-uncompressed specified more than once")
                }
                sawMaxUncompressed = true
                let rawValue: String
                if let inlineValue {
                    guard !inlineValue.isEmpty else {
                        die("--max-uncompressed needs a non-negative byte count")
                    }
                    rawValue = inlineValue
                } else {
                    guard index + 1 < arguments.count else {
                        die("--max-uncompressed needs a non-negative byte count")
                    }
                    index += 1
                    rawValue = arguments[index]
                }
                guard let parsed = Int(rawValue), parsed >= 0 else {
                    die("--max-uncompressed needs a non-negative byte count")
                }
                budget = parsed == 0 ? nil : parsed

            case "--include-poster" where command == .extract:
                guard inlineValue == nil else {
                    die("--include-poster does not take a value")
                }
                includePoster = true

            case "--strict" where command == .render:
                guard inlineValue == nil else {
                    die("--strict does not take a value")
                }
                strict = true

            case "--notes" where command == .render:
                guard inlineValue == nil else {
                    die("--notes does not take a value")
                }
                notes = true

            case "--font" where command == .render:
                let fontPath: String
                if let inlineValue {
                    guard !inlineValue.isEmpty else {
                        die("--font needs a path")
                    }
                    fontPath = inlineValue
                } else {
                    guard index + 1 < arguments.count,
                          !arguments[index + 1].isEmpty,
                          !arguments[index + 1].hasPrefix("-") else {
                        die("--font needs a path")
                    }
                    index += 1
                    fontPath = arguments[index]
                }
                fontPaths.append(fontPath)

            default:
                die("unknown option '\(name)' for '\(command.rawValue)'")
            }
        } else {
            positionals.append(arg)
        }
        index += 1
    }

    switch command {
    case .inspect, .validate:
        guard !positionals.isEmpty else {
            print(usageText)
            die("\(command.rawValue) needs a <file.pptx> path")
        }
        guard positionals.count == 1 else {
            die("unexpected argument '\(positionals[1])'")
        }
        guard !positionals[0].isEmpty else {
            die("\(command.rawValue) needs a non-empty <file.pptx> path")
        }
        return CLIOptions(
            command: command,
            inputPath: positionals[0],
            outputDirectory: nil,
            budget: budget,
            includePoster: false,
            fontPaths: [],
            strict: false,
            notes: false
        )

    case .extract, .render:
        guard !positionals.isEmpty else {
            print(usageText)
            die("\(command.rawValue) needs <file.pptx> and <directory>")
        }
        guard !positionals[0].isEmpty else {
            die("\(command.rawValue) needs a non-empty <file.pptx> path")
        }
        guard positionals.count >= 2 else {
            die("\(command.rawValue) needs a destination directory")
        }
        guard positionals.count == 2 else {
            die("unexpected argument '\(positionals[2])'")
        }
        guard !positionals[1].isEmpty else {
            die("\(command.rawValue) needs a non-empty destination directory")
        }
        return CLIOptions(
            command: command,
            inputPath: positionals[0],
            outputDirectory: positionals[1],
            budget: budget,
            includePoster: includePoster,
            fontPaths: fontPaths,
            strict: strict,
            notes: notes
        )
    }
}

// This tool exists to point at files somebody else sent you, so it keeps a
// budget tighter than the library's own 4 GiB `.default`. A gigabyte is far
// above any real deck and far below what a zip bomb wants;
// `--max-uncompressed 0` lifts it for the rare legitimately enormous file.
let options = parseCLI(CommandLine.arguments)
let path = options.inputPath
let fileURL = URL(fileURLWithPath: path)

let deck: Presentation
do {
    deck = try Presentation(contentsOf: fileURL, limits: .init(totalUncompressedBytes: options.budget))
} catch let error as RostrumError {
    print("INVALID: \(path) does not open — \(error)")
    exit(1)
} catch {
    die("cannot read \(path): \(error)")
}

if options.command == .extract, let outPath = options.outputDirectory {
    let destination = URL(fileURLWithPath: outPath, isDirectory: true)
    let summary: DeckExport.Summary
    do {
        summary = try DeckExport.write(deck, to: destination, includeVideoPosters: options.includePoster)
    } catch {
        die("cannot write \(outPath): \(error)")
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

if options.command == .render, let outPath = options.outputDirectory {
    do {
        for fontPath in options.fontPaths {
            try deck.fonts.register(contentsOf: URL(fileURLWithPath: fontPath))
        }
        let directory = URL(fileURLWithPath: outPath, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<deck.slides.count {
            let notes = options.notes
            if notes, try !deck.slides[index].hasNotes { continue }
            let result = try notes
                ? deck.renderNotesSVGReportingProblems(slideAt: index, strictRendering: options.strict)
                : deck.renderSVGReportingProblems(slideAt: index, strictRendering: options.strict)
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

if options.command == .validate {
    if issues.isEmpty {
        print("OK: \(path) — \(deck.slides.count) slides, no schema issues")
        exit(0)
    }
    for issue in issues { print("ISSUE: \(issue)") }
    exit(1)
}

// inspect — a structured report.
let size = deck.slideSize
func field(_ label: String, _ value: String) {
    let padded = label.count < 11
        ? label.padding(toLength: 11, withPad: " ", startingAt: 0)
        : label + " "
    print("\(padded)\(value)")
}
let resolvedPath = fileURL.resolvingSymlinksInPath().path
let fileAttributes = (try? FileManager.default.attributesOfItem(atPath: resolvedPath))
    ?? (try? FileManager.default.attributesOfItem(atPath: fileURL.path))
let byteCount = (fileAttributes?[.size] as? NSNumber)?.uint64Value ?? 0
field("file:", path)
field("bytes:", String(byteCount))
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
let orphans = deck.orphanPartURIs
if !orphans.isEmpty {
    field("orphans:", String(orphans.count))
}
if deck.sections.count > 0 {
    field("sectionList:", Array(deck.sections).map { "\($0.name)(\($0.slideCount))" }.joined(separator: ", "))
}
if !deck.readWarnings.isEmpty {
    field("readWarnings:", String(deck.readWarnings.count))
    for warning in deck.readWarnings {
        print("  - \(warning)")
    }
}
if issues.isEmpty {
    field("validate:", "OK")
    exit(0)
} else {
    field("validate:", "\(issues.count) issue(s)")
    for issue in issues.prefix(20) { print("  - \(issue)") }
    exit(1)
}
