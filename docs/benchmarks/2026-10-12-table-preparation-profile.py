"""Copy and instrument baseline RostrumLayout into a scratch directory.

Arguments: baseline repository checkout, scratch directory. This never edits the
checkout. Compile the copied module with the baseline Release Rostrum objects;
run the table-preparation Swift driver in plan mode and capture stderr JSONL.
"""
from pathlib import Path
import shutil
import subprocess
import sys
root=Path(sys.argv[1]).resolve()
assert subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip() == '9359abd927b4305704d5ee0d3defad41194029f9', 'Use a checkout of the baseline commit'
assert not subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '--', 'Sources/RostrumLayout'], text=True).strip(), 'Baseline layout sources must be clean'
out=Path(sys.argv[2]).resolve() / 'profile-source'
shutil.copytree(root/'Sources/RostrumLayout',out,dirs_exist_ok=True)
p=out/'TableLayoutEngine.swift'
s=p.read_text()
s=s.replace('        let widths = columnWidths ?? source.columnWidths', '''        let profileStart = ProcessInfo.processInfo.systemUptime
        var styleTime = 0.0, validationTime = 0.0, serializationTime = 0.0, geometryTime = 0.0
        var styleVisits = 0, geometryVisits = 0, serializedBodies = 0
        defer {
            let record: [String: Any] = ["total_seconds": ProcessInfo.processInfo.systemUptime - profileStart,
                "style_seconds": styleTime, "validation_seconds": validationTime,
                "serialization_seconds": serializationTime, "geometry_seconds": geometryTime,
                "style_visits": styleVisits, "geometry_visits": geometryVisits, "serialized_bodies": serializedBodies]
            let data = try! JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            FileHandle.standardError.write(data + Data([10]))
        }
        let widths = columnWidths ?? source.columnWidths''')
s=s.replace('                let cell = source.cell(', '                let styleStart = ProcessInfo.processInfo.systemUptime\n                let cell = source.cell(')
s=s.replace('                guard seenStyles.insert(styleBytes).inserted else { continue }','''                styleTime += ProcessInfo.processInfo.systemUptime - styleStart; styleVisits += 1
                guard seenStyles.insert(styleBytes).inserted else { continue }
                let validationStart = ProcessInfo.processInfo.systemUptime''')
s=s.replace('                let measurement: Measurement','''                validationTime += ProcessInfo.processInfo.systemUptime - validationStart
                let measurement: Measurement''')
s=s.replace('                    let key = Key(', '                    let serializationStart = ProcessInfo.processInfo.systemUptime\n                    let key = Key(')
s=s.replace('                    if let cached = cache[key]', '''                    serializationTime += ProcessInfo.processInfo.systemUptime - serializationStart; serializedBodies += 1
                    if let cached = cache[key]''')
s=s.replace('                        let geometry = RichTextLayout(', '                        let geometryStart = ProcessInfo.processInfo.systemUptime\n                        let geometry = RichTextLayout(')
s=s.replace('                        if geometry.truncated', '''                        geometryTime += ProcessInfo.processInfo.systemUptime - geometryStart; geometryVisits += 1
                        if geometry.truncated''')
p.write_text(s)
