from pathlib import Path
from datetime import datetime,timezone
import json,hashlib,subprocess,re
ROOT=Path('/path/to/user/Developer/rostrum');DRAFT=Path('/tmp/lectern-fidelity21-integration-draft');EXPORT=DRAFT/'docs/benchmarks/2026-10-04-table-transitions-integration';EXPORT.mkdir(parents=True,exist_ok=True)
OUT=EXPORT.parent/'2026-10-04-table-transitions-integration-verification.json'
assert not OUT.exists(),'Preserve original draft and assembly script'
checkpoint='33e484edf53f8b3ba817b28e6717d27fe265a94c'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],stderr=subprocess.DEVNULL)
primary={
'external':'/tmp/lectern-fidelity21-external.json','comments':'/tmp/lectern-fidelity21-comment-differences.json',
'gate':'/tmp/rostrum-fidelity21-gate-audit.json','app-summary':'/tmp/lectern-fidelity21-test-summary.json',
'manual':'/tmp/lectern-fidelity21-manual/manual-table-transitions-verification.json',
'worker':'/tmp/lectern-transitions21-worker-receipt.json',
'source':'/tmp/rostrum-s21-independent-source-review.json','readiness':'/tmp/rostrum-s21-independent-readiness-review.json',
'native':'/tmp/rostrum-s21-independent-generated-native-review.json',
'native-proposal':'/tmp/rostrum-s21-independent-native-proposal-review.json',
'native-initial-parser':'/tmp/rostrum-s21-independent-initial-parser-review.json',
'native-import-failure':'/tmp/rostrum-s21-independent-import-review-failure.json',
'root-equality':'/tmp/rostrum-s21-independent-root-equality-review.json',
'browser-summary':'/tmp/rostrum-s21-independent-webkit-regression-review-v2.json',
'browser-transitions':'/tmp/lectern-fidelity21-transitions-webkit/independent-final/review-receipt.json',
'browser-history':'/tmp/rostrum-s21-independent-webkit-regression-review.json',
'prior-hosted':'/tmp/rostrum-fidelity20-github-check-runs-final.json'}
summary=load(primary['browser-summary'])
for row in summary['groups']:primary['browser-'+row['group']]=row['receipt']
primary={k:Path(v) for k,v in primary.items()}
assert sha(primary['manual'])=='ca3eefdd624ab371897aa6ef81edd5454d5b845dc8b0a4a46e2877fcd94470ff'
pins={};copies=[];resolutions=[];aliases={}
roots=[ROOT,*[Path('/path/to/user/.codex/worktrees')/w/'rostrum' for w in ['rostrum-metadata','rostrum-tables','rostrum-fonts']]]
revisions=[checkpoint,'89aa1633cbbd07c152eb9e456c12e15686f7dbb8','acc709855fb1faa758af991d1f358629c8c6775a','8759edd1234318caed9e984efe0910d60ce46b53','3bab3d552ea016035921ce97671356152718ee05','119b1c107ff9911bdc86241e0e86a7a323a3b087','dc40a98b09d0db7c132c82c9e8f41b12dd4c5638','20e4a3556724f20937fcbca7208728798b658fcd','007efa9c5b1c56af36d5251937fe95244ffaa289']
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

for label,p in primary.items():pin(p);recurse(load(p));copy(p,label+'.json')
for label,p in primary.items():
 if not label.startswith('browser-') or label in ['browser-summary','browser-history']:continue
 for i,row in enumerate(load(p).get('results',[])):
  for field in ['cases','comparison','log','adapter']:
   v=row.get(field)
   if isinstance(v,str) and Path(v).is_file():copy(v,f'{label}-{i}-{field}{Path(v).suffix}')
# Retain the original capture, parser, worker and external-adapter histories.
for pattern in ['lectern-transitions21-*.log','lectern-fidelity21-external-verifier*.log','prepare-fidelity21-generated-native*.py','prepare-fidelity21-generated-native*failure*','verify-fidelity21*py','review-s21*.py']:
 for p in sorted(Path('/tmp').glob(pattern)):copy(p,'history-'+p.name)
for p in sorted(Path('/tmp/lectern-fidelity21-generated-native').rglob('*')):
 if p.is_file():
  pin(p)
  if p.suffix in ['.json','.log','.txt']:
   if p.suffix=='.json':recurse(load(p))
   copy(p,'native-'+str(p.relative_to('/tmp/lectern-fidelity21-generated-native')).replace('/','-'))
