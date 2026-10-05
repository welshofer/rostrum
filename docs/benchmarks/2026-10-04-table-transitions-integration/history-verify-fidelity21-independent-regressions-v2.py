from pathlib import Path
import json,hashlib,subprocess,datetime
PYTHON='/Library/Frameworks/Python.framework/Versions/3.12/bin/python3'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();read=lambda p:json.loads(Path(p).read_text())
GROUPS=[('marker','-v3',48,554,6),('glyph','-v3',14,208,0),('mixed','',24,192,0),('alignment','',48,344,0),('tables','-v4',24,144,0),('profiles','-v1',16,224,0),('partial','-v1',24,144,0)]
allrows=[];allfail=[];allpins={}
for group,suffix,nc,ng,no in GROUPS:
 priorpath=Path(f'/tmp/lectern-fidelity20-{group}-webkit')/'independent-final'/'review-receipt.json';prior=read(priorpath);assert prior['status']=='PASS'
 base=Path(f'/tmp/lectern-fidelity21-{group}-webkit');out=base/'independent-final-v2';assert not out.exists();out.mkdir()
 pins={};rows=[];fail=[]
 def pin(p):
  p=Path(p).resolve();h=sha(p);assert str(p)not in pins or pins[str(p)]==h;pins[str(p)]=h;return h
 pin(priorpath);extractor=prior['extractor'];assert pin(extractor)==prior['extractorSHA256']
 for p,h in prior['inputSHA256'].items():assert pin(p)==h
 caps=sorted(base.rglob('*capture.json'));oldrows={Path(r.get('captureReceipt',r.get('capture'))).name:r for r in prior['results'] if r.get('mode','browser')=='browser'};assert len(caps)==len(oldrows)
 for idx,path in enumerate(caps):
  try:
   pin(path);cap=read(path);oldrow=oldrows[path.name];oldpath=oldrow.get('captureReceipt',oldrow.get('capture'));old=read(oldpath);assert pin(oldpath)==oldrow.get('captureReceiptSHA256',oldrow.get('captureSHA256'))
   for k in ['source','svg','pdf']:assert pin(cap[k])==cap[k+'SHA256']
   for k in ['sourceSHA256','svgSHA256','renderingProfile']:assert cap[k]==old[k],(group,path,k,'Changed input; native transfer disallowed')
   if 'sourceSlideIndex'in cap:assert cap['sourceSlideIndex']==old['sourceSlideIndex']
   assert cap['fontReadiness']['status']=='loaded'and cap['fontReadiness']['faces']and all(f['status']=='loaded'for f in cap['fontReadiness']['faces'])
   if cap['renderingProfile']=='saved DeckInspector preview':assert pin(cap['inputInspectorSVG'])==cap['inputInspectorSVGSHA256']==cap['svgSHA256']
   def normalize(s):
    x=dict(s);p=x.pop('referenceJSON',None)
    if p:x['referenceSHA256']=pin(p)
    return x
   if 'originalSpecimens'in cap:assert [normalize(s)for s in cap['originalSpecimens']]==[normalize(s)for s in old['originalSpecimens']]
   comparison=out/f'{idx}-comparison.json';log=out/f'{idx}-capture.log'
   cmd=[PYTHON,extractor,'--svg',cap['svg'],'--pdf',cap['pdf']]
   if group in ['tables','profiles','partial']:
    ref=cap['originalSpecimens'][0]['referenceJSON'];pin(ref);font='/Users/welshofer/Developer/rostrum/Tests/RostrumTests/Fixtures/NativeListMarkers/fonts/DejaVuSans.ttf';pin(font)
    cmd+=['--reference',ref,'--font',font,'--slide',str(cap['sourceSlideIndex']),'--page','0','--mode','browser']
    if group in ['profiles','partial']:cmd+=['--native-pages','3']
   else:
    ancestor=read(prior['priorReviewReceipt']);assert pin(prior['priorReviewReceipt'])==prior['priorReviewReceiptSHA256'];ancestorrow=next(r for r in ancestor['results'] if Path(r.get('captureReceipt',r.get('capture'))).name==path.name);descriptor=Path(ancestorrow['cases']);assert pin(descriptor)==ancestorrow['casesSHA256'];newdesc=out/f'{idx}-cases.json';newdesc.write_bytes(descriptor.read_bytes());cmd+=['--cases',str(newdesc)]
   cmd+=['--output',str(comparison)];run=subprocess.run(cmd,capture_output=True,text=True);log.write_text(run.stdout+run.stderr);assert run.returncode==0,'Extractor failure '+str(log)
   d=read(comparison);rs=d.get('cases',d.get('results'));cases=len(rs);glyphs=d.get('visibleGlyphs',sum(r.get('glyphCount',0)for r in rs));omissions=sum(len(r.get('explicitlyOmittedMarkers',[]))for r in rs)
   if group=='mixed':
    descriptors=read(newdesc)
    for actual,c in zip(rs,descriptors):
     cursor=0
     for line in c['native']['lines']:
      assert abs(actual['glyphs'][cursor]['pdfVsPriorNative'][0])<=.025
      for g,n in zip(actual['glyphs'][cursor:cursor+len(line['characters'])],line['characters']):assert g['sourceFace']==n['sourceFace']and g['sourceFaceSHA256']==n['sourceFaceSHA256']and g['SVGFaceMatches']
      cursor+=len(line['characters'])
     assert cursor==actual['glyphCount']
   rows.append(dict(capture=str(path),captureSHA256=sha(path),source=cap['source'],sourceSHA256=cap['sourceSHA256'],svg=cap['svg'],svgSHA256=cap['svgSHA256'],pdf=cap['pdf'],pdfSHA256=cap['pdfSHA256'],comparison=str(comparison),comparisonSHA256=sha(comparison),log=str(log),logSHA256=sha(log),cases=cases,glyphs=glyphs,explicitOmissions=omissions,exactS20SourceAndSVG=True))
  except Exception as e:fail.append(dict(capture=str(path),error=repr(e)))
 assert all(sha(p)==h for p,h in pins.items())
 totals={'captures':len(rows),'cases':sum(r['cases']for r in rows),'glyphs':sum(r['glyphs']for r in rows),'omissions':sum(r['explicitOmissions']for r in rows)}
 if [totals['cases'],totals['glyphs'],totals['omissions']]!=[nc,ng,no]:fail.append(dict(expected=[nc,ng,no],actual=totals))
 native=[r for r in prior['results']if r.get('mode')=='native'];receipt=dict(status='FAIL'if fail else'PASS',createdUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),group=group,scope='Fresh S21 browser PDF extraction, unchanged reviewed extractor/bounds. Every complete source PPTX and SVG byte-identical to audited S20; prior native captures transfer strictly by these inputs and revalidated prior pins, no fresh native opening/export claim. Original computed pages excluded from native scope. Kerning raw-library profile preserved; other captures actual saved inspector.',script=str(Path(__file__)),scriptSHA256=sha(__file__),extractor=extractor,extractorSHA256=sha(extractor),priorReviewReceipt=str(priorpath),priorReviewReceiptSHA256=sha(priorpath),inputSHA256=pins,unchangedInputBytes=True,results=rows,failures=fail,totals=totals,nativeEvidenceTransferredByExactSourceAndSVG=native)
 p=out/'review-receipt.json';p.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(dict(group=group,status=receipt['status'],totals=totals,receipt=str(p),sha256=sha(p))),flush=True);allrows.append(dict(group=group,receipt=str(p),sha256=sha(p),totals=totals));allfail.extend(fail);allpins.update(pins)
