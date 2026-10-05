from pathlib import Path
import json,re
from lxml import etree
R=Path(__file__).resolve().parent;cases=json.loads((R/'cases.json').read_text());native=json.loads((R/'paint-reference.json').read_text());S='http://www.w3.org/2000/svg'
def canonical(lines):
 groups={}
 for line in lines:
  p=line['points'];v=p[0]==p[2];assert v or p[1]==p[3]
  k=(v,round(p[0] if v else p[1],5),line['width'],tuple(round(x*255) for x in line['color']),line['opacity'])
  groups.setdefault(k,[]).append(sorted([p[1] if v else p[0],p[3] if v else p[2]]))
 result={}
 for key,spans in groups.items():
  out=[]
  for a,b in sorted(spans):
   if out and abs(out[-1][1]-a)<.001:out[-1][1]=b
   else:out.append([a,b])
  result[key]=out
 return result
results=[];baseline=[]
for case,reference in zip(cases,native):
 assert case['id']==reference['id'];svg=etree.parse(str(R/'before'/f"slide-{case['page']}.svg"));x,y,w,h=(case[k] for k in ['x','y','width','height']);inside=lambda px,py:x-6<=px<=x+w+6 and y-6<=py<=y+h+6
 lines=[];glyphs=[]
 for node in svg.iter():
  if node.tag==f'{{{S}}}line':
   p=[float(node.get(k))/12700 for k in ['x1','y1','x2','y2']]
   if inside(p[0],p[1]):lines.append(dict(points=p,width=float(node.get('stroke-width'))/12700,color=[int(node.get('stroke')[i:i+2],16)/255 for i in [1,3,5]],opacity=float(node.get('stroke-opacity','1'))))
  if node.tag==f'{{{S}}}text' and node.get('transform'):
   tx,ty,scale=map(float,re.findall(r'[-+]?\d+(?:\.\d+)?',node.get('transform')));assert scale==12700
   if not inside(tx/12700,ty/12700):continue
   for span in node:
    xs=list(map(float,span.get('x').split()));txt=span.text or '';assert len(xs)==len(txt)
    glyphs.extend(dict(text=t,origin=[tx/12700+sx,ty/12700],size=float(span.get('font-size'))) for t,sx in zip(txt,xs))
 a,b=canonical(lines),canonical(reference['lines']);assert a.keys()==b.keys(),case['id'];diff=[];count=0;maximum=0
 for key in a:
  assert len(a[key])==len(b[key]),(case['id'],key,a[key],b[key])
  for aa,bb in zip(a[key],b[key]):
   count+=1;error=max(abs(p-q) for p,q in zip(aa,bb));maximum=max(maximum,error)
   if error>=.001:diff.append(dict(key=str(key),before=aa,native=bb,error=error))
 assert ''.join(g['text'] for g in glyphs)==''.join(g['text'] for g in reference['glyphs'])
 dx=max(abs(a['origin'][0]-b['origin'][0]) for a,b in zip(glyphs,reference['glyphs']));dy=max(abs(a['origin'][1]-b['origin'][1]) for a,b in zip(glyphs,reference['glyphs']));ds=max(abs(a['size']-b['size']) for a,b in zip(glyphs,reference['glyphs']))
 results.append(dict(id=case['id'],nativeIntervals=count,failingIntervals=len(diff),maximumEndpointError=maximum,glyphCount=len(glyphs),maximumGlyphXError=dx,maximumGlyphYError=dy,maximumPaintSizeError=ds,differences=diff))
 baseline.append(dict(id=case['id'],lines=lines,glyphs=glyphs))
(R/'baseline-paint.json').write_text(json.dumps(baseline,indent=2)+'\n');(R/'before-comparison.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps([{k:v for k,v in r.items() if k!='differences'} for r in results],indent=2))
