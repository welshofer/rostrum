from pathlib import Path
import json,hashlib,zipfile
from lxml import etree as E
p=Path('/tmp/lectern-fidelity21-manual/manual-table-transitions-verification.json');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();read=lambda p:json.loads(Path(p).read_text());d=read(p);assert sha(p)=='ca3eefdd624ab371897aa6ef81edd5454d5b845dc8b0a4a46e2877fcd94470ff';assert sha(d['script'])==d['scriptSHA256'];assert sha(Path(d['app'])/'Contents/MacOS/Lectern')==d['appBinarySHA256AtBothManualRuns'];N={'a':'http://schemas.openxmlformats.org/drawingml/2006/main','p':'http://schemas.openxmlformats.org/presentationml/2006/main'};pins={str(p):sha(p),d['script']:sha(d['script'])};rows=[]
for v in d['variants']:
 for f,h in v['files'].items():assert sha(f)==h,f;pins[f]=h
 before=read(next(f for f in v['files']if f.endswith('-before.json')));assert before['pptxSHA256']==v['sourceSHA256']==sha(v['source'])and before['appBinarySHA256']==d['appBinarySHA256AtBothManualRuns'];assert v['checks']==before['observedChecks']==68 and v['findings']==before['findings']==0 and v['slides']==before['observedSlides']==5
 assert v['sourceUnchangedFromBeforeInspectionThroughCompletedExport'];report=read(Path(v['source']).parent/'report.json');assert len(report['checks'])==68 and all(c['passed']for c in report['checks'])and not report['findings'];mdpath=next(Path(f)for f in v['files']if'-export/'in f and f.endswith('.md'));md=mdpath.read_text().replace('\\|','|').replace('\\\n  ','\n');xmlparts=0
 with zipfile.ZipFile(v['source'])as z:
  assert z.testzip()is None and len(z.namelist())==len(set(z.namelist()));texts=[];slides=[]
  for name in z.namelist():
   if name.endswith(('.xml','.rels')):E.fromstring(z.read(name));xmlparts+=1
   if name.startswith('ppt/slides/slide')and name.endswith('.xml'):slides.append(name);texts+=E.fromstring(z.read(name)).xpath('//a:t/text()',namespaces=N)
  assert len(slides)==5 and len(texts)==v['sourceTextNodes']==82 and all(t in md for t in texts if t);assert xmlparts==v['parsedXMLAndRels']==69
 for s in v['svgComparison']:
  assert sha(s['manual'])==s['manualSHA256']==sha(s['appGateSavedPreview'])==s['appGateSavedPreviewSHA256']and sha(s['rawLibrary'])==s['rawLibrarySHA256']
  a,b=E.fromstring(Path(s['manual']).read_bytes()),E.fromstring(Path(s['rawLibrary']).read_bytes())
  def projection(n):return(n.tag,tuple(sorted(n.attrib.items())),n.text,n.tail,tuple(projection(x)for x in n))
  assert a.attrib.keys()==b.attrib.keys()
  for n in(a,b):n.attrib.pop('width');n.attrib.pop('height')
  assert projection(a)==projection(b)
 native=Path('/tmp/lectern-fidelity21-generated-native')/('alternative-true'if v['options']['alternative']else'alternative-false')/'tableTransitions.pptx';assert sha(native)==v['sourceSHA256'];rows.append(dict(option=v['variant'],checks=68,findings=0,slides=5,textNodes=82,xmlParts=69,sourceExactNative=True,allFiveSVGsExactSavedApp=True,rawOnlyRootViewportDifference=True))
out=dict(status='PASS_INDEPENDENT_FILES_FOR_ROOT_ATTESTED_S21_MANUAL_WORKFLOWS',receipt=str(p),receiptSHA256=sha(p),uniqueArtifactPins=len(pins)-2,inputSHA256=pins,rows=rows,scope='Root owns actual GUI observations. Reviewer independently checked exact source/app hashes, before-snapshot/source immutability,68checks/zero findings peroption,all82textnodes each through constrained Markdown unescape,ZIP CRC69XML/rels/5slides each,all10actualsavedAppSVGs exact and only rootviewport difference against raw. Sourcepackages exact already numerically audited generatednative; no fifthpage nativegeometry or broad renderer/media parity claim.',script=str(Path(__file__)),scriptSHA256=sha(__file__));q=Path('/tmp/rostrum-s21-independent-manual-review.json');assert not q.exists();q.write_text(json.dumps(out,indent=2)+'\n');print(q,sha(q),len(pins)-2)
