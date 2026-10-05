from pathlib import Path
from datetime import datetime, timezone
import json,hashlib,subprocess,re
ROOT=Path('/Users/welshofer/Developer/rostrum')
DRAFT=Path('/tmp/lectern-fidelity19-integration-draft')
EXPORT=DRAFT/'docs/benchmarks/2026-10-04-partial-table-styles-integration'
EXPORT.mkdir(parents=True,exist_ok=True)
MANIFEST=DRAFT/'docs/benchmarks/2026-10-04-partial-table-styles-integration-verification.json'
# All writes are confined to /tmp. No tracked report, manifest or prior evidence is replaced.
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def load(p):return json.loads(Path(p).read_text())
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args])
primary={
'external':'/tmp/lectern-fidelity19-external.json',
'comment-and-caption-differences':'/tmp/lectern-fidelity19-comment-differences.json',
'prior-svg-identity':'/tmp/lectern-fidelity19-prior-svg-identity.json',
'svg-difference-classification':'/tmp/lectern-fidelity19-svg-difference-classification.json',
'manual':'/tmp/lectern-fidelity19-manual/manual-partial-table-styles-verification.json',
'gate-audit':'/tmp/lectern-fidelity19-gate-audit.json','app-tests':'/tmp/lectern-fidelity19-test-summary.json',
'webkit-alignment':'/tmp/lectern-fidelity19-alignment-webkit/independent-final/review-receipt.json',
'webkit-markers':'/tmp/lectern-fidelity19-marker-webkit/independent-final-v3/review-receipt.json',
'webkit-paragraphs':'/tmp/lectern-fidelity19-glyph-webkit/independent-final-v3/review-receipt.json',
'webkit-mixed':'/tmp/lectern-fidelity19-mixed-webkit/independent-final/review-receipt.json',
'webkit-tables':'/tmp/lectern-fidelity19-tables-webkit/independent-final-v4/review-receipt.json',
'native-and-webkit-profiles':'/tmp/lectern-fidelity19-profiles-webkit/independent-final-v1/review-receipt.json',
'native-and-webkit-partial':'/tmp/lectern-fidelity19-partial-webkit/independent-final-v1/review-receipt.json',
'partial-parser-adaptation':'/tmp/lectern-fidelity19-partial-webkit/independent-final-v1/parser-adaptation-receipt.json',
'partial-paint-controls':'/tmp/lectern-fidelity19-partial-webkit/independent-final-v1/paint-controls-receipt.json',
'worker':'/tmp/lectern-partial-styles19-worker-receipt.json',
'worker-native-inputs-caption-delta':'/tmp/lectern-partial-styles19-native-inputs-and-caption-delta.json',
'worker-prior-historical-source':'/tmp/lectern-table-profiles18-historical-source-pins.json',
'engine-source-native-review':'/tmp/rostrum-s19-independent-source-native-review.json',
'engine-native-model-reproduction':'/tmp/rostrum-s19-model-reproduction.json',
'independent-readiness-review':'/tmp/rostrum-s19-independent-readiness-review.json',
'native-visual-review':'/tmp/lectern-fidelity19-generated-native/root-visual-review.json',
'original-native-capture':'/tmp/lectern-fidelity19-table-style-native/capture-receipt.json'}
for recipe in ['partialTableStyles','tableJoinProfiles']:
 for mode in ['false','true']:primary[f'native-{recipe}-{mode}']=f'/tmp/lectern-fidelity19-generated-native/{recipe}/alternative-{mode}/capture-receipt.json'
primary={k:Path(v) for k,v in primary.items()}
assert sha(primary['manual'])=='cbea605ae51c5b5f03823a4fe48b59b6b5b9290996d37bfaf7e3181ac4212709'
pins={};copies=[];resolutions=[];snapshots={}
roots=[ROOT,Path('/Users/welshofer/.codex/worktrees/rostrum-metadata/rostrum'),Path('/Users/welshofer/.codex/worktrees/rostrum-tables/rostrum'),Path('/Users/welshofer/.codex/worktrees/rostrum-fonts/rostrum')]
revisions=['fada328527acabccebfcd0da4ea8b2c5a92105ef','85e1e3946f9d34a93e500cd977e4741e249a8425','dc40a98b09d0db7c132c82c9e8f41b12dd4c5638','481586eda651f5eae6fa6bdbffb2361c664e585a','e9b65363fd7a2614139543093b8b6e988807d554']
def archive(original,expected,preferred=None):
 original=Path(original).resolve();key=(str(original),expected)
 if key in snapshots:return snapshots[key]
 relative=next((original.relative_to(r) for r in roots if original.is_relative_to(r)),None)
 assert relative is not None,(str(original),'No Git historical resolution')
 for rev in ([preferred] if preferred else [])+[r for r in revisions if r!=preferred]:
  try:data=git('show',rev+':'+str(relative))
  except subprocess.CalledProcessError:continue
  if hashlib.sha256(data).hexdigest()!=expected:continue
  target=DRAFT/'historical-source'/rev/relative;target.parent.mkdir(parents=True,exist_ok=True)
  if target.exists():assert target.read_bytes()==data
  else:target.write_bytes(data)
  snapshots[key]=target.resolve();resolutions.append({'originalPath':str(original),'sha256':expected,'gitRevision':rev,'gitPath':str(relative),'retainedSnapshot':str(target),'reason':'Additive immutable Git-blob snapshot; original receipt and advanced checkout remain unchanged.'})
  return target.resolve()
 raise AssertionError((str(original),expected,'No exact historical Git blob'))
