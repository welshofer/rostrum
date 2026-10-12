# Run from the repository root; argument: directory holding both pairs of Release binaries.
import hashlib,json,os,platform,statistics,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path('/tmp/rostrum-prepared-fit')
(root/'proof').mkdir(exist_ok=True)
scenarios={'template':['plan-plain','plan-unique','fit-shrink','fit-shrink-unique','fit-tabs'],
 'authored':['plain-fallback','plain-registered','mixed','shrink','plain-fallback-unique','plain-registered-unique','mixed-unique','shrink-unique']}
rows=[]; summary={}; proofs=[]
for family,cases in scenarios.items():
 for scenario in cases:
  for pair in range(17):
   order=['baseline','candidate'] if pair%2==0 else ['candidate','baseline']
   for variant in order:
    command=[str(root/f'{family}-{variant}'),scenario]
    if pair==0: command.append(str(root/'proof'/f'{family}-{scenario}-{variant}.pptx'))
    p=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    output,error=p.stdout.read(),p.stderr.read()
    _,status,usage=os.wait4(p.pid,0); p.returncode=os.waitstatus_to_exitcode(status)
    p.stdout.close(); p.stderr.close()
    if p.returncode: raise RuntimeError(error)
    row=json.loads(output); row.update(family=family,variant=variant,pair=pair,warmup=pair<2,peakRSSKiB=usage.ru_maxrss)
    rows.append(row)
  name=family+'/'+scenario; summary[name]={}
  for variant in ['baseline','candidate']:
   samples=[r for r in rows if r['family']==family and r['scenario']==scenario and r['variant']==variant and not r['warmup']]
   summary[name][variant]=dict(cpuMedianMS=statistics.median(r['cpuMS'] for r in samples),elapsedMedianMS=statistics.median(r['elapsedMS'] for r in samples),elapsedP95MS=max(r['elapsedMS'] for r in samples),peakRSSMedianKiB=statistics.median(r['peakRSSKiB'] for r in samples),errors=sorted(set(r.get('error','') for r in samples)))
  pairs={}
  for r in rows:
   if r['family']==family and r['scenario']==scenario and not r['warmup']: pairs.setdefault(r['pair'],{})[r['variant']]=r['cpuMS']
  for pair in range(17):
   samples=[r for r in rows if r['family']==family and r['scenario']==scenario and r['pair']==pair]
   checks=[{k:v for k,v in r.items() if k not in ['variant','cpuMS','elapsedMS','peakRSSKiB']} for r in samples]
   assert checks[0]==checks[1],(name,pair,checks)
  changes=[100*(v['baseline']-v['candidate'])/v['baseline'] for v in pairs.values()]
  summary[name]['paired']=dict(cpuImprovementPercent=statistics.median(changes),fasterPairs=sum(v>0 for v in changes),pairs=len(changes))
  a=(root/'proof'/f'{family}-{scenario}-baseline.pptx').read_bytes(); b=(root/'proof'/f'{family}-{scenario}-candidate.pptx').read_bytes()
  proofs.append(dict(family=family,scenario=scenario,identical=a==b,baselineSHA256=hashlib.sha256(a).hexdigest(),candidateSHA256=hashlib.sha256(b).hexdigest()))
  print(name,json.dumps(summary[name]),'identical',a==b,flush=True)
  assert a==b,name
files=['Sources/Rostrum/Fonts/TextShaper.swift','Sources/Rostrum/Presentation/RichTextLayout.swift','Sources/Rostrum/Presentation/RichTextPreparation.swift','Sources/RostrumLayout/AuthoredLayoutEngine.swift','Sources/RostrumLayout/TemplateLayoutEngine.swift']
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
metadata=dict(date='2026-10-12',warmupPairs=2,measuredPairs=15,order='alternating AB/BA',baseline='64234fd1a4e851c819e9125f855b5877e5a4a5e6',compiler='Swift 6.1.3 Release (-O)',host=platform.platform(),cpu=next(l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),affinityCPUs=len(os.sched_getaffinity(0)),sourceSHA256={p:sha(p) for p in files},binarySHA256={f'{f}-{v}':sha(root/f'{f}-{v}') for f in scenarios for v in ['baseline','candidate']},drivers={f:sha(root/f'{f}.swift') for f in scenarios},fontSHA256={name:sha('Tests/RostrumTests/Fixtures/NativeGlyphPlacement/eligibility/fonts/'+name+'.ttf') for name in ['DejaVuSans','DejaVuSans-Bold','DejaVuSans-Oblique']},summary=summary,proofs=proofs,samples=rows)
(root/'paired-final.json').write_text(json.dumps(metadata,indent=2)+'\n')
