"""Bounded table native/WebKit vector and glyph-trace audit. No ink/raster claim.
Original /tmp/verify-webkit-paint.py is imported read-only for reviewed PDF matrix
and outline extraction. This helper does not use trace bounding boxes as ink.
"""
from pathlib import Path
from io import BytesIO
import argparse,hashlib,json,re,importlib.util
import xml.etree.ElementTree as ET
import fitz
from pypdf import PdfReader
from fontTools.ttLib import TTFont
spec=importlib.util.spec_from_file_location('reviewed_pdf','/tmp/verify-webkit-paint.py')
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
assert hashlib.sha256(Path('/tmp/verify-webkit-paint.py').read_bytes()).hexdigest()=='e4f5433152953381e9f1a226163d6f60d9ae77f7d17948af7e13cabf39c77f48'
SHA=lambda b:hashlib.sha256(b).hexdigest()
local=lambda n:n.tag.rsplit('}',1)[-1]
def same(a,b,t):return len(a)==len(b) and all(abs(x-y)<t for x,y in zip(a,b))
def canonical(lines):
 out=[]
 for x in lines:
  p=list(x['points']);assert len(p)==4 and (abs(p[0]-p[2])<.001 or abs(p[1]-p[3])<.001)
  if p[0]>p[2] or (p[0]==p[2] and p[1]>p[3]):p=p[2:]+p[:2]
  out.append(dict(x,points=p))
 def key(x):
  p=x['points'];v=abs(p[0]-p[2])<.001
  return [int(v),p[0] if v else p[1],x['width'],*x['color'],x['opacity'],p[1] if v else p[0]]
 out.sort(key=key);joined=[]
 for x in out:
  if joined:
   p=joined[-1];v=abs(p['points'][0]-p['points'][2])<.001;w=abs(x['points'][0]-x['points'][2])<.001
   if p['opacity']==x['opacity']==1 and p['color']==x['color'] and p['width']==x['width'] and v==w and same(p['points'][2:],x['points'][:2],.001):
    joined[-1]=dict(p,points=p['points'][:2]+x['points'][2:]);continue
  joined.append(x)
 return joined
def check_vectors(actual,expected):
 assert len(actual['fills'])==len(expected['fills']),('fill count',expected['id'])
 for a,b in zip(actual['fills'],expected['fills']):
  assert same(a['bounds'],b['bounds'],.001) and same(a['color'],b['color'],.0001) and a['opacity']==b['opacity'],('fill',expected['id'],a,b)
 aa,bb=canonical(actual['lines']),canonical(expected['lines']);assert len(aa)==len(bb),('complete stroke coverage',expected['id'],len(aa),len(bb))
 for a,b in zip(aa,bb):
  assert same(a['points'],b['points'],.001) and same(a['color'],b['color'],.0001) and abs(a['width']-b['width'])<.001 and a['opacity']==b['opacity'],('stroke',expected['id'],a,b)
 def rectangle(l):
  x1,y1,x2,y2=l['points'];h=l['width']/2
  return [x1-h,min(y1,y2),x1+h,max(y1,y2)] if x1==x2 else [min(x1,x2),y1-h,max(x1,x2),y1+h]
 def paint(v):
  return v['fills']+[dict(bounds=rectangle(l),color=l['color'],opacity=l['opacity'])for l in v['lines']]
 ap,ep=paint(actual),paint(expected);assert all(p['opacity']==1 for p in ap+ep)
 def last(v,x,y):
  out=None
  for p in v:
   l,t,r,b=p['bounds']
   if l<x<r and t<y<b:out=p['color']
  return out
 def edges(axis):
  out=[]
  for value in sorted({p['bounds'][i]for p in ap+ep for i in axis}):
   if not out or value-out[-1]>.001:out.append(value)
  return out
 xs,ys=edges([0,2]),edges([1,3]);regions=0
 for x1,x2 in zip(xs,xs[1:]):
  for y1,y2 in zip(ys,ys[1:]):
   x,y=(x1+x2)/2,(y1+y2)/2;ac,ec=last(ap,x,y),last(ep,x,y)
   assert (ac is None)==(ec is None),('ordered fill/stroke arrangement coverage',expected['id'],x,y,ac,ec)
   if ac is not None:assert same(ac,ec,.0001),('ordered fill/stroke arrangement color',expected['id'],x,y,ac,ec)
   regions+=1
 actual['completeOpaqueArrangementRegions']=regions

