from pathlib import Path
import json,hashlib,subprocess,copy,re
from lxml import etree as E
R=Path('/path/to/user/.codex/worktrees/rostrum-tables/rostrum');C='89aa1633cbbd07c152eb9e456c12e15686f7dbb8';B='5d3d888175d12f615a3f917e15d8c9b6a170f201';F='Tests/RostrumTests/Fixtures/NativeTableTransitions/';D=R/'.build/table-transitions21-implementation';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();read=lambda p:json.loads(Path(p).read_text());git=lambda *a:subprocess.check_output(['git','-C',str(R),*a]);blob=lambda p:git('show',C+':'+p);bh=lambda p:hashlib.sha256(blob(p)).hexdigest();pins={}
proposal='/tmp/rostrum-s21-independent-native-proposal-review.json';assert sha(proposal)=='641504f6c934735107dc7ba3a2c3f52993d541b25aa1e48fe2c4326e3445b6f1';pins[proposal]=sha(proposal)
changed=git('diff','--name-only',B,C).decode().splitlines();production=[p for p in changed if p.startswith('Sources/')];assert production==['Sources/Rostrum/Presentation/SVGRenderer.swift'];source=blob(production[0]);assert hashlib.sha256(source).hexdigest()=='5f720a8362e63d42107e43a35f551537cd76a928d42d82c9afa2b062ab5f98dd'
fixturepins=json.loads(blob(F+'pins.json'));v=json.loads(blob(F+'verification.json'))
for p,h in fixturepins.items():assert bh(F+p)==h
for p,h in v['localLogs'].items():assert sha(p)==h;pins[p]=h
assert v['sourceFiles'][production[0]]==bh(production[0]);delta=read(D/'output-delta.json');assert len(delta['inputs'])==7 and sum(len(x['artifacts'])for x in delta['inputs'])==29
S='{http://www.w3.org/2000/svg}'
def canon(e):return(e.tag,tuple(sorted(e.attrib.items())),e.text or '',tuple(canon(c)for c in e))
def withoutlines(e):
 e=copy.deepcopy(e)
 for x in e.iter(S+'line'):x.getparent().remove(x)
 return canon(e)
for x in delta['inputs']:
 for a in x['artifacts']:
  p=D/'proof/baseline'/x['name']/a['name'];q=D/'proof/candidate'/x['name']/a['name'];assert sha(p)==a['beforeSHA256']and sha(q)==a['afterSHA256'];pins[str(p)]=sha(p);pins[str(q)]=sha(q)
  if a['exact']:assert p.read_bytes()==q.read_bytes()
  else:
   assert x['newNativeTransition']and a['name'].endswith('.svg');aa,bb=E.parse(str(p)).getroot(),E.parse(str(q)).getroot();assert withoutlines(aa)==withoutlines(bb);assert len(list(aa.iter(S+'line')))==len(list(bb.iter(S+'line')))==a['beforeLineCount']==a['afterLineCount']
base=read(D/'baseline-receipt.json');assert base['commit']==B
for a in base['artifacts']:
 p=R/a['path'];assert sha(p)==a['sha256']and a['equalsResearchBefore'];folder=p.parent.name;research=R/'.build'/('table-transitions21-horizontal'if folder=='horizontal'else'table-transitions21')/'before'/p.name;assert p.read_bytes()==research.read_bytes();pins[str(p)]=sha(p)
def intervals(lines):
 d={}
 for l in lines:
  p=l['points'];v=p[0]==p[2];k=(v,p[0]if v else p[1],l['width'],l['opacity'],tuple(round(c*255)for c in l['color']));d.setdefault(k,[]).append([p[1]if v else p[0],p[3]if v else p[2]])
 for k,ranges in d.items():
  out=[]
  for a,b in sorted(ranges):
   if out and abs(out[-1][1]-a)<.001:out[-1][1]=b
   else:out.append([a,b])
  d[k]=out
 return d
def box(l):
 a,b,c,d=l['points'];h=l['width']/2;return[a-h,b,c+h,d]if a==c else[a,b-h,c,d+h]
def paint(lines,x,y):
 c=None
 for l in lines:
  a,b,d,e=box(l)
  if a<x<d and b<y<e:c=l['color']
 return c
