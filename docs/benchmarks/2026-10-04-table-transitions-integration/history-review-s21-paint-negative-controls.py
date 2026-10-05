from pathlib import Path
import json,copy,importlib.util,hashlib,fitz
H=Path('/tmp/verify-fidelity21-table-transition-paint-v3.py');spec=importlib.util.spec_from_file_location('transition_audit',H);h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h);R=Path('/path/to/user/Developer/rostrum');F=R/'Lectern/Sources/LecternCore/Resources/LibraryLab/TableTransitionsReferences.json';ref=json.loads(F.read_text());c=ref['cases'][0];actual={k:copy.deepcopy(c[k])for k in('lines','fills')};h.check_vectors(copy.deepcopy(actual),c);results=[]
def reject(name,value,expected=c):
 try:h.check_vectors(value,expected)
 except AssertionError:results.append(dict(name=name,rejected=True));return
 raise AssertionError('Negative escaped:'+name)
a=copy.deepcopy(actual);a['lines'].append(copy.deepcopy(a['lines'][0]));reject('extra stroke',a)
a=copy.deepcopy(actual);a['lines'].pop();reject('missing stroke',a)
a=copy.deepcopy(actual);a['lines'][0]['points'][3]-=.1;reject('endpoint gap',a)
a=copy.deepcopy(actual);a['lines'][0]['width']+=.1;reject('changed width',a)
a=copy.deepcopy(actual);a['lines'][0]['color']=[.7,.2,.3];reject('changed RGB',a)
for cc in ref['cases']:
 if not cc['admitted']:continue
 a={k:copy.deepcopy(cc[k])for k in('lines','fills')};a['lines'].reverse()
 try:h.check_vectors(a,cc)
 except AssertionError:results.append(dict(name='incorrect crossing order',case=cc['id'],rejected=True));break
else:raise AssertionError('No crossing-order negative found')
cap=next(Path('/tmp/lectern-fidelity21-transitions-webkit').rglob('*false-slide-1-capture.json'));d=json.loads(cap.read_text());doc=fitz.open(d['pdf']);paths=doc[0].get_drawings();matched=[]
for p in paths:
 if p['type']in('s','fs')and len(p['items'])==1 and p['items'][0][0]=='l' and c['x']-3<=p['rect'].x0<=c['x']+c['width']+3 and c['y']-3<=p['rect'].y0<=c['y']+c['height']+3:matched.append(p)
assert matched
class Fake:
 def __init__(self,p):self.p=p
 def get_drawings(self):return[self.p]
for name,change in [('round cap',lambda p:p.update(lineCap=(1,1,1))),('square cap',lambda p:p.update(lineCap=(2,2,2))),('nonzero fs polygon',lambda p:p.update(type='fs',items=[('re',fitz.Rect(c['x'],c['y'],c['x']+1,c['y']+1),1)]))]:
 p=copy.deepcopy(matched[0]);change(p)
 try:h.pdf_paint(Fake(p),c,1)
 except AssertionError:results.append(dict(name=name,rejected=True));continue
 raise AssertionError('Parser negative escaped:'+name)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();out=dict(status='PASS_ADDITIVE_TRANSITION_ADAPTER_NEGATIVE_CONTROLS',positiveReference=c['id'],controls=results,extractor=str(H),extractorSHA256=sha(H),reference=str(F),referenceSHA256=sha(F),actualBrowserCapture=str(cap),actualBrowserCaptureSHA256=sha(cap),scope='Synthetic copies only; actual source/PDF/refs and all bounds unchanged. Extra/missing/gap/width/color/crossing-order/raw butt cap/nonzero fs rejection checks; original helper/readiness/failed history retained.',script=str(Path(__file__)),scriptSHA256=sha(__file__));p=Path('/tmp/rostrum-s21-independent-paint-negative-controls.json');assert not p.exists();p.write_text(json.dumps(out,indent=2)+'\n');print(p,sha(p),len(results))
