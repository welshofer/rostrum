from pathlib import Path
from datetime import datetime,timezone
import json,hashlib,subprocess,re
ROOT=Path('/Users/welshofer/Developer/rostrum');DRAFT=Path('/tmp/lectern-fidelity20-integration-draft');EXPORT=DRAFT/'docs/benchmarks/2026-10-04-table-paint-reuse-integration';EXPORT.mkdir(parents=True,exist_ok=True)
OUT=EXPORT.parent/'2026-10-04-table-paint-reuse-integration-verification.json'
assert not OUT.exists(),'Preserve original draft and assembly script'
checkpoint='5d3d888175d12f615a3f917e15d8c9b6a170f201'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],stderr=subprocess.DEVNULL)
primary={
'external':'/tmp/lectern-fidelity20-external.json','comments':'/tmp/lectern-fidelity20-comment-differences.json',
'gate':'/tmp/lectern-fidelity20-gate-audit.json','app-summary':'/tmp/lectern-fidelity20-test-summary.json',
'manual':'/tmp/lectern-fidelity20-manual/manual-table-appearance-verification.json',
'headless-appearance':'/tmp/lectern-fidelity20-appearance-pipeline/verification.json',
'worker':'/tmp/lectern-fidelity20-worker-test-receipt.json',
'source-initial':'/tmp/rostrum-s20-independent-source-review.json',
'source-closure':'/tmp/rostrum-s20-independent-source-review-closure.json',
'source-baseline-scope':'/tmp/rostrum-s20-independent-source-review-baseline-scope.json',
'readiness':'/tmp/rostrum-s20-independent-readiness-review.json',
'browser-summary':'/tmp/rostrum-s20-independent-webkit-regression-review.json',
'prior-hosted':'/tmp/rostrum-fidelity19-github-check-runs-final.json'}
summary=load(primary['browser-summary'])
for row in summary['groups']:primary['browser-'+row['group']]=row['receipt']
primary={k:Path(v) for k,v in primary.items()}
assert sha(primary['manual'])=='8297df11afa469112d6ddeb3d96581d0e43f8301560804dfde1d67fe5876274b'
pins={};copies=[];resolutions=[];aliases={}
roots=[ROOT,*[Path('/Users/welshofer/.codex/worktrees')/w/'rostrum' for w in ['rostrum-metadata','rostrum-tables','rostrum-fonts']]]
revisions=[checkpoint,'8759edd1234318caed9e984efe0910d60ce46b53','3bab3d552ea016035921ce97671356152718ee05','119b1c107ff9911bdc86241e0e86a7a323a3b087','dc40a98b09d0db7c132c82c9e8f41b12dd4c5638','20e4a3556724f20937fcbca7208728798b658fcd','007efa9c5b1c56af36d5251937fe95244ffaa289']
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
 if not label.startswith('browser-') or label=='browser-summary':continue
 for i,row in enumerate(load(p).get('results',[])):
  for field in ['cases','comparison','log','adapter']:
   v=row.get(field)
   if isinstance(v,str) and Path(v).is_file():copy(v,f'{label}-{i}-{field}{Path(v).suffix}')
# Keep actual failed attempts and their corrected logs, rather than rewriting success into them.
for pattern in ['lectern-fidelity20-worker-focused*.log','lectern-fidelity20-worker-test-summary*.json','lectern-fidelity20-appearance-helper-*.log','review-s20-readiness*.log']:
 for p in sorted(Path('/tmp').glob(pattern)):copy(p,'history-'+p.name)