def pin(p,expected=None):
 p=Path(p).resolve()
 if expected is not None and (not p.is_file() or sha(p)!=expected):p=archive(p,expected)
 assert p.is_file(),p
 h=sha(p);assert expected is None or h==expected
 assert str(p) not in pins or pins[str(p)]==h
 pins[str(p)]=h;return h
# Preserve all owned S19 source/resource blobs even before a worker checkout advances.
worker=load(primary['worker']);nativeInputs=load(primary['worker-native-inputs-caption-delta'])
for row in worker['ownedSourcePins']+nativeInputs['resources']:
 p=archive(row['path'],row['sha256'],revisions[0]);pin(p,row['sha256'])
def recurse(v):
 if isinstance(v,dict):
  for k,x in v.items():
   if isinstance(k,str) and k.startswith('/') and isinstance(x,str) and re.fullmatch('[a-f0-9]{64}',x):pin(k,x)
   if isinstance(x,str) and x.startswith('/'):
    expected=next((v[z] for z in [k+'SHA256',k+'Sha256',k+'SHA',k+'Hash'] if isinstance(v.get(z),str) and re.fullmatch('[a-f0-9]{64}',v[z])),None)
    if k=='path':expected=v.get('sha256',v.get('SHA256',expected))
    if expected is not None:pin(x,expected)
    elif Path(x).is_file():pin(x)
   recurse(x)
 elif isinstance(v,list):
  for x in v:recurse(x)
 elif isinstance(v,str) and v.startswith('/') and Path(v).is_file():pin(v)
def copy(p,name):
 p=Path(p);h=pin(p);target=EXPORT/name
 if target.exists():assert sha(target)==h,target
 else:target.write_bytes(p.read_bytes())
 copies.append({'source':str(p),'draftCopy':str(target),'proposedExport':str(target.relative_to(DRAFT)),'sha256':h})
for label,p in primary.items():
 pin(p);recurse(load(p));copy(p,label+'.json')
for label in ['webkit-alignment','webkit-markers','webkit-paragraphs','webkit-mixed','webkit-tables','native-and-webkit-profiles','native-and-webkit-partial']:
 for i,result in enumerate(load(primary[label])['results']):
  for field in ['cases','comparison','log','adapter']:
   value=result.get(field)
   if isinstance(value,str) and Path(value).is_file():copy(value,f'{label}-{i}-{field}{Path(value).suffix}')
# Retain all partial verifier controls, failure logs and adaptations alongside final receipts.
for p in sorted(primary['native-and-webkit-partial'].parent.iterdir()):
 if p.is_file() and p.suffix in ('.json','.txt','.log') and p.name not in ('review-receipt.json','parser-adaptation-receipt.json','paint-controls-receipt.json'):
  copy(p,'partial-evidence-'+p.name)
for row in worker['history']:copy(row['log']['path'],'worker-history-'+Path(row['log']['path']).name)
for p in ['/tmp/review-s19-readiness.log','/tmp/review-s19-readiness-2.log','/tmp/review-s19-readiness-final.log']:
 copy(p,'readiness-history-'+Path(p).name)
for p in [Path(__file__),Path('/tmp/rostrum-fidelity19-verify.log'),Path('/tmp/verify-fidelity19-external.py'),Path('/tmp/verify-fidelity19-comment-differences.py'),Path('/tmp/verify-fidelity19-prior-svg.py'),Path('/tmp/classify-fidelity19-svg-differences.py'),Path('/tmp/lectern-fidelity19-manual/verify-partial-table-styles-workflows.py'),Path('/tmp/audit-fidelity19-gate.py')]:pin(p)
# Source pins are against the actual root gate commit, never inferred from today's HEAD.
sourcePaths=['Sources','Lectern/App','Lectern/AppTests','Lectern/Sources','Lectern/Tests','Tests/RostrumTests/Fixtures/NativeTableDefault','Tests/RostrumTests/Fixtures/NativeTableJoins','Tests/RostrumTests/Fixtures/NativeTableJoinProfiles','Tests/RostrumTests/Fixtures/NativeTableStyleFallback','Tests/RostrumTests/NativeTableDefaultTests.swift','Tests/RostrumTests/NativeTableJoinProfileTests.swift','Tests/RostrumTests/NativeTableStyleFallbackTests.swift','Lectern/scripts','scripts/verify.sh','.github/workflows/ci.yml']
checkpoint='481586eda651f5eae6fa6bdbffb2361c664e585a';names=git('ls-tree','-r','--name-only',checkpoint,'--',*sourcePaths).decode().splitlines();sourcePins={}
for name in names:
 h=hashlib.sha256(git('show',checkpoint+':'+name)).hexdigest();assert sha(ROOT/name)==h,(name,'Root no longer matches accepted source');sourcePins[name]=h
