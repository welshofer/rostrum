from pathlib import Path
from io import BytesIO
import json,hashlib,zipfile,collections,importlib.util,math,re,subprocess,copy
import fitz
from pypdf import PdfReader
from pypdf.generic import ContentStream
from lxml import etree as E
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
ROOT=Path('/path/to/user/.codex/worktrees/rostrum-tables/rostrum');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();read=lambda p:json.loads(Path(p).read_text());A='http://schemas.openxmlformats.org/drawingml/2006/main';P='http://schemas.openxmlformats.org/presentationml/2006/main';N={'a':A,'p':P};S='http://www.w3.org/2000/svg'
spec=importlib.util.spec_from_file_location('reviewed_paint','/tmp/verify-webkit-paint.py');helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
fontpath=ROOT/'Tests/RostrumTests/Fixtures/NativeListMarkers/fonts/DejaVuSans.ttf';fontbytes=fontpath.read_bytes();sourcefont=TTFont(BytesIO(fontbytes));assert sha(fontpath)=='7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954'
def outline(font,name):
 pen=DecomposingRecordingPen(font.getGlyphSet());font.getGlyphSet()[name].draw(pen);return pen.value
def normalized(v):
 if isinstance(v,(fitz.Point,fitz.Rect)):return list(v)
 if isinstance(v,(list,tuple)):return[normalized(x)for x in v]
 if isinstance(v,dict):return{k:normalized(x)for k,x in v.items()}
 return v
def spans(lines):
 groups={}
 for l in lines:
  p=l['points'];vertical=p[0]==p[2];assert vertical or p[1]==p[3];k=(vertical,p[0]if vertical else p[1],l['width'],tuple(round(v*255)for v in l['color']),l['opacity']);groups.setdefault(k,[]).append(sorted([p[1]if vertical else p[0],p[3]if vertical else p[2]]))
 out={}
 for k,v in groups.items():
  merged=[]
  for start,end in sorted(v):
   if merged and abs(merged[-1][1]-start)<.001:merged[-1][1]=end
   else:merged.append([start,end])
  out[k]=merged
 return out
def box(l):
 x1,y1,x2,y2=l['points'];h=l['width']/2;return[x1-h,y1,x2+h,y2]if x1==x2 else[x1,y1-h,x2,y2+h]
def paint(ls,x,y):
 last=None
 for l in ls:
  a,b,c,d=box(l)
  if a<x<c and b<y<d:last=tuple(l['color'])
 return last