def svg_paint(root,c):
 result=dict(fills=[],lines=[]);inside=lambda x,y,pad: c['x']-pad<=x<=c['x']+c['width']+pad and c['y']-pad<=y<=c['y']+c['height']+pad
 def number(n,k):return float(n.attrib[k])/12700
 def color(v):assert re.fullmatch('#[0-9a-fA-F]{6}',v);return [int(v[i:i+2],16)/255 for i in [1,3,5]]
 for n in root.iter():
  if local(n)=='g':assert n.get('transform') is None
  if local(n)=='rect' and inside(number(n,'x'),number(n,'y'),.001) and number(n,'x')<c['x']+c['width'] and number(n,'y')<c['y']+c['height']:
   assert n.get('transform') is None
   x,y,w,h=[number(n,k) for k in ['x','y','width','height']];result['fills'].append(dict(bounds=[x,y,x+w,y+h],color=color(n.get('fill')),opacity=float(n.get('fill-opacity','1'))))
  if local(n)=='line' and inside(number(n,'x1'),number(n,'y1'),3):
   assert n.get('transform') is None and n.get('stroke-dasharray') is None and n.get('stroke-linecap','butt')=='butt'
   result['lines'].append(dict(points=[number(n,k) for k in ['x1','y1','x2','y2']],color=color(n.get('stroke')),opacity=float(n.get('stroke-opacity','1')),width=number(n,'stroke-width')))
 return result
def pdf_paint(page,c,scale):
 result=dict(fills=[],lines=[])
 for p in page.get_drawings():
  r=[x/scale for x in p['rect']];over=r[2]>=c['x']-3 and r[0]<=c['x']+c['width']+3 and r[3]>=c['y']-3 and r[1]<=c['y']+c['height']+3
  if not over or r[2]-r[0]>=300 or r[3]-r[1]>=300:continue
  for it in p['items']:
   if p['type']=='f':
    if len(p['items'])==1 and it[0]=='l' and not p['closePath'] and (abs(it[1].x-it[2].x)<1e-8 or abs(it[1].y-it[2].y)<1e-8):
     # WebKit also emits the same zero-area fill separately when stroke color differs.
     continue
    assert it[0]=='re';result['fills'].append(dict(bounds=[x/scale for x in it[1]],color=list(p['fill']),opacity=p['fill_opacity']))
   else:
    if p['type']=='fs':
     # MuPDF merges WebKit's zero-area m/l/f with the separate matching m/l/S.
     # A single open axis-aligned segment has zero fill area; never discard a polygon fill.
     assert len(p['items'])==1 and it[0]=='l' and not p['closePath'] and (abs(it[1].x-it[2].x)<1e-8 or abs(it[1].y-it[2].y)<1e-8),('nonzero/closed/compound fs path',c['id'],p)
    assert p['type'] in ['s','fs'] and it[0]=='l' and p['dashes']=='[] 0' and p['lineCap']==(0,0,0),('unsupported native/browser path',c['id'],p)
    result['lines'].append(dict(points=[x/scale for point in it[1:3] for x in point],color=list(p['color']),opacity=p['stroke_opacity'],width=p['width']/scale))
 return result
def svg_chars(root,c,aliases):
 chars=[];unsupported=['y','dy','dx','rotate','baseline-shift','text-anchor','dominant-baseline','alignment-baseline']
 for n in root.iter():
  if local(n)!='text':continue
  if not n.get('transform','').startswith('translate('):continue
  v=old.numbers(n.get('transform'));assert len(v)==3 and v[2]==12700
  x,y=v[0]/12700,v[1]/12700
  if not c['x']-.001<=x<c['x']+c['width'] or not c['y']<=y<c['y']+c['height']:continue
  assert n.get('x') is None and all(n.get(a) is None for a in unsupported)
  for s in n:
   assert local(s)=='tspan' and all(s.get(a) is None for a in unsupported+['transform','textLength','lengthAdjust'])
   assert s.get('font-style')!='italic' and s.get('font-weight','400')=='400';assert s.get('font-family','').split(',')[0] in aliases
   text=''.join(s.itertext());xs=old.numbers(s.get('x'));assert len(text)==len(xs)
   for ch,offset in zip(text,xs):
    if ch!=' ':chars.append(dict(text=ch,x=x+offset,y=y,size=float(s.attrib['font-size'])))
 return chars
