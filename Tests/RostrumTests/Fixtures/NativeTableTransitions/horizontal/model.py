"""Offline existing signed-extension hypothesis; no production source is edited."""
from pathlib import Path
import json,runpy
R=Path(__file__).resolve().parent
from projection import canonical
cases=json.loads((R/'cases.json').read_text());baseline=json.loads((R/'baseline-paint.json').read_text());native=json.loads((R/'paint-reference.json').read_text())
def box(line):
 x1,y1,x2,y2=line['points'];half=line['width']/2
 return [x1-half,y1,x2+half,y2] if x1==x2 else [x1,y1-half,x2,y2+half]
def paint(lines,x,y):
 chosen=None
 for line in lines:
  a,b,c,d=box(line)
  if a<x<c and b<y<d:chosen=tuple(round(v*255) for v in line['color'])
 return chosen
results=[];output=[]
for case,before,reference in zip(cases,baseline,native):
 assert case['id']==before['id']==reference['id']
 x,y,w,h=[case[k] for k in ['x','y','width','height']];xs=[x+sum(case['columnWidths'][:i]) for i in range(len(case['columnWidths'])+1)];ys=[y+sum(case['rowHeights'][:i]) for i in range(len(case['rowHeights'])+1)]
 raw=[]
 for line in before['lines']:
  line=dict(line);p=line['points'].copy();vertical=p[0]==p[2];axis=1 if vertical else 0;coords=ys if vertical else xs
  # Strip only pre-existing terminal half-width extensions on the admitted
  # positive control; all other before primitives already end on grid lines.
  for index in [axis,axis+2]:
   q=min(coords,key=lambda value:abs(value-p[index]));assert abs(q-p[index])<=2;p[index]=q
  line['points']=p;line['group']=(2 if (p[0] in [x,x+w] if vertical else p[1] in [y,y+h]) else 0)+(0 if vertical else 1);raw.append(line)
 modeled=[]
 for own in raw:
  p=own['points'];v=p[0]==p[2];axis=1 if v else 0;fixed=p[0] if v else p[1];ends=[]
  for position,lower in [(p[axis],True),(p[axis+2],False)]:
   donors=[];continuations=[]
   for other in raw:
    if other is own:continue
    q=other['points'];ov=q[0]==q[2]
    if ov!=v:
     cross=q[1] if v else q[0];a,b=(q[0],q[2]) if v else (q[1],q[3])
     if cross==position and a<=fixed<=b:donors.append(other['width'])
    elif (q[0] if v else q[1])==fixed and ((lower and q[axis+2]==position) or (not lower and q[axis]==position)):continuations.append(other['width'])
   assert len(continuations)<=1
   extension=max(donors,default=0)/2
   if continuations:extension*=0 if own['width']==continuations[0] else (1 if own['width']>continuations[0] else -1)
   ends.append(position-extension if lower else position+extension)
  q=p.copy();q[axis],q[axis+2]=ends;modeled.append(dict(own,points=q))
 modeled.sort(key=lambda line:line['group'])
 a,b=canonical(modeled),canonical(reference['lines']);assert a.keys()==b.keys();diff=[];maximum=0
 for key in a:
  assert len(a[key])==len(b[key]),(case['id'],key,a[key],b[key])
  for aa,bb in zip(a[key],b[key]):
   error=max(abs(p-q) for p,q in zip(aa,bb));maximum=max(maximum,error)
   if error>=.001:diff.append(dict(key=str(key),model=aa,native=bb,error=error))
 bounds=[box(line) for line in modeled+reference['lines']];xx=sorted(set(v for b in bounds for v in [b[0],b[2]]));yy=sorted(set(v for b in bounds for v in [b[1],b[3]]));mismatches=[];regions=0
 for left,right in zip(xx,xx[1:]):
  for top,bottom in zip(yy,yy[1:]):
   px,py=(left+right)/2,(top+bottom)/2;regions+=1
   if paint(modeled,px,py)!=paint(reference['lines'],px,py):mismatches.append(dict(point=[px,py],model=paint(modeled,px,py),native=paint(reference['lines'],px,py)))
 result=dict(id=case['id'],nativeIntervals=sum(map(len,b.values())),maximumEndpointError=maximum,endpointMismatches=diff,opaquePaintRegions=regions,paintMismatches=mismatches,scope='rejected merged interaction; not proposed for admission' if case.get('merge') else 'unmerged LTR transition research')
 results.append(result);output.append(dict(id=case['id'],lines=modeled))
(R/'model-paint.json').write_text(json.dumps(output,indent=2)+'\n');(R/'model-proof.json').write_text(json.dumps(dict(productionEdited=False,scope='Exact vector intervals and complete opaque paint subdivision; raw native path order retained; no raster or antialias claim',cases=results),indent=2)+'\n')
print(json.dumps([{k:v for k,v in c.items() if k not in ['endpointMismatches','paintMismatches']}|dict(endpointFailures=len(c['endpointMismatches']),paintFailures=len(c['paintMismatches'])) for c in results],indent=2))