counts=[0,0,0,0];glyphmax=[0,0,0]
for folder in ['vertical','horizontal']:
 refs=json.loads(blob(F+folder+'/paint-reference.json'));baseline=json.loads(blob(F+folder+'/baseline-paint.json'));prefix='native-table-transitions21'+('-horizontal'if folder=='horizontal'else'')+'-v1'
 for ref,prior in zip(refs,baseline):
  assert ref['id']==prior['id'];e=E.parse(str(D/'proof/candidate'/prefix/f"slide-{ref['page']}.svg")).getroot();inside=lambda x,y:ref['x']-6<=x<=ref['x']+ref['width']+6 and ref['y']-6<=y<=ref['y']+ref['height']+6
  lines=[]
  for n in e.iter(S+'line'):
   p=[float(n.get(k))/12700 for k in ['x1','y1','x2','y2']]
   if inside(p[0],p[1]):
    color=n.get('stroke');assert color.startswith('#');color=[int(color[i:i+2],16)/255 for i in [1,3,5]];lines.append(dict(points=p,color=color,width=float(n.get('stroke-width'))/12700,opacity=float(n.get('stroke-opacity','1'))))
  excluded=ref['id']=='merged-colored-rejection';expected=prior['lines']if excluded else ref['lines']
  if excluded:assert lines==expected
  a,b=intervals(lines),intervals(expected);assert a.keys()==b.keys()
  for k in a:
   assert len(a[k])==len(b[k])
   for x,y in zip(a[k],b[k]):assert max(abs(i-j)for i,j in zip(x,y))<.001
  for l in lines:assert any(l['width']==m['width']and l['opacity']==m['opacity']and max(abs(i-j)for i,j in zip(l['color'],m['color']))<.0001 for m in expected)
  bb=[box(l)for l in lines+expected];xx=sorted({v for z in bb for v in[z[0],z[2]]});yy=sorted({v for z in bb for v in[z[1],z[3]]});regions=0
  for l,r in zip(xx,xx[1:]):
   for t,bottom in zip(yy,yy[1:]):
    regions+=1;p,q=paint(lines,(l+r)/2,(t+bottom)/2),paint(expected,(l+r)/2,(t+bottom)/2);assert(p is None)==(q is None)
    if p is not None:assert max(abs(i-j)for i,j in zip(p,q))<.0001
  glyphs=[]
  for text in e.iter(S+'text'):
   transform=text.get('transform','');v=list(map(float,re.findall(r'[-+]?\d+(?:\.\d+)?',transform)))
   if len(v)!=3 or not inside(v[0]/12700,v[1]/12700):continue
   assert v[2]==12700
   for span in text:
    xs=list(map(float,span.get('x','').split()));scalars=list(''.join(span.itertext()));assert len(xs)==len(scalars)and span.get('textLength')is None
    for x,c in zip(xs,scalars):glyphs.append(dict(text=c,origin=[v[0]/12700+x,v[1]/12700],size=float(span.get('font-size'))))
  assert len(glyphs)==len(ref['glyphs'])
  for g,n in zip(glyphs,ref['glyphs']):
   assert g['text']==n['text'];err=[abs(g['origin'][0]-n['origin'][0]),abs(g['origin'][1]-n['origin'][1]),abs(g['size']-n['size'])];assert all(x<b for x,b in zip(err,[.025,.121,.002]));glyphmax=[max(x,y)for x,y in zip(glyphmax,err)]
  counts[0]+=1;counts[1]+=len(glyphs)
  if not excluded:counts[2]+=sum(map(len,intervals(ref['lines']).values()));counts[3]+=regions
assert counts[:3]==[14,240,107]
log=(D/'fail-before-corrected.log').read_text();assert log.count('native interval [')==101 and log.count(': complete ordered opaque paint')==12 and '113 issues'in log
full=(D/'full.log').read_text();assert '1195 tests in 175 suites passed'in full and '18 tests in 3 suites passed'in full
receipt=dict(status='APPROVE_FROZEN_BOUNDED_S21_SOURCE',commit=C,baseline=B,productionFiles=production,changedGitFileSHA256={p:bh(p)for p in changed},fixturePins=len(fixturepins),retainedSHA256=pins,sourceReview='Only unmerged LTR mixed profile predicate expands; all topology/opaque/simple-solid/positive dimension/ragged/diagonal/maximum-width bounds, uniform path, donor/owner/paint-group arithmetic remain unchanged. Colored RTL/merges and invalid/unsupported paths remain covered. No added persistent state/DOM writes/cache changes.',testsReview='Strict native240 glyphs/107 admitted intervals and full ordered opaque paint. Excluded colored merged geometry/order exact frozen baseline, native text still strict. Older synthetic transitions now positive endpoint + absence-of-raw assertions; rejected sibling cases retain exact former endpoints. Live reused renderer/alias noFill→solid/width/color edits and restoration/save/reopen are exercised.',counts=dict(cases=14,glyphs=240,admittedIntervals=107,baselineIntervalFailures=101,baselineOrderedPaintFailures=12,preservationInputs=7,preservationArtifacts=29,libraryTests=1195,librarySuites=175,layoutTests=18,layoutSuites=3),maximumGlyphErrors=glyphmax,proposalReview=proposal,proposalReviewSHA256=sha(proposal),findings=[],limits=['No tests/builds/GUI/benchmarks run by reviewer; log claims read and pinned only.','Actual selected font outlines/rawPDF/native model already independently audited in prior proposal receipt; promoted native source/PDF/reference Git blobs match fixture pins.','Seven-input preservation is bounded; full corpus/root integration/renderer browser checks and matched performance campaign remain pending.','No whole-slide raster/ink parity, colored RTL/merged generalization or performance claim.'],script=str(Path(__file__)),scriptSHA256=sha(__file__))
p=Path('/tmp/rostrum-s21-independent-source-review.json');assert not p.exists();p.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(dict(status=receipt['status'],receipt=str(p),sha256=sha(p),counts=receipt['counts'],maximumGlyphErrors=glyphmax)))
