from pathlib import Path
from datetime import datetime,timezone
import json,hashlib,subprocess,re
ROOT=Path('/Users/welshofer/Developer/rostrum'); FONT=Path('/Users/welshofer/.codex/worktrees/rostrum-fonts/rostrum')
DRAFT=Path('/tmp/lectern-fidelity21-integration-accepted-performance'); EXPORT=DRAFT/'docs/benchmarks/2026-10-04-table-transitions-integration';EXPORT.mkdir(parents=True,exist_ok=True)
OUT=EXPORT.parent/'2026-10-04-table-transitions-integration-verification.json';assert not OUT.exists()
checkpoint='33e484edf53f8b3ba817b28e6717d27fe265a94c'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],stderr=subprocess.DEVNULL)
pins={};copies=[];resolutions=[];aliases={}
roots=[ROOT,*[Path('/Users/welshofer/.codex/worktrees')/w/'rostrum' for w in ['rostrum-metadata','rostrum-tables','rostrum-fonts']]]
revisions=[checkpoint,'73de22c42dc704c81f9fe8c03ee310def68c4dc3','1a84f4f0af2e1566828959bcc64c4daed92aca09','89aa1633cbbd07c152eb9e456c12e15686f7dbb8','acc709855fb1faa758af991d1f358629c8c6775a','8759edd1234318caed9e984efe0910d60ce46b53','3bab3d552ea016035921ce97671356152718ee05','119b1c107ff9911bdc86241e0e86a7a323a3b087','dc40a98b09d0db7c132c82c9e8f41b12dd4c5638','20e4a3556724f20937fcbca7208728798b658fcd','007efa9c5b1c56af36d5251937fe95244ffaa289']
def pin(p,expected=None):
 p=Path(p).resolve();original=p
 if expected and (not p.is_file() or sha(p)!=expected):
  key=(str(p),expected)
  if key in aliases:p=aliases[key]
  else:
   relative=next((p.relative_to(r) for r in roots if p.is_relative_to(r)),None)
   assert relative is not None,(str(p),expected,'No historical source path')
   for rev in revisions:
    try:data=git('show',rev+':'+str(relative))
    except subprocess.CalledProcessError:continue
    if hashlib.sha256(data).hexdigest()!=expected:continue
    p=DRAFT/'historical-source'/rev/relative;p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():assert p.read_bytes()==data
    else:p.write_bytes(data)
    aliases[key]=p;resolutions.append({'original':str(original),'sha256':expected,'retained':str(p),'revision':rev,'reason':'Exact historical Git blob; original evidence and advanced checkout unchanged.'});break
   else:raise AssertionError((str(original),expected,'Historical pin not resolved'))
 assert p.is_file(),p
 h=sha(p);assert expected is None or h==expected,(str(p),expected,h)
 assert str(p) not in pins or pins[str(p)]==h
 pins[str(p)]=h;return p

def recurse(v):
 if isinstance(v,dict):
  for k,x in v.items():
   if isinstance(k,str) and k.startswith('/') and isinstance(x,str) and re.fullmatch('[a-f0-9]{64}',x):pin(k,x)
   if isinstance(x,str) and x.startswith('/'):
    expected=next((v[z] for z in [k+'SHA256',k+'Sha256',k+'SHA',k+'Hash'] if isinstance(v.get(z),str) and re.fullmatch('[a-f0-9]{64}',v[z])),None)
    if k in ['path','receipt']:expected=v.get('sha256',v.get('SHA256',expected))
    if expected:pin(x,expected)
    elif Path(x).is_file():pin(x)
   recurse(x)
 elif isinstance(v,list):
  for x in v:recurse(x)

def copy(p,name):
 p=pin(p);t=EXPORT/name
 if t.exists():assert sha(t)==sha(p)
 else:t.write_bytes(p.read_bytes())
 copies.append({'source':str(p),'draftCopy':str(t),'proposedExport':str(t.relative_to(DRAFT)),'sha256':sha(p)})