summary=dict(retainedInitialFailureReceipt='/tmp/rostrum-s21-independent-webkit-regression-review.json',retainedInitialFailureSHA256=sha('/tmp/rostrum-s21-independent-webkit-regression-review.json'),parserCorrection='Previous review result cases field is numeric count; resolve immutable descriptor via pinned S19 ancestor review instead. Original initial FAIL receipts/logs retained; no input/bounds changes.',status='FAIL'if allfail else'PASS',groups=allrows,failures=allfail,allFreshBrowserCases=sum(x['totals']['cases']for x in allrows),allFreshVisibleGlyphs=sum(x['totals']['glyphs']for x in allrows),allExplicitOmissions=sum(x['totals']['omissions']for x in allrows),inputSHA256=allpins,script=str(Path(__file__)),scriptSHA256=sha(__file__),scope='Seven independent fresh S21 browser regression groups. Exact complete PPTX and SVG input identity to S20, retained native transfer only; prior published evidence immutable. No tests/builds/GUI/benchmark launched.')
p=Path('/tmp/rostrum-s21-independent-webkit-regression-review-v2.json');assert not p.exists();p.write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(dict(status=summary['status'],cases=summary['allFreshBrowserCases'],glyphs=summary['allFreshVisibleGlyphs'],omissions=summary['allExplicitOmissions'],receipt=str(p),sha256=sha(p))),flush=True)
assert not allfail
