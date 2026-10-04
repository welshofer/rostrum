"""Quantify PDF font-width/Tc/TJ placement for the largest model residual."""
from pathlib import Path
from pypdf import PdfReader
from fontTools.ttLib import TTFont
import json,math
ROOT=Path(__file__).resolve().parent
reader=PdfReader(ROOT/'powerpoint.pdf');page=reader.pages[0]
mat=(1,0,0,1,0,0);stack=[];tc=0;tw=0;tf=1;tm=(1,0,0,1,0,0);font=None;records=[]
def mul(l,r):
 a,b,c,d,e,f=l;g,h,i,j,k,m=r
 return(a*g+c*h,b*g+d*h,a*i+c*j,b*i+d*j,a*k+c*m+e,b*k+d*m+f)
for args,op in page.get_contents().operations:
 if op==b'q':stack.append((mat,tc,tw,tf,font))
 elif op==b'Q':mat,tc,tw,tf,font=stack.pop()
 elif op==b'cm':mat=mul(mat,tuple(map(float,args)))
 elif op==b'Tc':tc=float(args[0])
 elif op==b'Tw':tw=float(args[0])
 elif op==b'Tf':font=str(args[0]);tf=float(args[1])
 elif op==b'Tm':tm=tuple(map(float,args))
 elif op in [b'Tj',b'TJ']:
  combined=mul(mat,tm)
  # Exact source case: first bold line, page0,x30,top-down baseline283.92.
  if font!='/TT4' or abs(combined[4]-30)>.001 or abs(720-combined[5]-283.92)>.001:continue
  face=page['/Resources']['/Font'][font].get_object();assert str(face['/Encoding'])=='/MacRomanEncoding'
  first=int(face['/FirstChar']);widths=list(map(float,face['/Widths']));offset=0;adjust=0
  chunks=args[0] if op==b'TJ' else [args[0]]
  for chunk in chunks:
   if isinstance(chunk,(float,int)):
    delta=-float(chunk)/1000*tf;offset+=delta;adjust+=delta;continue
   raw=chunk.original_bytes if hasattr(chunk,'original_bytes') else bytes(chunk)
   for value in raw:
    char=bytes([value]).decode('mac_roman');w=widths[value-first]
    records.append(dict(text=char,pdfX=combined[4]+offset*combined[0]-30,pdfWidth1000=w,charSpacing=tc,precedingTJTextAdjustment=adjust))
    offset+=(w/1000*tf)+tc+(tw if value==32 else 0);adjust=0
native=next(c for c in json.loads((ROOT/'native-paint-metrics.json').read_text())['cases'] if c['name']=='bold-authored14p50-wrap')['lines'][0]['characters']
assert ''.join(r['text'] for r in records)==''.join(g['text'] for g in native)
font=TTFont(ROOT/'fonts/DejaVuSans-Bold.ttf');cmap=font.getBestCmap();units=font['head'].unitsPerEm;layout_x=0
for r,g in zip(records,native):
 r['traceX']=g['x'];r['reconstructionResidual']=r['pdfX']-g['x'];r['layoutGridX']=layout_x;r['exportVersusLayout']=r['pdfX']-layout_x
 raw=font['hmtx'][cmap[ord(r['text'])]][0]*14.5/units;layout_x+=math.floor(raw*8+.5)/8
result=dict(case='bold-authored14p50-wrap',operator='TJ',fontResource='/TT4',paintSize=13.9999992,authoredSize=14.5,maxReconstructionResidual=max(abs(r['reconstructionResidual']) for r in records),maxExportVersusLayout=max(abs(r['exportVersusLayout']) for r in records),records=records)
(ROOT/'pdf-advance-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='records'},indent=2))