def main():
 p=argparse.ArgumentParser();p.add_argument('--svg',required=True);p.add_argument('--pdf',required=True);p.add_argument('--reference',required=True);p.add_argument('--font',required=True);p.add_argument('--slide',type=int,required=True);p.add_argument('--page',type=int,default=0);p.add_argument('--mode',choices=['native','browser'],required=True);p.add_argument('--native-pages',type=int,default=4);p.add_argument('--output',required=True);a=p.parse_args()
 svg=Path(a.svg).read_bytes();pdf=Path(a.pdf).read_bytes();reference=Path(a.reference).read_bytes();fontdata=Path(a.font).read_bytes();assert SHA(fontdata)=='7da195a74c55bef988d0d48f9508bd5d849425c1770dba5d7bfc6ce9ed848954'
 root=ET.fromstring(svg);view=old.numbers(root.get('viewBox'));assert view==[0,0,9144000,9144000]
 aliases={m.group(1) for m in re.finditer(r"@font-face\{font-family:'([^']+)'[^}]*base64,([^)]*)",svg.decode()) if __import__('base64').b64decode(m.group(2))==fontdata};assert aliases
 doc=fitz.open(stream=pdf,filetype='pdf');assert (len(doc)==1 if a.mode=='browser' else len(doc)==a.native_pages);page=doc[a.page];scale=page.rect.width/720;assert abs(page.rect.height/720-scale)<1e-6
 reader=PdfReader(BytesIO(pdf));matrices=old.raw_matrices(reader.pages[a.page]);vectors=old.vector_matrices(page);fonts={}
 for item in page.get_fonts(full=True):
  _,ext,_,data=doc.extract_font(item[0])
  if ext in ['ttf','otf']:fonts[item[3].split('+')[-1]]=(TTFont(BytesIO(data)),SHA(data))
 trace=[]
 for span in page.get_texttrace():
  for scalar,gid,origin,bbox in span['chars']:
   if scalar!=32:trace.append(dict(text=chr(scalar),gid=gid,font=span['font'],x=origin[0]/scale,y=origin[1]/scale,color=list(span['color'])))
 source=TTFont(BytesIO(fontdata));units=source['head'].unitsPerEm;cmap=source.getBestCmap();used=set();results=[]
 cases=[c for c in json.loads(reference)['cases'] if c['slide']==a.slide];assert len(cases)==({0:4,1:4,2:4,3:2}[a.slide])
 for c in cases:
  check_vectors(svg_paint(root,c),c);paint=pdf_paint(page,c,scale)
  if c['admitted'] or a.mode=='browser':check_vectors(paint,c)
  else:assert c['id']=='merged-colored-rejection' and isinstance(c['nativeLinesExcluded'],list) and len(c['nativeLinesExcluded'])==8
  sg=svg_chars(root,c,aliases);assert len(sg)==len(c['glyphs']);records=[]
  for index,(g,native) in enumerate(zip(sg,c['glyphs'])):
   assert g['text']==native['text'];xlimit=.025
   cand=[(i,t) for i,t in enumerate(trace) if i not in used and t['text']==g['text'] and abs(t['x']-g['x'])<(.025 if a.mode=='browser' else xlimit) and abs(t['y']-g['y'])<(.025 if a.mode=='browser' else .121)];assert len(cand)==1,(c['id'],g,cand);i,t=cand[0];used.add(i)
   assert abs(t['x']-native['origin'][0])<xlimit and abs(t['y']-native['origin'][1])<.121 and same(t['color'],native['color'],.0001)
   subset,h=fonts[t['font']];assert subset['head'].unitsPerEm==units;assert old.signature(subset,subset.getGlyphOrder()[t['gid']])==old.signature(source,cmap[ord(t['text'])])
   vv=[v for v in vectors if v['text']==t['text'] and abs(v['matrix'][4]/scale-t['x'])<.002 and abs(v['matrix'][5]/scale-t['y'])<.002];assert len(vv)==1
   mm=[m for m in matrices if m['font']==t['font'] and abs(m['matrix'][5]/scale-t['y'])<=.025 and all(abs(x-y)<.00002 for x,y in zip(m['matrix'][:4],vv[0]['matrix'][:4]))];assert mm
   linear={tuple(round(x/scale,6) for x in m['matrix'][:4]) for m in mm};assert len(linear)==1;ax,bx,cx,dy=next(iter(linear));assert abs(bx)<1e-6 and abs(cx)<1e-6 and ax>0 and dy<0
   assert abs(ax-g['size'])<.002 and abs(-dy-g['size'])<.002 and abs(ax-native['size'])<.002 and abs(-dy-native['size'])<.002
   records.append(dict(text=t['text'],subsetSHA256=h,sourceOutlineMatches=True,pdfVsSVG=[t['x']-g['x'],t['y']-g['y']],pdfVsPriorNative=[t['x']-native['origin'][0],t['y']-native['origin'][1]],paintSize=[ax,-dy]))
  results.append(dict(id=c['id'],glyphCount=len(records),glyphs=records,pdfPaint=paint,nativeBorderAdmitted=c['admitted'],vectorProof=('Complete opaque paint checked at .001pt/.0001RGB.' if c['admitted'] else 'Merged-colored native border explicitly excluded; SVG exact baseline fallback checked, glyphs retain all native bounds.')))
 bounded={i for i,t in enumerate(trace) if any(c['x']-.001<=t['x']<c['x']+c['width'] and c['y']<=t['y']<c['y']+c['height'] for c in cases)}
 assert bounded==used,('complete table glyph consumption',len(bounded),len(used),bounded-used,used-bounded)
 result=dict(bounds=dict(vectorPoints=.001,RGB=.0001,allGlyphX=.025,baseline=.121,paintSize=.002),svgSHA256=SHA(svg),pdfSHA256=SHA(pdf),referenceSHA256=SHA(reference),fontSHA256=SHA(fontdata),mode=a.mode,page=a.page,slide=a.slide,results=results,visibleGlyphs=sum(x['glyphCount'] for x in results),scope='Independent finite fill/stroke paint and scalar-origin/raw paint-size proof; source/subset outline identity is checked. Native trace boxes are never used as ink and no ink-dimension/raster parity is asserted.')
 Path(a.output).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'cases':len(cases),'glyphs':result['visibleGlyphs'],'output':a.output}))
if __name__=='__main__':main()