rows=[];pins={};totalglyphs=0;regions=0;intervals=0;failed=0;largest=[0,0,0];excluded=['merged-colored-rejection']
for folder,expectedglyphs,expectedcases in [('table-transitions21',124,8),('table-transitions21-horizontal',116,6)]:
 r=ROOT/'.build'/folder;m=read(r/'manifest.json');cases=read(r/'cases.json');references=read(r/'paint-reference.json');native=read(r/'native-vectors.json');baseline=read(r/'baseline-paint.json');receipt=read(r/'capture-receipt.json');audit=read(r/'audit.json');before=read(r/'before-comparison.json');proof=read(r/'model-proof.json');model=read(r/'model-paint.json')
 assert sha(r/m['source'])==m['sourceSHA256']==sha(receipt['input'])==native['sourceSHA256'];assert sha(r/'powerpoint.pdf')==sha(receipt['pdf'])==receipt['pdfSHA256']==native['pdfSHA256'];assert receipt['sourceUnchanged']and not receipt['sourceSaved']and not receipt['repairDialogObserved']and receipt['pages']==2 and 'selected1; online service0'in receipt['export']
 for name,h in audit['beforeArtifactSHA256'].items():assert sha(r/'before'/name)==h
 for p in r.iterdir():
  if p.is_file():pins[str(p)]=sha(p)
 assert len(PresentationSource:=cases)==expectedcases and m['expectedVisibleGlyphs']==expectedglyphs
 with zipfile.ZipFile(r/m['source'])as z:
  assert z.testzip()is None and len(z.namelist())==len(set(z.namelist()))and z.read('ppt/fonts/regular.fntdata').endswith(fontbytes)
  for name in z.namelist():
   if name.endswith(('.xml','.rels')):E.fromstring(z.read(name))
  for page in range(2):
   shapes=E.fromstring(z.read(f'ppt/slides/slide{page+1}.xml')).xpath('//p:graphicFrame',namespaces=N);cs=[c for c in cases if c['page']==page];assert len(shapes)==len(cs)
   for shape,c in zip(shapes,cs):
    assert shape.xpath('./p:nvGraphicFramePr/p:cNvPr/@name',namespaces=N)==[c['id']];f=shape.xpath('./p:xfrm/a:off',namespaces=N)[0];wh=shape.xpath('./p:xfrm/a:ext',namespaces=N)[0];assert [int(f.get('x'))/12700,int(f.get('y'))/12700,int(wh.get('cx'))/12700,int(wh.get('cy'))/12700]==[c[k]for k in ['x','y','width','height']]
    tbl=shape.find('.//{'+A+'}tbl');assert tbl.find('{'+A+'}tblPr').get('rtl')=='0';assert [int(x.get('w'))/12700 for x in tbl.findall('{'+A+'}tblGrid/{'+A+'}gridCol')]==c['columnWidths'];assert [int(x.get('h'))/12700 for x in tbl.findall('{'+A+'}tr')]==c['rowHeights']
    cells=tbl.findall('{'+A+'}tr/{'+A+'}tc');assert len(cells)==len(c['cells'])
    for tc,d in zip(cells,c['cells']):
     assert dict(tc.attrib)==d['attributes']and ''.join(tc.xpath('.//a:t/text()',namespaces=N))==d['text'];assert not tc.xpath('.//a:lnTlToBr|.//a:lnBlToTr',namespaces=N)
     for prop in tc.findall('.//{'+A+'}rPr'):assert prop.get('sz')=='1450'and prop.get('kern')=='0'and prop.get('b')=='0'and prop.get('i')=='0'and prop.find('{'+A+'}latin').get('typeface')=='DejaVu Sans'
     for e in d['edges']:
      ln=tc.find('{'+A+'}tcPr/{'+A+'}'+e['edge']);assert int(ln.get('w'))==round(e['widthPT']*12700)and (ln.find('{'+A+'}noFill')is not None)==e['noFill']
      if not e['noFill']:assert ln.find('.//{'+A+'}srgbClr').get('val')==e['color']
 doc=fitz.open(r/'powerpoint.pdf');reader=PdfReader(r/'powerpoint.pdf');assert len(doc)==len(reader.pages)==2;actualGlyphs=0
 for page in range(2):
  assert list(doc[page].rect)==[0,0,720,720];actualPaths=normalized(doc[page].get_drawings());assert actualPaths==native['pages'][page]['paths'];ops=[dict(operator=op.decode('latin1'),operands=[str(v)for v in values])for values,op in ContentStream(reader.pages[page].get_contents(),reader).operations];assert ops==native['pages'][page]['operators'];assert doc[page].read_contents()==(r/f'page-{page+1}-content.txt').read_bytes()
 matrices= [helper.raw_matrices(reader.pages[i])for i in range(2)]
 subsets={}
 for page in doc:
  for f in page.get_fonts(full=True):
   xref=f[0];name,ext,kind,data=doc.extract_font(xref);assert ext=='ttf';subsets[xref]=TTFont(BytesIO(data));assert data==(r/f'pdf-font-{xref}.ttf').read_bytes()
 for c,ref,original,pre,mod,pr in zip(cases,references,native['cases'],baseline,model,proof['cases']):
  assert c['id']==ref['id']==original['id']==pre['id']==mod['id']==pr['id'];page=doc[c['page']];frame=fitz.Rect(c['x']-6,c['y']-6,c['x']+c['width']+6,c['y']+c['height']+6);glyphs=[]
  for trace in page.get_texttrace():
   for scalar,gid,origin,bounds in trace['chars']:
    if frame.contains(fitz.Point(origin)):glyphs.append(dict(text=chr(scalar),glyph=gid,origin=list(origin),bounds=list(bounds),font=trace['font'],size=trace['size'],color=list(trace['color']),type=trace['type'],seqno=trace['seqno']))
  assert glyphs==original['glyphs']==ref['glyphs'];assert ''.join(g['text']for g in glyphs)==''.join(x['text']for x in c['cells']);assert len(glyphs)==len(pre['glyphs'])
  actualGlyphs+=len(glyphs);resources=page.get_fonts(full=True);assert len(resources)==1;subset=subsets[resources[0][0]];assert subset['head'].unitsPerEm==sourcefont['head'].unitsPerEm
  for g,svg in zip(glyphs,pre['glyphs']):
   assert g['text']==svg['text'];assert outline(subset,subset.getGlyphOrder()[g['glyph']])==outline(sourcefont,sourcefont.getBestCmap()[ord(g['text'])]);dx,dy,ds=abs(g['origin'][0]-svg['origin'][0]),abs(g['origin'][1]-svg['origin'][1]),abs(g['size']-svg['size']);largest=[max(a,b)for a,b in zip(largest,[dx,dy,ds])];assert dx<.025 and dy<.121 and ds<.002
   mm=[x for x in matrices[c['page']]if x['font']==g['font']and abs(x['matrix'][5]-g['origin'][1])<.025];assert mm;linear={tuple(round(v,6)for v in x['matrix'][:4])for x in mm};assert len(linear)==1;a,b,cc,d=next(iter(linear));assert abs(b)<1e-6 and abs(cc)<1e-6 and abs(a-g['size'])<.002 and abs(-d-g['size'])<.002
  assert len(original['paths'])==len(ref['lines'])
  for p,l in zip(original['paths'],ref['lines']):assert p['type']=='s'and p['lineCap']==[0,0,0]and p['dashes']=='[] 0'and not p['closePath']and len(p['items'])==1 and p['items'][0][0]=='l'and p['stroke_opacity']==l['opacity']==1 and l['points']==p['items'][0][1]+p['items'][0][2]and l['color']==p['color']and l['width']==p['width']
  xs=[c['x']+sum(c['columnWidths'][:i])for i in range(len(c['columnWidths'])+1)];ys=[c['y']+sum(c['rowHeights'][:i])for i in range(len(c['rowHeights'])+1)];raw=[]
  for l in pre['lines']:
   l=copy.deepcopy(l);p=l['points'];vertical=p[0]==p[2];axis=1 if vertical else 0;coords=ys if vertical else xs
   for i in [axis,axis+2]:q=min(coords,key=lambda v:abs(v-p[i]));assert abs(q-p[i])<=2;p[i]=q
   l['group']=(2 if(p[0]in[xs[0],xs[-1]]if vertical else p[1]in[ys[0],ys[-1]])else 0)+(0 if vertical else 1);raw.append(l)
  predicted=[]
  for own in raw:
   p=own['points'];vertical=p[0]==p[2];axis=1 if vertical else 0;fixed=p[0]if vertical else p[1];ends=[]
   for point,lower in [(p[axis],True),(p[axis+2],False)]:
    donors=[];continuations=[]
    for other in raw:
     if other is own:continue
     q=other['points'];ov=q[0]==q[2]
     if ov!=vertical:
      crossing=q[1]if vertical else q[0];left,right=(q[0],q[2])if vertical else(q[1],q[3])
      if crossing==point and left<=fixed<=right:donors.append(other['width'])
     elif(q[0]if vertical else q[1])==fixed and((lower and q[axis+2]==point)or(not lower and q[axis]==point)):continuations.append(other['width'])
    assert len(continuations)<=1;extension=max(donors,default=0)/2
    if continuations:extension*=0 if own['width']==continuations[0]else(1 if own['width']>continuations[0]else-1)
    ends.append(point-extension if lower else point+extension)
   q=p.copy();q[axis],q[axis+2]=ends;predicted.append(dict(own,points=q))
  predicted.sort(key=lambda l:l['group']);assert predicted==mod['lines']
  a,b=spans(predicted),spans(ref['lines']);assert a.keys()==b.keys();n=sum(map(len,b.values()));intervals+=n;assert n==pr['nativeIntervals']
  for key in a:
   assert len(a[key])==len(b[key])
   for aa,bb in zip(a[key],b[key]):assert max(abs(x-y)for x,y in zip(aa,bb))<.001
  # Exact source/expected RGB checked independently instead of relying only on 8-bit grouping.
  for l in predicted:assert any(max(abs(x-y)for x,y in zip(l['color'],g['color']))<.0001 and l['width']==g['width']for g in ref['lines'])
  bounds=[box(l)for l in predicted+ref['lines']];xx=sorted({v for b in bounds for v in [b[0],b[2]]});yy=sorted({v for b in bounds for v in [b[1],b[3]]});count=0
  for left,right in zip(xx,xx[1:]):
   for top,bottom in zip(yy,yy[1:]):
    count+=1;p,q=paint(predicted,(left+right)/2,(top+bottom)/2),paint(ref['lines'],(left+right)/2,(top+bottom)/2);assert (p is None)==(q is None)
    if p is not None:assert max(abs(x-y)for x,y in zip(p,q))<.0001
  assert count==pr['opaquePaintRegions']and not pr['endpointMismatches']and not pr['paintMismatches'];regions+=count
  beforeRow=next(x for x in before if x['id']==c['id']);failed+=beforeRow['failingIntervals'];rows.append(dict(id=c['id'],glyphs=len(glyphs),intervals=n,paintRegions=count,preFixFailingIntervals=beforeRow['failingIntervals'],proposedAdmission=c['id']not in excluded,grid=[len(c['rowHeights']),len(c['columnWidths'])]))
 assert actualGlyphs==expectedglyphs;totalglyphs+=actualGlyphs