manual=load(primary['manual']);pin(Path(manual['app'])/'Contents/MacOS/Lectern',manual['appBinarySHA256AtBothManualRuns'])
external=load(primary['external']);gate=load(primary['gate-audit']);browser={}
for label in ['webkit-alignment','webkit-markers','webkit-paragraphs','webkit-mixed','webkit-tables','native-and-webkit-profiles','native-and-webkit-partial']:
 d=load(primary[label]);assert d['status']=='PASS';browser[label]=d.get('totals') or {'PDFcomparisons':len(d['results']),'cases':sum(x['caseCount'] for x in d['results']),'glyphs':sum(x['visibleGlyphs'] for x in d['results']),'explicitOmissions':sum(x.get('explicitOmissions',0) for x in d['results'])}
result={'status':'DRAFT_EVIDENCE_ASSEMBLED_PERFORMANCE_ACCEPTANCE_PENDING','createdUTC':datetime.now(timezone.utc).isoformat(),'sourceCheckpoint':checkpoint,'sourcesTree':git('rev-parse',checkpoint+':Sources').decode().strip(),'headAtAssembly':git('rev-parse','HEAD').decode().strip(),'workerCommit':revisions[0],'engineCommit':revisions[1],'engineDocumentationCommit':revisions[2],
'gate':{'command':'scripts/verify.sh','exitCode':0,'suiteRuns':gate['suiteRuns'],'appExecutions':gate['appExecutions'],'failures':gate['xcresultFailed'],'expectedFailures':gate['xcresultExpected'],'skips':gate['xcresultSkipped'],'runtimeWarnings':gate['xcresultRuntimeWarnings'],'consoleDiagnosticCounts':gate['consoleDiagnosticCounts'],'stages':gate['stages'],'xcresult':gate['xcresult']},
'catalog':external['catalogTotals'],'externalTotals':external['totals'],'browserAndNative':browser,
'manual':{'receipt':str(primary['manual']),'sha256':sha(primary['manual']),'variants':2,'checksPerVariant':62,'findingsPerVariant':0,'loadedPreviewsPerVariant':3,'exportedSlidesPerVariant':3,'sourceUnchangedBeforeInspectionThroughExport':True,'observedBy':'Root native CUA; this assembly only verifies retained file evidence.'},
'pins':pins,'sourcePins':sourcePins,'exports':copies,'historicalSourcePinResolutions':resolutions,
'scope':'Actual package/inline custom styles default only truly absent effective cardinal edges to black 1 pt; present empty/noFill, unresolved wrappers, direct overrides and unrelated built-in/unknown/absent styles retain their scoped behavior. Twelve captured specimens/72 glyph traces/49 border intervals/15 fills. Bounded grid-line-constant solid paint joins. First two Lab pages retain exact specimens; third is a public API control outside numerical native acceptance. Glyph proof is trace origin/face/paint size, not outline ink parity.',
'priorDifferenceClassification':{'commentMetadata':'Four packages differ only valid consistent UUID/timestamp metadata.','profilesCaption':'Three S18 profile packages differ only approved third-page caption; both newly generated variants were recaptured natively. First two specimen pages remain exact.','tablesPublicPage':'S17 false variant page4 gains exactly four black 1-point default-border lines; all other XML exact. First three native specimen pages exact.','SVG':'40 prior special pairs:37 byte-exact, two profile third-page text/x-list changes and one table public-page four-line addition, each strictly classified.'},
'performance':{'status':'PENDING_INDEPENDENT_NUMERIC_REVIEW_AND_ROOT_ACCEPTANCE','readinessReceipt':str(primary['independent-readiness-review']),'readinessSHA256':sha(primary['independent-readiness-review']),'rootReportedExecution':'594 children completed once, exit0; timing results still being analyzed. No quantitative result or acceptance is inferred here.','finalReviewReceipt':None,'report':None},
'failureHistory':{'worker':worker['history'],'readiness':'Retained directory traversal error and reviewer count distinction (66 original changed SVGs,65 residual join pages); corrected final read-only audit passes.','browser':'Bounded parser adaptation and negative controls are retained with original extractor/control receipt pins; final S19 extraction logs pass. Historical helper failures are not reclassified as S19 app-gate failures. No native bounds or original captures changed.'},
'proposedReport':'docs/LAYOUT-FIDELITY-20261004-19.md','proposedManifest':str(MANIFEST.relative_to(DRAFT)),'proposedLabDocument':'docs/LIBRARY-LAB-20261002.md','originalEvidenceModified':False,'trackedRootFilesWritten':False}
for p,h in pins.items():assert sha(p)==h,p
MANIFEST.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(json.dumps({'manifest':str(MANIFEST),'sha256':sha(MANIFEST),'physicalPins':len(pins),'sourcePins':len(sourcePins),'exportCopies':len(copies),'historicalResolutions':len(resolutions),'status':result['status']}))
