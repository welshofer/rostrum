import Foundation
import LecternCore
let args = CommandLine.arguments
let parent = URL(fileURLWithPath: args[1], isDirectory: true)
let alternate = args.count > 2 && args[2] == "true"
let start = DispatchTime.now().uptimeNanoseconds
let result = try LibraryLab.run(.listMarkers, options: .init(alternative: alternate), in: parent)
let stop = DispatchTime.now().uptimeNanoseconds
let report: [String: Any] = ["seconds": Double(stop - start) / 1_000_000_000, "passed": result.passed, "checks": result.checks.count, "findings": result.findings.count, "slides": result.slideCount, "alternative": alternate, "directory": result.directory.path]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]))
FileHandle.standardOutput.write(Data("\n".utf8))
if !result.passed { exit(1) }