assert len(rows)==14 and totalglyphs==240 and intervals==115 and regions==1131 and failed==109
admitted=[x for x in rows if x['proposedAdmission']];assert len(admitted)==13 and sum(x['intervals']for x in admitted)==107 and sum(x['paintRegions']for x in admitted)==1081 and sum(x['preFixFailingIntervals']for x in admitted)==101
expanded=read(ROOT/'.build/table-transitions21-horizontal/expanded-model-proof.json');assert expanded['nativeIntervals']==intervals and expanded['paintRegions']==regions and expanded['glyphs']==totalglyphs
out={'status':'APPROVE_BOUNDED_S21_NATIVE_PROPOSAL_BEFORE_IMPLEMENTATION','sourceBaseline':'119b1c107ff9911bdc86241e0e86a7a323a3b087 (S20 ancestry; not integrated root)','productionEditsApprovedForNextReviewOnly':'Simplify existing unmerged LTR mixed-profile admission; preserve all enclosing solid/opaque/topology/dimension/ragged/diagonal guards, existing one-color RTL and one-orientation/one-color merged paths. Actual implementation/tests/integrated output/performance still require review.','cases':14,'glyphs':240,'nativeIntervals':115,'opaquePaintRegions':1131,'proposedCases':13,'proposedIntervals':107,'proposedPaintRegions':1081,'preFixAdmittedIntervalFailures':101,'excludedCaseIDs':excluded,'maximumGlyphErrors':dict(zip(['x','y','paintSize'],largest)),'bounds':{'vectorPT':.001,'RGB':.0001,'glyphXPT':.025,'glyphYPT':.121,'paintSizePT':.002},'rows':rows,'pins':pins,'fontSHA256':sha(fontpath),'reviewedRawMatrixHelper':{'path':'/tmp/verify-webkit-paint.py','sha256':sha('/tmp/verify-webkit-paint.py')},'findings':[],'retainedParserRepresentationCorrection':{'path':'/tmp/rostrum-s21-independent-initial-parser-review.json','sha256':sha('/tmp/rostrum-s21-independent-initial-parser-review.json')},'retainedReviewerImportCorrection':{'path':'/tmp/rostrum-s21-independent-import-review-failure.json','sha256':sha('/tmp/rostrum-s21-independent-import-review-failure.json')},'limitations':['No production change, tests/builds/GUI or timing launched by reviewer; source/regeneration/helper provenance retained, no new production performance claim.','All 240 font outlines/raw paint matrices and existing body positions independently checked; no transformed glyph-ink/raster/whole-slide claim.','Model predictions use pinned baseline primitives and source grid coordinates/widths only; native intervals/origins are comparison targets, not prediction inputs. Full ordered paint regions compare raw RGB within .0001 rather than only rounded color buckets.','Merged-colored model agreement is research only, excluded from proposed support; preserve exact baseline fallback geometry in strict tests. Both-axis3x3 expands transition evidence without proving all topology/style combinations.','S20 ancestry omits root prior ordinary-inheritance reuse; integrated proof/performance must use exact accepted root baseline.'],'script':str(Path(__file__)),'scriptSHA256':sha(__file__)}
p=Path('/tmp/rostrum-s21-independent-native-proposal-review.json');assert not p.exists();p.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'path':str(p),'sha256':sha(p),'status':out['status'],'counts':[14,240,115,1131],'admitted':[13,107,1081],'maximumGlyphErrors':out['maximumGlyphErrors']}))