for p in ['/tmp/rostrum-fidelity20-verify.log','/tmp/verify-fidelity20-external.py','/tmp/verify-fidelity20-comment-differences.py','/tmp/lectern-fidelity20-manual/verify-table-appearance-workflows.py','/tmp/verify-s20-appearance-pipeline.py',__file__]:pin(p)
# Retain source review prototype manifest, including its failed test history.
prototype=ROOT/'docs/benchmarks/2026-10-04-table-paint-reuse-prototype.json'
copy(prototype,'prototype-preservation.json');recurse(load(prototype))
copy(ROOT/'docs/TABLE-PAINT-REUSE-PROTOTYPE-20261004.md','prototype-report.md')
# Native numerical acceptance remains S19; source identity is freshly established by S20 external review.
prior=ROOT/'docs/benchmarks/2026-10-04-partial-table-styles-integration-verification.json'
copy(prior,'accepted-S19-integration-reference.json')
sourcePaths=['Sources','Lectern/App','Lectern/AppTests','Lectern/Sources','Lectern/Tests','Tests/RostrumTests/TableBorderPaintReuseTests.swift','Lectern/scripts','scripts/verify.sh','.github/workflows/ci.yml']
sourcePins={}
for name in git('ls-tree','-r','--name-only',checkpoint,'--',*sourcePaths).decode().splitlines():
 h=hashlib.sha256(git('show',checkpoint+':'+name)).hexdigest();assert sha(ROOT/name)==h,name;sourcePins[name]=h
external=load(primary['external']);gate=load(primary['gate']);manual=load(primary['manual']);worker=load(primary['worker'])
result={'status':'DRAFT_INTEGRATION_EVIDENCE_PERFORMANCE_ACCEPTANCE_PENDING','createdUTC':datetime.now(timezone.utc).isoformat(),'sourceCheckpoint':checkpoint,'sourcesTree':git('rev-parse',checkpoint+':Sources').decode().strip(),'headAtAssembly':git('rev-parse','HEAD').decode().strip(),'engineCommit':revisions[2],'engineDocumentationCommit':revisions[3],'workerCommit':revisions[1],
'gate':gate,'catalog':external['catalogTotals'],'externalTotals':external['totals'],'outputPreservation':{'packages':88,'byteExact':84,'commentUUIDTimestampOnly':4,'allSVGBytesExact':236,'nativeInputRowsExact':21,'noNewNativeExportsClaimed':True},'browser':{'cases':summary['allFreshBrowserCases'],'glyphs':summary['allFreshVisibleGlyphs'],'omissions':summary['allExplicitOmissions'],'groups':summary['groups']},
'manual':{'receipt':str(primary['manual']),'sha256':sha(primary['manual']),'variants':2,'checksEach':20,'findingsEach':7,'slidesEach':3,'sourceTextNodesEach':27,'sourcePure':True,'scope':'Root-observed UI Run/Inspect/Export. Saved previews and source match separate headless public recipe outputs. AppTest captures were temporary and not retained.'},
'knownGapS22':'Direct and table-style fill image bytes remain in PPTX; inspector reports media but actual folder export has zero media. Existing omitted image-fill extraction remains unfixed in S20. No complete asset-export claim.',
'performance':{'status':'PENDING_REVIEWED_WORKER_PACKET_AND_NUMERICAL_ACCEPTANCE','readinessReceipt':str(primary['readiness']),'rootExecutionAttestation':'660 children completed once; results being analyzed. No timing gain or acceptance inferred here.','finalReviewReceipt':None,'report':None},
'failureHistory':{'workerApp':worker['history'],'headlessAppearance':load(primary['headless-appearance'])['firstAttempt'],'headlessCorrection':load(primary['headless-appearance'])['correction'],'prototype':'Initial diagnostic-location comparison assumption corrected; retained original and corrected prototype evidence. Prototype baseline omitted previous ordinary-text reuse; formal baseline and root include it.','readiness':'Initial audit traversal/schema and historical audit-source pin failures retained, corrected readiness passed. No frozen timing input changed.'},
'pins':pins,'sourcePins':sourcePins,'exports':copies,'historicalSourcePinResolutions':resolutions,'proposedReport':'docs/LAYOUT-PERFORMANCE-20261004-20.md','proposedManifest':str(OUT.relative_to(DRAFT)),'trackedRootFilesWritten':False,'originalEvidenceModified':False,'assemblyScript':str(Path(__file__)),'assemblyScriptSHA256':sha(__file__)}
for p,h in pins.items():assert sha(p)==h,p
OUT.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n');print(json.dumps({'manifest':str(OUT),'sha256':sha(OUT),'physicalPins':len(pins),'sourcePins':len(sourcePins),'exports':len(copies),'historicalResolutions':len(resolutions)}))
