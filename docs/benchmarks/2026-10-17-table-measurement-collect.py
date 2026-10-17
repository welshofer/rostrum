"""Release composition comparison. Run from repo root with SCRATCH OUTPUT.json.
Build baseline{,-spans,-vertical,-headers} and candidate equivalents first.
No concurrent builds/tests; retain all alternating pairs and adverse controls.
"""
import hashlib, json, os, platform, statistics, subprocess, sys, tempfile, time, zipfile
from pathlib import Path
from pptx import Presentation
scratch,output=map(Path,sys.argv[1:3])
if hasattr(os,'sched_setaffinity'):os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
launcher=scratch/'measure-child'
subprocess.run(['cc','-O2','docs/benchmarks/2026-10-16-measure-child.c','-o',str(launcher)],check=True)
root=scratch/'preservation'
mode=sys.argv[3] if len(sys.argv)>3 else 'all'
assert mode in ('all','preserve','measure')
if mode!='measure':root.mkdir(exist_ok=False)
kinds=['','-spans','-vertical','-headers']
drivers=['2026-10-12-table-preparation.swift','2026-10-12-table-spans.swift','2026-10-16-table-row-pagination.swift','2026-10-16-repeated-headers.swift']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
record={'baseline_commit':'6bd5ca166aaf3c9c31547faf257a3e63bb9aa186','platform':platform.platform(),
 'cpu_affinity':sorted(os.sched_getaffinity(0)) if hasattr(os,'sched_getaffinity') else None,
 'swift_version':subprocess.check_output(['swift','--version'],text=True).strip(),
 'binary_hashes':{v+k:sha(scratch/(v+k)) for v in ['baseline','candidate'] for k in kinds},
 'source_hashes':[{'path':str(p),'sha256':sha(p)} for p in sorted(Path('Sources').rglob('*.swift'))],
 'driver_hashes':[{'path':str(p),'sha256':sha(p)} for p in [*[Path('docs/benchmarks')/d for d in drivers],Path(__file__),Path('docs/benchmarks/2026-10-16-measure-child.c')]],
 'memory_method':'wait4 in native launcher; fork after exec avoids collector RSS inheritance',
 'preservation':[],'pairs':[]}
for kind in kinds if mode!='measure' else []:
 for rows,labels,sizing in [(24,'distinct','measured'),(28,'mixed','measured'),(100,'distinct','measured'),(24,'distinct','estimated')]:
  paths=[]
  for variant in ['baseline','candidate']:
   path=root/f'{variant}{kind}-{rows}-{labels}-{sizing}'
   subprocess.run([str(scratch/(variant+kind)),str(rows),labels,sizing,'1','artifacts',str(path)],check=True,stdout=subprocess.DEVNULL)
   paths.append(path)
  names=sorted(p.name for p in paths[0].iterdir())
  assert names==sorted(p.name for p in paths[1].iterdir())
  for name in names:
   a,b=[(p/name).read_bytes() for p in paths]
   assert json.loads(a)==json.loads(b) if name.endswith('.json') else a==b,(kind,rows,labels,sizing,name)
  with zipfile.ZipFile(paths[1]/'saved.pptx') as archive:assert archive.testzip() is None
  deck=Presentation(paths[1]/'saved.pptx');pages=json.loads((paths[1]/'geometry.json').read_text())
  source=json.loads((paths[1]/'source.json').read_text()) if (paths[1]/'source.json').exists() else None
  header_count=2 if kind=='-headers' else 1
  assert [r for p in pages for r in p['body_rows']]==list(range(header_count,rows+header_count))
  for i,page in enumerate(pages):
   table,=[s.table for s in deck.slides[i+1].shapes if s.has_table]
   assert [r.height for r in table.rows]==page['heights']
   assert [c.width for c in table.columns]==page['widths']
   if source:assert [[c.text for c in r.cells] for r in table.rows]==[source[r] for r in page['source_rows']]
   for c in page['cells']:
    native=table.cell(c['row'],c['column'])
    assert native.is_spanned==c.get('covered',False)
    if not c.get('covered',False):
     assert native.span_width==c.get('span',1) and native.span_height==c.get('rowSpan',1)
     assert sum(page['heights'][c['row']:c['row']+c.get('rowSpan',1)])>=c['height']
  record['preservation'].append({'kind':kind or 'plain','rows':rows,'labels':labels,'sizing':sizing,'identical_files':len(names),'independent_grid_check':True})
  print('Preserved',kind or 'plain',rows,labels,sizing,len(names),'files',flush=True)
if mode=='preserve':
 output.write_text(json.dumps(record,indent=2,sort_keys=True)+'\n');raise SystemExit(0)
if mode=='measure':
 previous=json.loads((scratch/'preservation.json').read_text())
 assert previous['binary_hashes']==record['binary_hashes']
 record['preservation']=previous['preservation']
def run(args):
 with tempfile.NamedTemporaryFile() as usage:
  start=time.perf_counter()
  p=subprocess.run([str(launcher),usage.name,*map(str,args)],capture_output=True,text=True,check=True)
  return {'samples':json.loads(p.stdout),'process_elapsed_ms':(time.perf_counter()-start)*1000,**json.load(usage)}
cases=[('',24,'distinct','measured'),('',1000,'distinct','measured'),('',1000,'repeated','measured'),
       ('',24,'distinct','estimated'),('-spans',24,'distinct','measured'),('-spans',1000,'distinct','measured'),
       ('-vertical',24,'distinct','measured'),('-vertical',1000,'distinct','measured'),
       ('-headers',24,'distinct','measured'),('-headers',1000,'distinct','measured')]
for pair in range(7):
 for kind,rows,labels,sizing in cases:
  order=['baseline','candidate'] if pair%2==0 else ['candidate','baseline']
  item={'pair':pair,'kind':kind or 'plain','rows':rows,'labels':labels,'sizing':sizing,'order':order}
  for v in order:item[v]=run([scratch/(v+kind),rows,labels,sizing,5,'compose'])
  record['pairs'].append(item)
 output.write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
 print('Completed alternating pair',pair+1,'of 7',flush=True)
for kind,rows,labels,sizing in cases:
 selected=[p for p in record['pairs'] if (p['kind'],p['rows'],p['labels'],p['sizing'])==(kind or 'plain',rows,labels,sizing)]
 print(kind or 'plain',rows,labels,sizing)
 for key in ['plan_cpu_ms','plan_ms','compose_cpu_ms','compose_ms','process_cpu_ms','process_elapsed_ms','rss_kib']:
  def val(p,v):return p[v][key] if key in p[v] else statistics.median(s[key] for s in p[v]['samples'][1:])
  deltas=[(val(p,'candidate')/val(p,'baseline')-1)*100 for p in selected]
  print(key,'baseline',statistics.median(val(p,'baseline') for p in selected),'candidate',statistics.median(val(p,'candidate') for p in selected),
        'paired_percent',statistics.median(deltas),'faster_pairs',sum(d<0 for d in deltas))