prior=Path('/tmp/lectern-fidelity21-integration-final-draft/docs/benchmarks/2026-10-04-table-transitions-integration-verification.json')
assert sha(prior)=='3f7e523fd9e487e8281cd8a3d4e5848397292f3a7e56fb0547724705ffdc63d0'
d=load(prior)
for p,h in d['pins'].items():pin(p,h)
for row in d['exports']:
 p=Path(row['draftCopy']);pin(p,row['sha256']);copy(p,p.name)
copy(prior,'manual-addendum-draft.json');copy('/tmp/assemble-fidelity21-integration-manual-addendum.py','manual-addendum-assembly.py')
report=FONT/'docs/TABLE-TRANSITIONS-PERFORMANCE-20261004-21.md';wrapper=FONT/'docs/benchmarks/2026-10-04-table-transitions-layout-21-export.json';w=load(wrapper)
assert 'PENDING' not in w['status'],w['status']
assert sha(report)==w['reportSHA256']
# Exact pending packet snapshots resolve reviewed pre-acceptance report hashes after wording changes.
for name in ['TABLE-TRANSITIONS-PERFORMANCE-20261004-21.md','2026-10-04-table-transitions-layout-21-export.json']:
 p=Path('/tmp/lectern-fidelity21-integration-performance-preacceptance')/name
 current=report if name.endswith('.md') else wrapper
 aliases[(str(current.resolve()),sha(p))]=p
physical=FONT/'.build/perf33-table-transitions/verification.json'
pin(physical,w['originalVerificationSHA256']);recurse(load(physical));copy(physical,'performance-physical-verification.json')
for row in w['exports']:
 p=FONT/row['tracked'];pin(p,row['SHA256']);pin(row['original'],row['SHA256']);copy(p,'performance-'+p.name)
copy(report,'performance-report.md');copy(wrapper,'performance-export-wrapper.json')
for name,h in [('review','1e1c413501fac9e82c7dad1b4ea0be3e949d3ea1619d995e37ba632e1d20461a'),('closure','fa65bee729ceb4bf0dc0c2e43861fb1008bd57dae9868c54f9959895b8c4ddf1')]:
 p=Path('/tmp/rostrum-s21-independent-performance-'+name+'.json');pin(p,h);recurse(load(p));copy(p,'performance-independent-'+name+'.json')
copy(__file__,'accepted-performance-assembly.py')
d['status']='FINAL_DRAFT_ACCEPTED_PERFORMANCE_INTEGRATION_REVIEW_PENDING'
d['previousManualAddendumDraft']={'path':str(prior),'sha256':sha(prior)}
d['performance']={'status':w['status'],'scope':w['scope'],'report':str(report),'reportSHA256':sha(report),'wrapper':str(wrapper),'wrapperSHA256':sha(wrapper),'exportCopies':len(w['exports']),'physicalVerification':str(physical),'physicalVerificationSHA256':sha(physical),'independentNumericalReview':'/tmp/rostrum-s21-independent-performance-review.json','independentClosure':'/tmp/rostrum-s21-independent-performance-closure.json','pendingHistory':'Original initial and manual-addendum drafts plus pending report/wrapper snapshots retained unchanged.','children':748,'primaryComparisons':35,'claim':'Every primary interval crosses zero; no speedup or universal nonregression claim.'}
d['pins']=pins;d['exports']=copies;d['historicalSourcePinResolutions']+=resolutions;d['assemblyScript']=str(Path(__file__));d['assemblyScriptSHA256']=sha(__file__);d['createdUTC']=datetime.now(timezone.utc).isoformat()
for p,h in pins.items():assert sha(p)==h,p
for row in copies:assert sha(row['draftCopy'])==row['sha256']
OUT.write_text(json.dumps(d,indent=2,sort_keys=True)+'\n');print(json.dumps({'manifest':str(OUT),'sha256':sha(OUT),'physicalPins':len(pins),'sourcePins':len(d['sourcePins']),'copies':len(copies),'historicalResolutions':len(resolutions)}))
