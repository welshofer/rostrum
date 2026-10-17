"""Recheck the exact retained historical binaries: this-file.py BINARY_DIRECTORY OUTPUT.json."""
import hashlib, json, platform, statistics, subprocess, tempfile, time, sys
from pathlib import Path
old=Path(sys.argv[1])
out=Path(sys.argv[2])
prior=json.loads(Path('docs/benchmarks/2026-10-16-repeated-headers.json').read_text())
for name in ['baseline','candidate']:
    assert hashlib.sha256((old/name).read_bytes()).hexdigest()==prior['binary_hashes'][name]
record={'baseline_commit':prior['baseline_commit'], 'candidate_commit':'feee4eaf7ab97202776bc1afd537b031d20f9142',
        'platform':platform.platform(),'binary_hashes':{k:prior['binary_hashes'][k] for k in ['baseline','candidate']},'pairs':[]}
def run(variant,rows,labels):
    with tempfile.NamedTemporaryFile() as usage:
        start=time.perf_counter()
        p=subprocess.run([str(old/'measure-child'),usage.name,str(old/variant),str(rows),labels,'measured','5','compose'],capture_output=True,text=True,check=True)
        return {'samples':json.loads(p.stdout),'process_elapsed_ms':(time.perf_counter()-start)*1000,**json.load(usage)}
for pair in range(10):
    for rows,labels in [(24,'distinct'),(1000,'distinct'),(1000,'repeated')]:
        order=['baseline','candidate'] if pair%2==0 else ['candidate','baseline']
        item={'pair':pair,'rows':rows,'labels':labels,'order':order}
        for variant in order:item[variant]=run(variant,rows,labels)
        record['pairs'].append(item)
    out.write_text(json.dumps(record,indent=2)+'\n')
    print('Completed reproduction pair',pair+1,flush=True)
for rows,labels in [(24,'distinct'),(1000,'distinct'),(1000,'repeated')]:
    items=[p for p in record['pairs'] if (p['rows'],p['labels'])==(rows,labels)]
    print(rows,labels)
    for key in ['plan_cpu_ms','compose_cpu_ms','process_cpu_ms','process_elapsed_ms','rss_kib']:
        def val(p,v):return p[v][key] if key in p[v] else statistics.median(s[key] for s in p[v]['samples'][1:])
        deltas=[(val(p,'candidate')/val(p,'baseline')-1)*100 for p in items]
        print(key,'paired %',round(statistics.median(deltas),3),'slower pairs',sum(d>0 for d in deltas),'of',len(deltas))
