from pathlib import Path
import json,hashlib,subprocess,xml.etree.ElementTree as E
R=Path('/path/to/user/Developer/rostrum');B=Path('/tmp/lectern-fidelity21-transitions-webkit');read=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();PY='/Library/Frameworks/Python.framework/Versions/3.12/bin/python3';REF=R/'Lectern/Sources/LecternCore/Resources/LibraryLab/TableTransitionsReferences.json';FONT=R/'Tests/RostrumTests/Fixtures/NativeListMarkers/fonts/DejaVuSans.ttf';H=Path('/tmp/verify-fidelity21-table-transition-paint-v3.py');old=Path('/tmp/verify-fidelity21-table-transition-paint-v2.py');assert not H.exists();H.write_text(old.read_text().replace("if c['admitted']:check_vectors(paint,c)","if c['admitted'] or a.mode=='browser':check_vectors(paint,c)"))
# In browser mode even the excluded merged native border must match exact fallback SVG paint.
D=B/'independent-final';assert not D.exists();D.mkdir();pins={str(H):sha(H),str(REF):sha(REF),str(FONT):sha(FONT)};rows=[];fail=[]
for index,p in enumerate(sorted(B.rglob('*capture.json'))):
 try:
  cap=read(p);pins[str(p)]=sha(p)
  for k in ('source','svg','pdf'):assert sha(cap[k])==cap[k+'SHA256'];pins[cap[k]]=cap[k+'SHA256']
  assert cap['renderingProfile']=='saved DeckInspector preview' and cap['fontReadiness']['status']=='loaded'and all(f['status']=='loaded'for f in cap['fontReadiness']['faces']);assert sha(cap['inputInspectorSVG'])==cap['inputInspectorSVGSHA256']==cap['svgSHA256'];pins[cap['inputInspectorSVG']]=sha(cap['inputInspectorSVG'])
  refs={x['referenceJSON']for x in cap['originalSpecimens']};assert len(refs)==1;f=Path(next(iter(refs)));assert sha(f)==sha(REF);pins[str(f)]=sha(f);cases=[c for c in read(REF)['cases']if c['slide']==cap['sourceSlideIndex']];assert [c['id']for c in cases]==[x['referenceID']for x in cap['originalSpecimens']]
  for c,descriptor in zip(cases,cap['originalSpecimens']):assert descriptor['nativeBorderAdmitted']==c['admitted']and descriptor['frame']=={k:c[k]for k in('x','y','width','height')}
  option='alternative-true'if'-true-slide-'in p.name else'alternative-false';np=Path('/tmp/lectern-fidelity21-generated-native')/option/'input-pins.json';n=read(np);assert cap['sourceSHA256']==n['inputSHA256'];pins[str(np)]=sha(np);workerSVG=Path(n['source']).parent/f"slide-{cap['sourceSlideIndex']+1}.svg"
  a,b=E.fromstring(Path(cap['svg']).read_bytes()),E.fromstring(workerSVG.read_bytes())
  for t in(a,b):t.attrib.pop('width');t.attrib.pop('height')
  assert E.tostring(a)==E.tostring(b),'Only native raw root viewport can differ; every remaining SVG node exact';pins[str(workerSVG)]=sha(workerSVG)
  output=D/f'{index}-comparison.json';log=D/f'{index}-capture.log';run=subprocess.run([PY,str(H),'--svg',cap['svg'],'--pdf',cap['pdf'],'--reference',str(f),'--font',str(FONT),'--slide',str(cap['sourceSlideIndex']),'--page','0','--mode','browser','--output',str(output)],capture_output=True,text=True);log.write_text(run.stdout+run.stderr);assert run.returncode==0,str(log);d=read(output)
  rows.append(dict(capture=str(p),captureSHA256=sha(p),comparison=str(output),comparisonSHA256=sha(output),log=str(log),logSHA256=sha(log),cases=len(d['results']),glyphs=d['visibleGlyphs'],nativePaintAdmitted=sum(x['nativeBorderAdmitted']for x in d['results']),allBrowserPaintIncludingMergedFallbackChecked=True,mode='browser'))
 except Exception as e:fail.append(dict(capture=str(p),error=repr(e)))
assert all(sha(p)==h for p,h in pins.items());totals=dict(PDFs=len(rows),cases=sum(x['cases']for x in rows),glyphs=sum(x['glyphs']for x in rows),nativePaintAdmitted=sum(x['nativePaintAdmitted']for x in rows))
if totals!=dict(PDFs=8,cases=28,glyphs=480,nativePaintAdmitted=26):fail.append(dict(expected=[8,28,480,26],actual=totals))
out=dict(status='FAIL'if fail else'PASS',totals=totals,results=rows,failures=fail,inputSHA256=pins,extractor=str(H),extractorSHA256=sha(H),scope='Fresh actual saved DeckInspector WebKit PDFs, every body scalar/source font/subset outline/raw matrices; vector.001RGB.0001 x.025/nativey.121/browser-SVGxy.025 size.002 unchanged. Complete browser ordered opaque paint checked for every case INCLUDING exact merged fallback; native reference border acceptance only26admitted cases. Both inputPPTXs exact generated native and worker SVG projection differs root viewport only, no wholesale rawSVG identity claim. Fifth computed page excluded.',script=str(Path(__file__)),scriptSHA256=sha(__file__))
p=D/'review-receipt.json';p.write_text(json.dumps(out,indent=2)+'\n');print(p,sha(p),totals,fail);assert not fail
