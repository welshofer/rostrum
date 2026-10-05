"""Offline missing-edge model, validated against every native vector interval and paint region."""
from pathlib import Path
import json
R=Path(__file__).resolve().parent
def key(line):
 p=line['points'];v=p[0]==p[2]
 return (v,round(p[0] if v else p[1],5),line['width'],tuple(round(x*255) for x in line['color']),line['opacity'])
def canonical(lines):
 groups={}
 for line in lines:
  p=line['points'];v=p[0]==p[2];groups.setdefault(key(line),[]).append([p[1] if v else p[0],p[3] if v else p[2]])
 result={}
 for k,spans in groups.items():
  out=[]
  for a,b in sorted(spans):
   if out and abs(out[-1][1]-a)<.001:out[-1][1]=b
   else:out.append([a,b])
  result[k]=out
 return result

cases=json.loads((R/'cases.json').read_text());native=json.loads((R/'native-vectors.json').read_text());reads=json.loads((R/'model-input.json').read_text())['reads'];results=[]
def rgb(s):return [int(s[i:i+2],16)/255 for i in [0,2,4]]
def stroke_box(line):
 x1,y1,x2,y2=line['points'];h=line['width']/2
 return [x1-h,y1,x2+h,y2] if x1==x2 else [x1,y1-h,x2,y2+h]
def last_color(seq,x,y):
 selected=None
 for box,color in seq:
  if box[0]<x<box[2] and box[1]<y<box[3]:selected=tuple(round(c*255) for c in color)
 return selected
for case,observed,api in zip(cases,native['cases'],reads):
 assert case['id']==observed['id']==api['id']
 rows,cols=case['rows'],case['columns'];x,y,w,h=(case[k] for k in ['x','y','width','height'])
 raw=[]
 for cell in api['cells']:
  row,col=cell['row'],cell['column']
  for edge in ['a:lnL','a:lnR','a:lnT','a:lnB']:
   if edge=='a:lnL' and col>0 or edge=='a:lnT' and row>0:continue
   line=cell['resolvedBorders'][edge]
   if not line['present']:width=1;color=[0,0,0]
   elif line['none'] or line['color'] is None:continue
   else:width=(line['widthEMU'] if line['widthEMU'] is not None else 12700)/12700;color=rgb(line['color'])
   vertical=edge in ['a:lnL','a:lnR'];boundary=(col+(edge=='a:lnR')) if vertical else (row+(edge=='a:lnB'))
   points=[x+boundary*w/cols,y+row*h/rows,x+boundary*w/cols,y+(row+1)*h/rows] if vertical else [x+col*w/cols,y+boundary*h/rows,x+(col+1)*w/cols,y+boundary*h/rows]
   outer=boundary in [0,cols if vertical else rows]
   raw.append(dict(points=points,width=width,color=color,opacity=1,group=(2 if outer else 0)+(0 if vertical else 1)))
 modeled=[]
 for own in raw:
  p=own['points'];v=p[0]==p[2];axis=1 if v else 0;fixed=p[0] if v else p[1];ends=[]
  for pos,lower in [(p[axis],True),(p[axis+2],False)]:
   donors=[];continuation=[]
   for other in raw:
    if other is own:continue
    q=other['points'];ov=q[0]==q[2]
    if ov!=v:
     cross=q[1] if v else q[0];a,b=(q[0],q[2]) if v else(q[1],q[3])
     if cross==pos and a<=fixed<=b:donors.append(other['width'])
    elif (q[0] if v else q[1])==fixed:
     if lower and q[axis+2]==pos or not lower and q[axis]==pos:continuation.append(other['width'])
   assert len(continuation)<=1
   ext=max(donors,default=0)/2
   if continuation:ext*=0 if own['width']==continuation[0] else (1 if own['width']>continuation[0] else -1)
   ends.append(pos-ext if lower else pos+ext)
  p=p.copy();p[axis],p[axis+2]=ends;modeled.append(dict(own,points=p))
 modeled.sort(key=lambda p:p['group'])
 expected=[];native_paint=[]
 for path in observed['paths']:
  item=path['items'][0];assert len(path['items'])==1
  if path['type']=='f':native_paint.append((item[1],path['fill']))
  else:
   line=dict(points=item[1]+item[2],width=path['width'],color=path['color'],opacity=path['stroke_opacity']);expected.append(line);native_paint.append((stroke_box(line),line['color']))
 actual_paint=[]
 for fill in json.loads((R/'model-input.json').read_text())['fills'][case['id']]:actual_paint.append((fill['bounds'],fill['color']))
 actual_paint.extend((stroke_box(line),line['color']) for line in modeled)
 a,b=canonical(modeled),canonical(expected);assert a.keys()==b.keys()
 max_error=0
 for k in a:
  assert len(a[k])==len(b[k])
  max_error=max(max_error,*[abs(p-q) for aa,bb in zip(a[k],b[k]) for p,q in zip(aa,bb)])
 assert max_error<.001
 # Exact planar subdivision for these opaque flat rectangles. Every open
 # rectangle of the combined edge arrangement has constant final paint.
 xs=sorted(set(v for box,_ in actual_paint+native_paint for v in [box[0],box[2]]));ys=sorted(set(v for box,_ in actual_paint+native_paint for v in [box[1],box[3]]));regions=0
 for l,r in zip(xs,xs[1:]):
  for t,bottom in zip(ys,ys[1:]):
   px,py=(l+r)/2,(t+bottom)/2
   assert last_color(actual_paint,px,py)==last_color(native_paint,px,py),(case['id'],px,py)
   regions+=1
 results.append(dict(id=case['id'],nativeIntervals=sum(map(len,canonical(expected).values())),maxEndpointError=max_error,completeOpaquePaintRegionsCompared=regions))
(R/'model-reproduction.json').write_text(json.dumps(dict(cases=results,totalNativeIntervals=sum(c['nativeIntervals'] for c in results),scope='Every opaque fill/stroke region in combined rectangle-edge arrangement; actual baseline fills, modeled default edges, native ordered PDF paths. No raster/antialias boundary claim.',originalPreEditProof='model-proof.json retained before production edits; rerunning verifies the same modeled projection'),indent=2)+'\n')
print(json.dumps(results,indent=2))
