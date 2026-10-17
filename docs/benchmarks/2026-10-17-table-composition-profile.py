"""Copy, instrument and build a diagnostic layout module without editing production sources.
Run from a checkout whose Release Rostrum target is built: python3 this-file.py SCRATCH.
CPU timers nest; measurements describe work distribution, not speedup.
"""
from pathlib import Path
import shutil, sys, subprocess, json, hashlib
root=Path.cwd(); scratch=Path(sys.argv[1]).resolve()
scratch.mkdir(parents=True, exist_ok=True)
out=scratch/'profile-source'
shutil.copytree(root/'Sources/RostrumLayout',out)
def edit(file,changes):
    p=out/file;s=p.read_text()
    for old,new in changes:
        assert s.count(old)==1,(file,old,s.count(old))
        s=s.replace(old,new)
    p.write_text(s)
def timer(label):return f'\n        let profileStart = CompositionProfile.now()\n        defer {{ CompositionProfile.add("{label}", profileStart) }}'
edit('TemplateLayoutEngine.swift',[
('    private func context(_ layout: SlideLayout, slot: Int) -> TemplateTextContext? {','    private func context(_ layout: SlideLayout, slot: Int) -> TemplateTextContext? {'+timer('context')),
('    public func objectStyle(layout: SlideLayout, slot: Int?) -> DeckStyle {','    public func objectStyle(layout: SlideLayout, slot: Int?) -> DeckStyle {'+timer('object_style')),
(') throws -> PreparedSlide {',') throws -> PreparedSlide {'+timer('prepare')),
('    func write(_ plan: TemplateSlidePlan, prepared: PreparedSlide) throws -> Slide {','    func write(_ plan: TemplateSlidePlan, prepared: PreparedSlide) throws -> Slide {'+timer('write')),
('        let slide = try presentation.slides.add(clonedFrom: plan.layout)','        let cloneStart = CompositionProfile.now()\n        let slide = try presentation.slides.add(clonedFrom: plan.layout)\n        CompositionProfile.add("clone", cloneStart)'),
('            native.setLayoutContents(table.rows, font: tableStyle.bodyFont, size: 18 * objectScale)','            let contentsStart = CompositionProfile.now()\n            native.setLayoutContents(table.rows, font: tableStyle.bodyFont, size: 18 * objectScale)\n            CompositionProfile.add("set_contents", contentsStart)'),
('        let geometry = RichTextLayout(textBody: body, width: width, height: 1e9,','        let profileStart = CompositionProfile.now()\n        defer { CompositionProfile.add("measure_text", profileStart) }\n        let geometry = RichTextLayout(textBody: body, width: width, height: 1e9,')])
edit('TemplateTablePagination.swift',[
('        let current = try planTablePages(title: plan.title, table: plan.content, caption: plan.caption,','        let replanStart = CompositionProfile.now()\n        let current = try planTablePages(title: plan.title, table: plan.content, caption: plan.caption,'),
('        guard current.pages.count == plan.pages.count,','        CompositionProfile.add("fresh_replan", replanStart)\n        guard current.pages.count == plan.pages.count,'),
('                try slide.addText(current.caption, in: frame, role: .caption,','                let captionStart = CompositionProfile.now()\n                defer { CompositionProfile.add("caption", captionStart) }\n                try slide.addText(current.caption, in: frame, role: .caption,')])
edit('TemplateTableContent.swift',[
('        let prototype = try Table.layoutPrototype','        let prototypeStart = CompositionProfile.now()\n        let prototype = try Table.layoutPrototype'),
('        try prototype.merge(merges)','        try prototype.merge(merges)\n        CompositionProfile.add("prototype", prototypeStart)')])
(out/'CompositionProfile.swift').write_text('''import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
package enum CompositionProfile {
    nonisolated(unsafe) static var times: [String: Double] = [:]
    nonisolated(unsafe) static var counts: [String: Int] = [:]
    static func now() -> Double {
        var value = timespec()
        precondition(clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value) == 0)
        return Double(value.tv_sec) * 1000 + Double(value.tv_nsec) / 1e6
    }
    static func add(_ name: String, _ start: Double) {
        times[name, default: 0] += now() - start; counts[name, default: 0] += 1
    }
    package static func reset() { times = [:]; counts = [:] }
    package static func report() {
        let report = times.mapValues { $0 } as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: ["cpu_ms": report, "calls": counts], options: [.sortedKeys])
        FileHandle.standardError.write(data + Data([10]))
    }
}
''')
driver=(root/'docs/benchmarks/2026-10-12-table-preparation.swift').read_text()
driver=driver.replace('        let slides = try engine.composeTablePages(accepted)', '        CompositionProfile.reset()\n        let slides = try engine.composeTablePages(accepted)\n        CompositionProfile.report()')
(scratch/'profile-driver.swift').write_text(driver)

modules=scratch/'modules';modules.mkdir()
subprocess.run(['swiftc','-O','-parse-as-library','-whole-module-optimization','-module-name','RostrumLayout',
    '-package-name','rostrum','-I',str(root/'.build/release/Modules'),'-emit-module','-emit-module-path',str(modules/'RostrumLayout.swiftmodule'),
    '-emit-object','-o',str(scratch/'layout.o'),*[str(p) for p in out.glob('*.swift')]],check=True)
subprocess.run(['swiftc','-O','-package-name','rostrum','-I',str(modules),'-I',str(root/'.build/release/Modules'),str(scratch/'profile-driver.swift'),
    *[str(p) for p in (root/'.build/release/Rostrum.build').glob('*.o')],str(scratch/'layout.o'),'-o',str(scratch/'profile')],check=True)
record={'checkout_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
 'source_dirty':bool(subprocess.check_output(['git','diff','HEAD','--','Sources'],text=True).strip()),
 'source_hashes':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'Sources/RostrumLayout').glob('*.swift')},
 'binary_sha256':hashlib.sha256((scratch/'profile').read_bytes()).hexdigest(),'cases':[]}
for rows,labels in [(24,'distinct'),(1000,'distinct'),(1000,'repeated')]:
 p=subprocess.run([str(scratch/'profile'),str(rows),labels,'measured','3','compose'],capture_output=True,text=True,check=True)
 record['cases'].append({'rows':rows,'labels':labels,'samples':json.loads(p.stdout),'profile':[json.loads(s) for s in p.stderr.splitlines()]})
(scratch/'profile.json').write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
