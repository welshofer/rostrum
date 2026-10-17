from pathlib import Path
import subprocess, shutil, json, hashlib, sys
root=Path.cwd(); scratch=Path(sys.argv[1]).resolve(); scratch.mkdir(parents=True,exist_ok=True)
out=scratch/'source'; shutil.copytree(root/'Sources/Rostrum',out)
p=out/'Presentation/RichTextLayout.swift'; s=p.read_text()
def replace(old,new):
 global s
 assert s.count(old)==1,(old,s.count(old))
 s=s.replace(old,new)
def start(label): return f'\n        let profile{label} = LayoutProfile.now()'
def end(label): return f'\n        LayoutProfile.add("{label}", profile{label})\n'
replace('        let bodies = [textBody.firstChild(named: "a:bodyPr")]',start('layout')+'\n        defer { LayoutProfile.add("layout", profilelayout) }\n        let bodies = [textBody.firstChild(named: "a:bodyPr")]')
replace('            let input = preparation?.paragraph',start('input')+'\n            let input = preparation?.paragraph')
replace('            let level = input.level,',end('input')+'            let level = input.level,')
replace('            func face(_ style: ResolvedTextRun) -> FontMetrics? {','            func face(_ style: ResolvedTextRun) -> FontMetrics? {'+start('face')+'\n                defer { LayoutProfile.add("face", profileface) }')
replace('                            let input = preparation?.segment(segment)',start('shape')+'\n                            let input = preparation?.segment(segment)')
replace('                            let breaks = input?.breaks',end('shape')+'                            let breaks = input?.breaks')
replace('            let beforeShapingWarnings = warnings.count',start('atoms')+'\n            let beforeShapingWarnings = warnings.count')
replace('            // Native mixed-face exact-spacing controls',end('atoms')+'            // Native mixed-face exact-spacing controls')
replace('                                let shaped = TextShaper(font).shape(value,',start('fragment')+'\n                                defer { LayoutProfile.add("fragment", profilefragment) }\n                                let shaped = TextShaper(font).shape(value,')
replace('                guard output.count < lineLimit else { didTruncate = true; return }',start('emit')+'\n                defer { LayoutProfile.add("emit", profileemit) }\n                guard output.count < lineLimit else { didTruncate = true; return }')
replace('            while index < atoms.count {',start('wrap')+'\n            while index < atoms.count {')
replace('            if paragraphIndex < paragraphs.count - 1 || useEdgeParagraphSpacing {',end('wrap')+'            if paragraphIndex < paragraphs.count - 1 || useEdgeParagraphSpacing {')
p.write_text(s)
(out/'LayoutProfile.swift').write_text('''import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
package enum LayoutProfile {
 nonisolated(unsafe) static var times: [String: Double] = [:]
 nonisolated(unsafe) static var counts: [String: Int] = [:]
 static func now() -> Double { var v=timespec(); precondition(clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&v)==0); return Double(v.tv_sec)*1000+Double(v.tv_nsec)/1e6 }
 static func add(_ name: String,_ start: Double) { times[name,default:0] += now()-start; counts[name,default:0] += 1 }
 package static func reset() { times=[:];counts=[:] }
 package static func report() { FileHandle.standardError.write(try! JSONSerialization.data(withJSONObject:["cpu_ms":times,"calls":counts],options:[.sortedKeys])+Data([10])) }
}
''')
modules=scratch/'modules'; modules.mkdir()
subprocess.run(['swiftc','-O','-parse-as-library','-whole-module-optimization','-module-name','Rostrum','-package-name','rostrum','-emit-module','-emit-module-path',str(modules/'Rostrum.swiftmodule'),'-emit-object','-o',str(scratch/'rostrum.o'),*[str(p) for p in out.rglob('*.swift')]],check=True)
record={'commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'source_hashes':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'Sources/Rostrum').rglob('*.swift')},'cases':[]}
for kind,driver in [('plain','2026-10-12-table-preparation.swift'),('spans','2026-10-12-table-spans.swift')]:
 s=(root/'docs/benchmarks'/driver).read_text().replace('for trial in 0..<iterations {','for trial in 0..<iterations {\n    LayoutProfile.reset()').replace('    samples.append(sample)','    LayoutProfile.report()\n    samples.append(sample)')
 d=scratch/(kind+'.swift'); d.write_text(s)
 binary=scratch/kind
 subprocess.run(['swiftc','-O','-package-name','rostrum','-I',str(modules),'-I',str(root/'.build/release/Modules'),str(d),str(scratch/'rostrum.o'),*[str(p) for p in (root/'.build/release/RostrumLayout.build').glob('*.o')],'-o',str(binary)],check=True)
 record[kind+'_binary_sha256']=hashlib.sha256(binary.read_bytes()).hexdigest()
 for rows,labels in [(24,'distinct'),(1000,'distinct'),(1000,'repeated')]:
  p=subprocess.run([str(binary),str(rows),labels,'measured','3','plan'],capture_output=True,text=True,check=True)
  case={'kind':kind,'rows':rows,'labels':labels,'samples':json.loads(p.stdout),'profiles':[json.loads(x) for x in p.stderr.splitlines()]}
  record['cases'].append(case); print(json.dumps(case),flush=True)
(scratch/'profile.json').write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
