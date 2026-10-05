from pathlib import Path
from io import BytesIO
import hashlib,json,zipfile,subprocess
from lxml import etree as E
R=Path('/Users/welshofer/Developer/rostrum');BASE=Path('/tmp/lectern-fidelity21-generated-native');F=R/'Lectern/Sources/LecternCore/Resources/LibraryLab/TableTransitionsReferences.json';FONT=R/'Tests/RostrumTests/Fixtures/NativeListMarkers/fonts/DejaVuSans.ttf';H=Path('/tmp/verify-fidelity21-table-transition-paint-v2.py');PY='/Library/Frameworks/Python.framework/Versions/3.12/bin/python3';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();read=lambda p:json.loads(Path(p).read_text());ref=read(F);N={'p':'http://schemas.openxmlformats.org/presentationml/2006/main','a':'http://schemas.openxmlformats.org/drawingml/2006/main'};pins={str(F):sha(F),str(FONT):sha(FONT),str(H):sha(H)};rows=[]
fixtures={}
for source in ref['sources']:
 folder=R/source['fixture'];sourcefile=folder/source['source'];assert sha(sourcefile)==source['sourceSHA256'];fixturefont=folder/'fonts/DejaVuSans.ttf'
 z=zipfile.ZipFile(sourcefile);tables={}
 for n in z.namelist():
  if n.startswith('ppt/slides/slide')and n.endswith('.xml'):
   for frame in E.fromstring(z.read(n)).xpath('//p:graphicFrame',namespaces=N):tables[frame.xpath('./p:nvGraphicFramePr/p:cNvPr/@name',namespaces=N)[0]]=frame
 fixtures[source['group']]=tables;pins[str(sourcefile)]=sha(sourcefile)
for opt in ('alternative-false','alternative-true'):
 d=BASE/opt;cap=read(d/'capture-receipt.json');inp=read(d/'input-pins.json');source=d/'tableTransitions.pptx';pdf=d/'powerpoint.pdf';assert sha(source)==cap['inputSHA256']==inp['inputSHA256']==sha(inp['source']);assert sha(pdf)==cap['pdfSHA256'];assert cap['sourceUnchanged']and not cap['sourceSaved']and not cap['repairDialogObserved']and cap['pages']==5 and 'selected1; online service0'in cap['export'];sourcebefore=sha(source)
 with zipfile.ZipFile(source)as z:
  assert z.testzip()is None and len(z.namelist())==len(set(z.namelist()));assert z.read('ppt/fonts/regular.fntdata').endswith(FONT.read_bytes())
  for n in z.namelist():
   if n.endswith(('.xml','.rels')):E.fromstring(z.read(n))
  for page in range(4):
   frames=E.fromstring(z.read(f'ppt/slides/slide{page+1}.xml')).xpath('//p:graphicFrame',namespaces=N);cs=[c for c in ref['cases']if c['slide']==page];assert len(frames)==len(cs)
   for frame,c in zip(frames,cs):
    old=fixtures[c['sourceGroup']][c['id']];assert frame.xpath('./p:nvGraphicFramePr/p:cNvPr/@name',namespaces=N)==[c['id']]
    def projection(node):return (node.tag,tuple(sorted(node.attrib.items())),node.text,tuple(projection(x)for x in node))
    # Object ID may be remapped at deck composition; all frame/body/grid cells, styles and children remain exact.
    f1=frame.find('p:xfrm',N);f2=old.find('p:xfrm',N);t1=frame.find('.//a:tbl',N);t2=old.find('.//a:tbl',N);assert projection(f1)==projection(f2)and projection(t1)==projection(t2),c['id']
 for page in range(4):
  svg=Path(inp['source']).parent/f'slide-{page+1}.svg';dest=d/f'independent-v2-page{page+1}.json'
  if not dest.exists():
   result=subprocess.run([PY,str(H),'--svg',str(svg),'--pdf',str(pdf),'--reference',str(F),'--font',str(FONT),'--slide',str(page),'--page',str(page),'--mode','native','--native-pages','5','--output',str(dest)],cwd=R,capture_output=True,text=True)
   (d/f'independent-v2-page{page+1}.log').write_text(result.stdout+result.stderr);assert result.returncode==0,(opt,page,result.stderr)
  result=read(dest);assert result['pdfSHA256']==sha(pdf)and result['svgSHA256']==sha(svg)and result['referenceSHA256']==sha(F);assert result['visibleGlyphs']==sum(len(c['glyphs'])for c in ref['cases']if c['slide']==page)
  rows.append(dict(option=opt,page=page,receipt=str(dest),receiptSHA256=sha(dest),cases=len(result['results']),glyphs=result['visibleGlyphs'],admittedCases=sum(x['nativeBorderAdmitted']for x in result['results'])));pins[str(svg)]=sha(svg);pins[str(dest)]=sha(dest)
 assert sha(source)==sourcebefore
 for p in (d/'capture-receipt.json',d/'input-pins.json',source,pdf):pins[str(p)]=sha(p)
assert sum(r['cases']for r in rows)==28 and sum(r['glyphs']for r in rows)==480 and sum(r['admittedCases']for r in rows)==26
out=dict(status='PASS_S21_GENERATED_NATIVE_BOUNDED_PAINT_AND_ALL_GLYPHS',options=2,PDFs=2,PDFPagesEach=5,oraclePagesEach=4,cases=28,glyphs=480,nativePaintAdmittedCases=26,nativePaintExcludedMergedCases=2,bounds={'vectorPoints':.001,'RGB':.0001,'glyphX':.025,'glyphY':.121,'paintSize':.002},rows=rows,pins=pins,scope=['All14 source frames/table bodies/grids/actual embedded font bytes retained exactly per option; only outside captions and deck composition may differ.','All480 visible body glyphs independently consumed, actual subset/source outlines and raw PDF/text/vector matrices checked. No trace-bbox-as-ink or raster parity claim.','26 admitted cases complete opaque stroke/fill arrangement and intervals checked; merged-colored borders remain excluded from native acceptance, while their glyph bounds remain strict and SVG baseline fallback is checked.','Fifth public computed-control page outside native geometry oracle; root owns no-repair/local-print and visual observations.','No tests/builds/GUI/timing or source/original evidence changes by reviewer.'],script=str(Path(__file__)),scriptSHA256=sha(__file__))
p=Path('/tmp/rostrum-s21-independent-generated-native-review.json');assert not p.exists();p.write_text(json.dumps(out,indent=2)+'\n');print(p,sha(p))
