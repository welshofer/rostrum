import Foundation
import Rostrum
import LecternCore

let parent = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
for alternative in [false, true] {
    let result = try LibraryLab.run(.templates, options: .init(alternative: alternative), in: parent)
    print("alternative=\(alternative) passed=\(result.passed) slides=\(result.slideCount) path=\(result.afterURL.path)")
    for check in result.checks where !check.passed { print(check) }
    precondition(result.passed)
}
