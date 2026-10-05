from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,re,subprocess
ROOT=Path('/Users/welshofer/Developer/rostrum');DRAFT=Path('/tmp/lectern-fidelity20-integration-draft');FINAL=Path('/tmp/lectern-fidelity20-integration-final');DEST=FINAL/'docs/benchmarks/2026-10-04-table-paint-reuse-integration';DEST.mkdir(parents=True,exist_ok=True)
OUT=DEST.parent/'2026-10-04-table-paint-reuse-integration-verification.json'
INITIAL=DRAFT/'docs/benchmarks/2026-10-04-table-paint-reuse-integration-verification.json'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
assert sha(INITIAL)=='1d814cbf09c461ee04fd80e45677383a64650c28bc1cb77889c35c35123f2beb'
original=load(INITIAL);pins=dict(original['pins']);copies=[];aliases={};resolutions=[]
fonts=Path('/Users/welshofer/.codex/worktrees/rostrum-fonts/rostrum');packet=fonts/'.build/perf32-table-paint-reuse'
for old,new in [(fonts/'docs/TABLE-PAINT-REUSE-PERFORMANCE-20261004-20.md',packet/'report-before-acceptance.md'),(packet/'budget-audit.swift',packet/'budget-audit-initial.swift')]:
 aliases[(str(old.resolve()),sha(new))]=new

def pin(p,expected=None):
 p=Path(p).resolve();o=p
 if expected and (not p.exists() or sha(p)!=expected):
  p=aliases.get((str(p),expected),p)
  if p!=o:resolutions.append({'original':str(o),'expectedSHA256':expected,'retained':str(p),'reason':'Worker-retained exact earlier bytes; original receipt unchanged.'})
 assert p.is_file(),p
 h=sha(p);assert expected is None or h==expected,(str(p),expected,h)
 assert str(p) not in pins or pins[str(p)]==h,(str(p),'initial pin changed')
 pins[str(p)]=h;return p

def copy(p,name,expected=None):
 p=pin(p,expected);t=DEST/name
 if t.exists():assert sha(t)==sha(p),t
 else:t.write_bytes(p.read_bytes())
 copies.append({'source':str(p),'retainedCopy':str(t),'proposedExport':str(t.relative_to(FINAL)),'sha256':sha(p)})
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
for p,h in pins.items():assert sha(p)==h,(p,'initial pin drift')
for row in original['exports']:copy(row['draftCopy'],Path(row['proposedExport']).name,row['sha256'])
copy(INITIAL,'initial-integration-draft.json');copy('/tmp/assemble-fidelity20-integration.py','initial-assembly-script.py')
report=ROOT/'docs/TABLE-PAINT-REUSE-PERFORMANCE-20261004-20.md';wrapper=ROOT/'docs/benchmarks/2026-10-04-table-paint-reuse-layout-20-export.json'
copy(report,'accepted-performance-report.md','e19be2cf327bfde5f32806c6c85be4e905bc32ee9339658e6eb3cc6a04cb894c')
copy(wrapper,'accepted-performance-wrapper.json','ab663a5b96e14456f9f3d49a9b73cbe9598d4a3932fcaec82c65a22e52598eb9')
w=load(wrapper);assert len(w['exports'])==56
for row in w['exports']:pin(row['original'],row['SHA256']);copy(ROOT/row['tracked'],'performance-'+Path(row['tracked']).name,row['SHA256'])
copy(packet/'report-before-acceptance.md','performance-original-pending-report.md','3bb78807bf4d8c6b393ab663b8bbcb6ac43918e518bb98e2b1b91da6a8bbfee1')
copy(packet/'export-wrapper-before-acceptance.json','performance-original-pending-wrapper.json','4d789c42ba90a0fbaa02ad8200ba3db7b743f9935aeb0b87b1dc66a7d01db107')
verification=packet/'verification.json';recurse(load(verification));assert len(load(verification)['files'])==144
reviews={}
for name,h in [('performance','70285caec1b66968e3f2d48cf3f1abc3bd1a3313327602f70a1b1764cccaae11'),('performance-preservation','3fb788cce3bb0def2e09de6d5d7744812f40f9118e22c9655edaaa081e3447f4')]:
 p=Path('/tmp/rostrum-s20-independent-'+name+'-review.json');copy(p,'independent-'+name+'-review.json',h);recurse(load(p));reviews[name]={'path':str(p),'sha256':sha(p)}
# Preserve the earlier snapshot's naming mistake explicitly: it captured accepted
# wrapper bytes after worker acceptance, not original pending report bytes.
p=DRAFT/'performance-preacceptance/preservation-receipt.json';copy(p,'intermediate-performance-snapshot-history.json');recurse(load(p))
for row in load(p)['copies']:pin(row['retainedCopy'],row['sha256'])
report20=ROOT/'docs/LAYOUT-PERFORMANCE-20261004-20.md';copy(report20,'root-integration-report.md')
for name,h in original['sourcePins'].items():
 assert hashlib.sha256(subprocess.check_output(['git','-C',str(ROOT),'show',original['sourceCheckpoint']+':'+name])).hexdigest()==h
 assert sha(ROOT/name)==h,(name,'frozen root source drift')
result=dict(original);result.update(status='FINAL_DRAFT_READY_FOR_INDEPENDENT_INTEGRATION_REVIEW',createdUTC=datetime.now(timezone.utc).isoformat(),pins=pins,exports=copies,initialDraft={'path':str(INITIAL),'sha256':sha(INITIAL),'unchanged':True},finalReport={'path':str(report20),'sha256':sha(report20)},historicalPinResolutions=resolutions,trackedRootFilesWritten=False)
result['sourcePinScope']={'included':['Sources','Lectern/App','Lectern/AppTests','Lectern/Sources','Lectern/Tests','Tests/RostrumTests/TableBorderPaintReuseTests.swift','Lectern/scripts','scripts/verify.sh','.github/workflows/ci.yml'],'count':633,'distinctionFromS19':'The separate S19 manifest pinned four native fixture trees and three native test files in its 705-file source set. S20 keeps those historical acceptance records and independently verifies 71 fixture files through its external receipt; they are not silently included in this 633-file source count.'}
result['performance']={'status':'INDEPENDENTLY_ACCEPTED_BOUNDED_TARGET_GAIN_WITH_ADVERSE_CONTROLS','report':{'path':str(report),'sha256':sha(report)},'wrapper':{'path':str(wrapper),'sha256':sha(wrapper)},'reviews':reviews,'children':660,'retainedChildSamples':600,'primaryComparisons':31,'allPhases':339,'physicalPins':144,'outputArtifactPins':9861,'inputPins':122,'exports':56,'scope':'Target partial-table gains only; adverse direct axis-color control, inconclusive controls, RSS and ambient host activity retained. No general recovery, cumulative gain, universal nonregression or memory improvement claim.','initialVerificationStatusPreserved':True}
result['snapshotHistory']={'intermediateReceipt':str(p),'scope':'Directory name performance-preacceptance predates collection; actual snapshot contains accepted report e19be2/wrapper7e3015 and original verification. Original pending report3bb788 and pending wrapper4d789 are separately retained here.'}
result['assemblyScript']=str(Path(__file__));result['assemblyScriptSHA256']=sha(__file__);pin(__file__)
for p,h in pins.items():assert sha(p)==h,p
OUT.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n');print(json.dumps({'manifest':str(OUT),'sha256':sha(OUT),'physicalPins':len(pins),'sourcePins':len(result['sourcePins']),'exports':len(copies),'historicalResolutions':len(resolutions)}))
