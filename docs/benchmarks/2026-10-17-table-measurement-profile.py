"""Copy/instrument a matching Release layout module; run from repo root with fresh SCRATCH.
Nested CPU timers describe work distribution, not normal-build speedup.
"""
from pathlib import Path
import shutil,sys,subprocess,json,hashlib,os
root=Path.cwd(); scratch=Path(sys.argv[1]).resolve(); scratch.mkdir()
out=scratch/'source';shutil.copytree(root/'Sources/RostrumLayout',out)
def edit(file,changes):
 p=out/file;s=p.read_text()
 for old,new in changes:
  assert s.count(old)==1,(file,old,s.count(old))
  s=s.replace(old,new)
 p.write_text(s)
def timer(label):return f'\n        let profileStart = CompositionProfile.now()\n        defer {{ CompositionProfile.add("{label}", profileStart) }}'
style_line = ('            let style = cell.textStyleBytes' if 'let style = cell.textStyleBytes' in (out/'TableCellPreparation.swift').read_text() else '            let style = Data(cell.textStyle.serialized().utf8)')
style_label = 'style_bytes_read' if 'textStyleBytes' in style_line else 'style_serialization'
edit('TableCellPreparation.swift',[
 ('pagination: Bool) -> [TableCellInput] {','pagination: Bool) -> [TableCellInput] {'+timer('resolve')),
 ('prepareText: Bool) -> [TableCellInput] {','prepareText: Bool) -> [TableCellInput] {'+timer('inputs')),
 ('private func text(for input: TableCellInput) -> Text? {','private func text(for input: TableCellInput) -> Text? {'+timer('prepare_text')),
 (style_line,'            let serializationStart = CompositionProfile.now()\n'+style_line+'\n            CompositionProfile.add("'+style_label+'", serializationStart)'),
 ('            let cell = source.cell(row:', '            let sourceStart = CompositionProfile.now()\n            let cell = source.cell(row:'),
 ('            let serializationStart', '            CompositionProfile.add("source_cell", sourceStart)\n            let serializationStart')])
edit('TableLayoutEngine.swift',[
 ('        let theme = theme ?? table.layoutTheme', '        let profileStart = CompositionProfile.now()\n        defer { CompositionProfile.add("table_plan", profileStart) }\n        let theme = theme ?? table.layoutTheme'),
 ('                    if let cached = cache[key] { measurement = cached }','                    let cacheStart = CompositionProfile.now()\n                    let cached = cache[key]\n                    CompositionProfile.add("measurement_lookup", cacheStart)\n                    if let cached { measurement = cached }'),
 ('                            let geometry = RichTextLayout(', '                            let geometryStart = CompositionProfile.now()\n                            let geometry = RichTextLayout('),
 ('                            if geometry.truncated', '                            CompositionProfile.add("horizontal_layout", geometryStart)\n                            if geometry.truncated'),
 ('        if let reuse {\n            reuse.rotatedCells', '        let finalStart = CompositionProfile.now()\n        defer { CompositionProfile.add("final_constraints_and_columns", finalStart) }\n        if let reuse {\n            reuse.rotatedCells')])
prof='import Foundation\n#if canImport(Glibc)\nimport Glibc\n#else\nimport Darwin\n#endif\npackage enum CompositionProfile {\n    nonisolated(unsafe) static var times: [String: Double] = [:]\n    nonisolated(unsafe) static var counts: [String: Int] = [:]\n    static func now() -> Double {\n        var value = timespec()\n        precondition(clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value) == 0)\n        return Double(value.tv_sec) * 1000 + Double(value.tv_nsec) / 1e6\n    }\n    static func add(_ name: String, _ start: Double) {\n        times[name, default: 0] += now() - start; counts[name, default: 0] += 1\n    }\n    package static func reset() { times = [:]; counts = [:] }\n    package static func report() {\n        let report = times.mapValues { $0 } as [String: Any]\n        let data = try! JSONSerialization.data(withJSONObject: ["cpu_ms": report, "calls": counts], options: [.sortedKeys])\n        FileHandle.standardError.write(data + Data([10]))\n    }\n}\n'
(out/'CompositionProfile.swift').write_text(prof)
modules=scratch/'modules';modules.mkdir()
subprocess.run(['swiftc','-O','-parse-as-library','-whole-module-optimization','-module-name','RostrumLayout','-package-name','rostrum','-I',str(root/'.build/release/Modules'),'-emit-module','-emit-module-path',str(modules/'RostrumLayout.swiftmodule'),'-emit-object','-o',str(scratch/'layout.o'),*[str(p) for p in out.glob('*.swift')]],check=True)
r={'source_hashes':[{'path':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted((root/'Sources').rglob('*.swift'))],'cases':[]}
for kind,name in [('plain','2026-10-12-table-preparation.swift'),('spans','2026-10-12-table-spans.swift')]:
 s=(root/'docs/benchmarks'/name).read_text().replace('for trial in 0..<iterations {','for trial in 0..<iterations {\n    CompositionProfile.reset()').replace('    samples.append(sample)','    CompositionProfile.report()\n    samples.append(sample)')
 d=scratch/(kind+'.swift');d.write_text(s)
 subprocess.run(['swiftc','-O','-package-name','rostrum','-I',str(modules),'-I',str(root/'.build/release/Modules'),str(d),*[str(p) for p in (root/'.build/release/Rostrum.build').glob('*.o')],str(scratch/'layout.o'),'-o',str(scratch/kind)],check=True)
# Builds complete before measuring either case.
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
for kind in ['plain','spans']:
 for rows in [24,1000]:
  p=subprocess.run([str(scratch/kind),str(rows),'distinct','measured','5','plan'],capture_output=True,text=True,check=True)
  r['cases'].append({'kind':kind,'rows':rows,'samples':json.loads(p.stdout),'profiles':[json.loads(x) for x in p.stderr.splitlines()]})
(scratch/'profile.json').write_text(json.dumps(r,indent=2)+'\n')
for case in r['cases']:
 print(case['kind'],case['rows'],case['profiles'][-1],flush=True)
