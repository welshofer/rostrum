from pathlib import Path
import json,hashlib,subprocess,collections
from lxml import etree as E
R=Path('/path/to/user/.codex/worktrees/rostrum-fonts/rostrum');ROOT=Path('/path/to/user/Developer/rostrum');S=R/'.build/perf33-table-transitions';read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();git=lambda repo,*args:subprocess.check_output(['git','-C',str(repo),*args])
p=read(S/'timing-plan.json');ready=read(S/'ready.json');assert sha(S/'timing-plan.json')=='487cd24019eb59e9d510b5c9cd1c7f93281ba20588f26e46ddc09fabd60de29b';assert sha(S/'ready.json')=='76e7117eff3807a0664d1694e57447d92c247976bca8a5f459de2f3a7fa6e195'
for obj in (p,ready,read(S/'preflight-verification.json')):
 for x,h in obj['pins'].items():assert sha(x)==h,x
for n,h in p['binaries'].items():assert sha(S/n)==h,n
baseline=read(S/'baseline-pins.json');build=read(S/'candidate-helper-build.json');candidate=read(S/'candidate-source-pins.json');assert len(candidate)==len(baseline['sources'])==112
for k,h in candidate.items():assert hashlib.sha256(git(R,'show',p['candidateSource']+':'+k)).hexdigest()==h and sha(R/k)==h,k
for k,h in baseline['sources'].items():assert hashlib.sha256(git(R,'show',p['baselineSource']+':'+k)).hexdigest()==h,k
for obj in (baseline,build):
 for x,h in obj['files'].items():assert sha(S/x)==h,x
assert baseline['compiler']==build['compiler']
for x in ('extended-main.swift','supplement-main.swift','native-main.swift','table-main.swift'):assert baseline['files'][x]==build['files'][x]
for ref,tree in ((p['baselineSource'],p['baselineSourceTree']),(p['candidateSource'],p['candidateSourceTree'])):assert git(R,'rev-parse',ref+':Sources').decode().strip()==tree
assert git(ROOT,'rev-parse','33e484edf53f8b3ba817b28e6717d27fe265a94c:Sources').decode().strip()==p['candidateSourceTree']=='d555de4fa405e9c03217ebb966125a360cdd7f78'
assert git(R,'diff','--name-only',p['baselineSource'],p['candidateSource'],'--','Sources').decode().splitlines()==['Sources/Rostrum/Presentation/SVGRenderer.swift']
assert git(R,'diff',p['baselineSource'],p['candidateSource'],'--','Sources')==git(ROOT,'diff','5d3d888','33e484e','--','Sources')
old=read(R/'.build/perf32-table-paint-reuse/timing-plan.json')
for pool in ('canonical','supplement','native','cache-controls'):
 cmd=p['commands'][pool];oldcmd=old['commands'][pool]
 scenarios=lambda c:c[c.index('--scenarios')+1:c.index('--output')]
 assert scenarios(cmd)==scenarios(oldcmd),pool
 for arg in ('--runs','--warmups'):assert cmd[cmd.index(arg)+1]==oldcmd[oldcmd.index(arg)+1]
counts={k:len(v[v.index('--scenarios')+1:v.index('--output')]) for k,v in p['commands'].items()};assert counts=={'canonical':5,'supplement':3,'native':19,'cache-controls':3,'transitions':4}
assert sum(counts.values())*22==p['children']==748 and p['primaryComparisons']==35 and p['allMeasuredPhaseComparisons']==383
assert old['children']==660 and old['primaryComparisons']==31 and old['allMeasuredPhaseComparisons']==339
runner=(S/'run-authorized.py').read_text();assert "env.pop(k,None)"in runner and "'ROSTRUM_BENCH_OUTPUT':None"in runner and "assert not (s/'timing-execution.json').exists()"in runner and 'assert code==0'in runner
outputs=read(S/'output-artifact-pins.json');inputs=read(S/'input-pins.json');assert len(outputs)==9982 and len(inputs)==126
for x,h in {**outputs,**inputs}.items():assert sha(x)==h,x
corpus=read(S/'corpus-proof.json');assert len(corpus['cases'])==194 and sum(c['slideCount']for c in corpus['cases'])==892 and corpus['newProofProcesses']==corpus['freshPythonPptxReopens']==582
changed=[];artifactcount=0
for c in corpus['cases']:
 maps=c['artifacts'];assert maps['candidate-1']==maps['candidate-2'];differences=[k for k in maps['baseline']if maps['baseline'][k]!=maps['candidate-1'][k]];assert sorted(differences)==sorted(c['changedArtifacts'])
 assert all(n.endswith('.svg')for n in differences)
 for v,m in maps.items():
  for n,h in m.items():assert sha(S/'corpus'/c['name']/v/n)==h;artifactcount+=1
 if differences:changed.append((c['name'],differences))
