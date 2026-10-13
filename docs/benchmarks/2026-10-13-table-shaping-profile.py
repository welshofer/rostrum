"""Copy and instrument baseline sources; never edit production sources.

Run from the repository root: python3 this-file.py SCRATCH.
Compile SCRATCH/profile-source as module Rostrum, link the existing layout
objects and profile-driver.swift with -package-name rostrum, then run the driver
in plan mode. Timers nest: initial shaping is inside atom assembly; line shaping
is inside wrapping. The profile is diagnostic, not an end-to-end speedup claim.
"""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path.cwd()
assert subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip() == "d6aaefdd695db18502109cbed3030f1e82ba9473"
assert not subprocess.check_output(["git", "diff", "HEAD", "--", "Sources"], text=True).strip()
scratch = Path(sys.argv[1]).resolve()
out = scratch / "profile-source"
shutil.copytree(root / "Sources/Rostrum", out)
p = out / "Presentation/RichTextLayout.swift"
s = p.read_text()

def replace(old, new):
    global s
    assert s.count(old) == 1, old
    s = s.replace(old, new)

replace('        let bodies = [textBody.firstChild(named: "a:bodyPr")]',
        '        let profileLayoutStart = ProcessInfo.processInfo.systemUptime\n'
        '        defer { TableTextProfile.add(0, profileLayoutStart) }\n'
        '        let bodies = [textBody.firstChild(named: "a:bodyPr")]')
replace('            let input = preparation?.paragraph',
        '            let profileInputStart = ProcessInfo.processInfo.systemUptime\n'
        '            let input = preparation?.paragraph')
replace('            let level = input.level,',
        '            TableTextProfile.add(1, profileInputStart)\n            let level = input.level,')
replace('                            let input = preparation?.segment(segment)',
        '                            let profileShapeStart = ProcessInfo.processInfo.systemUptime\n'
        '                            let input = preparation?.segment(segment)')
replace('                            let breaks = input?.breaks',
        '                            TableTextProfile.add(3, profileShapeStart)\n'
        '                            let breaks = input?.breaks')
replace('            let beforeShapingWarnings = warnings.count',
        '            let profileAtomsStart = ProcessInfo.processInfo.systemUptime\n'
        '            let beforeShapingWarnings = warnings.count')
replace('            // Native mixed-face exact-spacing controls',
        '            TableTextProfile.add(2, profileAtomsStart)\n'
        '            // Native mixed-face exact-spacing controls')
replace('                            let shaped = TextShaper(font).shape(value,',
        '                            let profileLineShapeStart = ProcessInfo.processInfo.systemUptime\n'
        '                            let shaped = TextShaper(font).shape(value,')
replace('                            let nativeGrid = nativeLeftToRight && Self.supportsNativeAdvanceGrid(shaped, text: value)',
        '                            TableTextProfile.add(5, profileLineShapeStart)\n'
        '                            let nativeGrid = nativeLeftToRight && Self.supportsNativeAdvanceGrid(shaped, text: value)')
replace('            while index < atoms.count {',
        '            let profileWrapStart = ProcessInfo.processInfo.systemUptime\n'
        '            while index < atoms.count {')
replace('            if paragraphIndex < paragraphs.count - 1 || useEdgeParagraphSpacing {',
        '            TableTextProfile.add(4, profileWrapStart)\n'
        '            if paragraphIndex < paragraphs.count - 1 || useEdgeParagraphSpacing {')
p.write_text(s)
(out / "TableTextProfile.swift").write_text('''import Foundation
package enum TableTextProfile {
    nonisolated(unsafe) static var times = [Double](repeating: 0, count: 6)
    nonisolated(unsafe) static var counts = [Int](repeating: 0, count: 6)
    static func add(_ index: Int, _ start: Double) {
        times[index] += ProcessInfo.processInfo.systemUptime - start
        counts[index] += 1
    }
    package static func reset() {
        times = [Double](repeating: 0, count: 6); counts = [Int](repeating: 0, count: 6)
    }
    package static func report() {
        let names = ["layout", "paragraph_input", "atoms_including_initial_shape", "initial_shape", "wrap_including_line_shape", "line_shape"]
        var record: [String: Any] = [:]
        for i in names.indices { record[names[i]] = ["seconds": times[i], "calls": counts[i]] }
        FileHandle.standardError.write(try! JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) + Data([10]))
    }
}
''')
for name, driver in [("spans", "2026-10-12-table-spans.swift"), ("unmerged", "2026-10-12-table-preparation.swift")]:
    s = (root / "docs/benchmarks" / driver).read_text()
    s = s.replace('for trial in 0..<iterations {', 'for trial in 0..<iterations {\n    TableTextProfile.reset()')
    s = s.replace('    samples.append(sample)', '    TableTextProfile.report()\n    samples.append(sample)')
    (scratch / f"profile-{name}.swift").write_text(s)
