"""Identical adjacent paint interval projection, independent of endpoint model."""
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