assert len(changed)==5 and sum(len(x[1])for x in changed)==7
semantic=read(S/'semantic-classification.json');SV='{http://www.w3.org/2000/svg}';coordinates=('x1','y1','x2','y2');numeric=lambda l:tuple(float(l[n])for n in coordinates);normal=lambda l:(numeric(l),tuple(sorted((k,v)for k,v in l.items()if k not in coordinates)))
def predict(lines,origin,widths,heights):
 x,y=origin;w=sum(widths);h=sum(heights);result=[]
 for i,own in enumerate(lines):
  v=numeric(own);vertical=v[0]==v[2];axis=1 if vertical else 0;fixed=v[0]if vertical else v[1];vals=[]
  for pos,start in ((v[axis],True),(v[axis+2],False)):
   perp=[];same=[]
   for j,other in enumerate(lines):
    if i==j:continue
    q=numeric(other);ov=q[0]==q[2]
    if vertical!=ov:
     cross=q[1]if vertical else q[0];a,b=(q[0],q[2])if vertical else(q[1],q[3])
     if cross==pos and a<=fixed<=b:perp.append(float(other['stroke-width']))
    elif (q[0]if vertical else q[1])==fixed and (q[axis+2]if start else q[axis])==pos:same.append(float(other['stroke-width']))
   assert len(same)<=1
   extension=max(perp,default=0)/2
   if same:extension*=0 if float(own['stroke-width'])==same[0]else(1 if float(own['stroke-width'])>same[0]else-1)
   vals.append(pos-extension if start else pos+extension)
  q=list(v);q[axis],q[axis+2]=vals;item=dict(own);item.update({k:str(n)for k,n in zip(coordinates,q)});group=(2 if fixed in([x,x+w]if vertical else[y,y+h]) else 0)+(0 if vertical else 1);result.append((group,item))
 return [x[1]for x in sorted(result,key=lambda x:x[0])]
for c in semantic['cases']:
 for row in c['slides']:
  proof=read(row['proofPath']);assert sha(row['proofPath'])==row['proofSHA256'];trees=[];alllines=[]
  for variant in ('baseline','candidate-1'):
   t=E.fromstring((S/'corpus'/c['name']/variant/row['slide']).read_bytes(),E.XMLParser(huge_tree=True,resolve_entities=False));nodes=list(t.iter(SV+'line'));alllines.append([dict(n.attrib)for n in nodes])
   for n in nodes:n.getparent().remove(n)
   trees.append(E.tostring(t))
  assert trees[0]==trees[1] and alllines[0]==proof['baselineLines'] and alllines[1]==proof['candidateLines']
  assert collections.Counter(tuple(sorted((k,v)for k,v in l.items()if k not in coordinates))for l in alllines[0])==collections.Counter(tuple(sorted((k,v)for k,v in l.items()if k not in coordinates))for l in alllines[1])
  expected=list(alllines[0])
  for table in proof['sourceTables']:
   indices=table['baselineLineIndices'];ls=[alllines[0][i]for i in indices];pred=predict(ls,table['frameOrigin'],table['sourceGridWidths'],table['sourceGridHeights'])
   for i,l in zip(indices,pred):expected[i]=l
  assert [normal(l)for l in expected]==[normal(l)for l in alllines[1]]
vp=read(S/'value-proof.json');groups={}
for row in vp['rows']:
 assert sha(row['path'])==row['SHA256'];assert sum(1 for _ in Path(row['path']).open())==row['records'];groups.setdefault((row['kind'],row['records']),[]).append(row['SHA256'])
assert all(len(set(v))==1 and len(v)==3 for v in groups.values()) and sorted(k[1]for k in groups)==[288,1728,101022]
out=dict(status='APPROVE_FROZEN_S21_READINESS_NO_TIMING_AUTHORIZATION',plan=str(S/'timing-plan.json'),planSHA256=sha(S/'timing-plan.json'),ready=str(S/'ready.json'),readySHA256=sha(S/'ready.json'),rootSource='33e484edf53f8b3ba817b28e6717d27fe265a94c',rootSourcesTree=p['candidateSourceTree'],baseline=p['baselineSource'],candidate=p['candidateSource'],physicalPins=ready['physicalPins'],originalInputs=126,outputPins=9982,children=748,poolWorkloadCounts=counts,primaryComparisons=35,allPhaseComparisons=383,corpus={'cases':194,'slides':892,'recordedFreshProofProcesses':582,'recordedPythonReopens':582,'actualCompleteCorpusArtifacts':artifactcount,'changedCases':5,'changedSVGs':7,'allCandidateRepeatsExact':True,'allPackagesDiagnosticsInheritanceExact':True,'completeActualNonLineExact':True,'allLineNonCoordinatePaintExact':True,'independentSignedEndpointAndOrderModelExact':True},shapingRecords=101310,layoutRecords=1728,findings=[],limits=['This is finite prelaunch protocol/readiness approval only; root must grant timing after task jobs and GUI are idle. No campaign launched by reviewer.','Saved packages/diagnostics/non-line trees preserved, but seven SVG endpoint/order changes are intentional fidelity corrections; no all-SVG identity claim.','Old reject-collinear control is newly admitted. Merged colored and RTL controls remain exact fallback.','One warmup pair and ten alternating retained process pairs, all383 unadjusted exploratory phases/RSS/adverse samples retained; no universal nonregression, cumulative recovery or allocation claim.','Baseline uses retained acceptedS20 Release products, not fresh baseline build. Reviewer read/hash/model checks only; no test/build/GUI or evidence modification.'],script=str(Path(__file__)),scriptSHA256=sha(__file__))
q=Path('/tmp/rostrum-s21-independent-readiness-review.json');assert not q.exists();q.write_text(json.dumps(out,indent=2)+'\n');print(q,sha(q))