for p in ['/tmp/rostrum-fidelity21-verify.log','/tmp/lectern-fidelity21-manual/verify-table-transitions-workflows.py',__file__]:pin(p)
prior=ROOT/'docs/benchmarks/2026-10-04-table-paint-reuse-integration-verification.json'
copy(prior,'accepted-S20-integration-reference.json')
sourcePaths=['Sources','Lectern/App','Lectern/AppTests','Lectern/Sources','Lectern/Tests','Tests/RostrumTests/TableBorderTransitionTests.swift','Tests/RostrumTests/Fixtures/NativeTableTransitions','Lectern/scripts','scripts/verify.sh','.github/workflows/ci.yml']
sourcePins={}
for name in git('ls-tree','-r','--name-only',checkpoint,'--',*sourcePaths).decode().splitlines():
 data=git('show',checkpoint+':'+name);sourcePins[name]=hashlib.sha256(data).hexdigest()
external=load(primary['external']);gate=load(primary['gate']);manual=load(primary['manual']);worker=load(primary['worker']);native=load(primary['native']);transitions=load(primary['browser-transitions'])
result={'status':'DRAFT_INTEGRATION_EVIDENCE_PERFORMANCE_ACCEPTANCE_PENDING','createdUTC':datetime.now(timezone.utc).isoformat(),'sourceCheckpoint':checkpoint,'sourcesTree':git('rev-parse',checkpoint+':Sources').decode().strip(),'headAtAssembly':git('rev-parse','HEAD').decode().strip(),'engineCommit':revisions[1],'workerCommit':revisions[2],
'gate':gate,'catalog':external['catalogTotals'],'externalTotals':external['totals'],
'outputPreservation':{'priorPackages':external['wholePriorPackageCount'],'priorByteExact':external['byteIdenticalPriorPackages'],'priorCommentOnly':len(external['labPackageDifferences']),'allPriorSVGBytesExact':external['allPriorSVGBytesExact'],'nativeInputRows':len(external['nativeSourceIdentity'])},
'browser':{'priorCases':summary['allFreshBrowserCases'],'priorGlyphs':summary['allFreshVisibleGlyphs'],'priorOmissions':summary['allExplicitOmissions'],'groups':summary['groups'],'newTransitions':transitions['totals'],'totalCases':summary['allFreshBrowserCases']+transitions['totals']['cases'],'totalGlyphs':summary['allFreshVisibleGlyphs']+transitions['totals']['glyphs']},
'native':{k:v for k,v in native.items() if k not in ['pins','rows']},
'manual':{'receipt':str(primary['manual']),'sha256':sha(primary['manual']),'variants':[{k:v for k,v in x.items() if k not in ['files','svgComparison']} for x in manual['variants']],'scope':manual['scope']},
'performance':{'status':'PENDING_REVIEWED_WORKER_PACKET_AND_NUMERICAL_ACCEPTANCE','readinessReceipt':str(primary['readiness']),'rootExecutionAttestation':'748 children completed once; results being analyzed. No timing gain or acceptance inferred.','finalReviewReceipt':None,'report':None},
'failureHistory':{'worker':worker['history'],'external':'First adapter referenced nonexistent S20 partial-native path; corrected to immutable S19 input. Initial script and failed log retained.','nativePreflight':'Initial helper compared obfuscated package font bytes with decoded TTF SHA; corrected helper compares original package bytes. No fixture or specimen change.','nativeAndBrowserParsers':'Initial parser/import and prior browser descriptor traversal failures retained alongside corrected independent receipts. No tolerances relaxed or captures modified.'},
'knownGapS22':'Selected fill image inventory/export omission remains outside S21 acceptance; S22 follows separately.',
'pins':pins,'sourcePins':sourcePins,'sourcePinScope':{'paths':sourcePaths,'method':'Immutable git blobs at sourceCheckpoint; not an entire-repository denominator and not interchangeable with earlier source counts.'},'exports':copies,'historicalSourcePinResolutions':resolutions,'proposedReport':'docs/LAYOUT-FIDELITY-20261004-21.md','proposedManifest':str(OUT.relative_to(DRAFT)),'trackedRootFilesWritten':False,'originalEvidenceModified':False,'assemblyScript':str(Path(__file__)),'assemblyScriptSHA256':sha(__file__)}
for p,h in pins.items():assert sha(p)==h,p
OUT.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n');print(json.dumps({'manifest':str(OUT),'sha256':sha(OUT),'physicalPins':len(pins),'sourcePins':len(sourcePins),'exports':len(copies),'historicalResolutions':len(resolutions),'browserCases':result['browser']['totalCases'],'browserGlyphs':result['browser']['totalGlyphs']}))
