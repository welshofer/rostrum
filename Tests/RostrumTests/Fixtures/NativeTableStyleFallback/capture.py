"""Raw native research capture. No cell mirroring or join model is assumed.
Usage: python3 capture.py <accepted PDF SHA256>
Requires the GUI owner's capture-receipt.json and unchanged source.
"""
from pathlib import Path
import sys,json,hashlib
import fitz
from pypdf import PdfReader
from pypdf.generic import ContentStream
ROOT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'manifest.json').read_text());cases=json.loads((ROOT/'cases.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(ROOT/manifest['source'])==manifest['sourceSHA256']
assert (ROOT/'capture-receipt.json').exists()
pdf=ROOT/'powerpoint.pdf';assert sha(pdf)==sys.argv[1]
doc=fitz.open(pdf);reader=PdfReader(pdf);assert len(doc)==len(reader.pages)==manifest['slides']
def convert(v):
 if isinstance(v,(fitz.Point,fitz.Rect)):return list(v)
 if isinstance(v,(list,tuple)):return [convert(x) for x in v]
 if isinstance(v,dict):return {k:convert(x) for k,x in v.items()}
 return v
pages=[];records=[]
for pageIndex,page in enumerate(doc):
 assert page.rect==fitz.Rect(0,0,720,720)
 (ROOT/f'page-{pageIndex+1}-content.txt').write_bytes(page.read_contents())
 paths=page.get_drawings();traces=page.get_texttrace()
 operators=[dict(operator=op.decode('latin1'),operands=[str(v) for v in values]) for values,op in ContentStream(reader.pages[pageIndex].get_contents(),reader).operations]
 pages.append(dict(page=pageIndex,paths=convert(paths),operators=operators))
 for case in [c for c in cases if c['page']==pageIndex]:
  frame=fitz.Rect(case['x'],case['y'],case['x']+case['width'],case['y']+case['height']);expanded=frame+(-6,-6,6,6)
  observed=[]
  for index,path in enumerate(paths):
   rect=path['rect']
   overlaps=rect.x1>=expanded.x0 and rect.x0<=expanded.x1 and rect.y1>=expanded.y0 and rect.y0<=expanded.y1
   if overlaps and rect.width<300 and rect.height<300:observed.append(dict(index=index,**convert(path)))
  glyphs=[]
  for span in traces:
   for scalar,glyph,origin,bounds in span['chars']:
    if expanded.contains(fitz.Point(origin)):glyphs.append(dict(text=chr(scalar),glyph=glyph,origin=list(origin),bounds=list(bounds),font=span['font'],size=span['size'],color=span['color'],type=span['type'],seqno=span['seqno']))
  expected=''.join(c['text'] for c in case['cells'])
  assert ''.join(g['text'] for g in glyphs)==expected,(case['id'],expected,glyphs)
  records.append(dict(id=case['id'],page=pageIndex,frame=list(frame),paths=observed,glyphs=glyphs))
assert len(records)==manifest['cases'] and sum(len(c['glyphs']) for c in records)==manifest['expectedVisibleGlyphs']
record=dict(sourceSHA256=manifest['sourceSHA256'],pdfSHA256=sha(pdf),pages=pages,cases=records,limitations='Raw paint sequence, vector operators and trace completeness only. No native cell ownership/mirror model or source-outline ink guarantee is inferred.')
(ROOT/'native-vectors.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(dict(cases=len(records),glyphs=sum(len(c['glyphs']) for c in records),pdfSHA256=sha(pdf)),indent=2))

# Mechanical compact projection retains native fill/stroke order and raw values.
projection=[]
for case,observed in zip(cases,records):
 assert case['id']==observed['id']
 lines=[];fills=[];saw_stroke=False
 for path in observed['paths']:
  assert len(path['items'])==1
  item=path['items'][0]
  if path['type']=='f':
   assert item[0]=='re' and not saw_stroke
   fills.append(dict(bounds=item[1],color=path['fill'],opacity=path['fill_opacity']))
  else:
   assert path['type']=='s' and item[0]=='l';saw_stroke=True
   lines.append(dict(points=item[1]+item[2],color=path['color'],opacity=path['stroke_opacity'],width=path['width'],sequence=path['seqno']))
 projection.append(dict(id=case['id'],page=case['page'],x=case['x'],y=case['y'],width=case['width'],height=case['height'],fills=fills,lines=lines,glyphs=observed['glyphs']))
(ROOT/'paint-reference.json').write_text(json.dumps(projection,indent=2)+'\n')
