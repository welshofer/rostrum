from pathlib import Path
import json,hashlib,shutil
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
original=Path('/tmp/lectern-fidelity21-integration-draft/docs/benchmarks/2026-10-04-table-transitions-integration-verification.json')
assert sha(original)=='7ddcae59f361d6fdd4dcbc7f3c340ba8422918b4bae50893a9f10ec7aed056cc'
base=Path('/tmp/lectern-fidelity21-integration-final-draft');export=base/'docs/benchmarks/2026-10-04-table-transitions-integration';export.mkdir(parents=True,exist_ok=True)
out=export.parent/'2026-10-04-table-transitions-integration-verification.json';assert not out.exists()
d=json.loads(original.read_text());d['previousDraft']={'path':str(original),'sha256':sha(original),'scope':'Immutable initial draft/script/copies retained.'}
oldCopies=d['exports'];d['exports']=[]
for row in oldCopies:
 p=Path(row['draftCopy']);assert sha(p)==row['sha256'];target=export/p.name
 target.write_bytes(p.read_bytes());d['exports'].append({**row,'draftCopy':str(target),'proposedExport':str(target.relative_to(base))})
new=[('initial-draft.json',original),('initial-assembly.py',Path('/tmp/assemble-fidelity21-integration.py')),('manual-independent-review.json',Path('/tmp/rostrum-s21-independent-manual-review.json'))]
for p in Path('/tmp/lectern-fidelity21-integration-performance-preacceptance').iterdir():new.append(('performance-preacceptance-'+p.name,p))
new.append(('manual-addendum-assembly.py',Path(__file__)))
for name,p in new:
 target=export/name;target.write_bytes(p.read_bytes());h=sha(p);d['pins'][str(p)]=h;d['pins'][str(target)]=h;d['exports'].append({'source':str(p),'draftCopy':str(target),'proposedExport':str(target.relative_to(base)),'sha256':h})
d['manual']['independentReview']={'path':'/tmp/rostrum-s21-independent-manual-review.json','sha256':sha('/tmp/rostrum-s21-independent-manual-review.json')}
d['performance']['pendingPacketSnapshot']={'directory':'/tmp/lectern-fidelity21-integration-performance-preacceptance','status':'Pending independent numerical review; retained before accepted wording updates.'}
d['assemblyScript']=str(Path(__file__));d['assemblyScriptSHA256']=sha(__file__)
for p,h in d['pins'].items():assert sha(p)==h,p
out.write_text(json.dumps(d,indent=2,sort_keys=True)+'\n');print(json.dumps({'manifest':str(out),'sha256':sha(out),'physicalPins':len(d['pins']),'sourcePins':len(d['sourcePins']),'exports':len(d['exports'])}))
