"""Retain native vector operators and cell fill/stroke observations, without assumed defaults.
Usage: python3 capture.py builtin|custom
A native PDF and a capture receipt must first be supplied by the GUI owner.
"""
from pathlib import Path
import sys,json,hashlib
import fitz
from pypdf import PdfReader
from pypdf.generic import ContentStream
ROOT=Path(__file__).resolve().parent/sys.argv[1]
manifest=json.loads((ROOT/'manifest.json').read_text());cases=json.loads((ROOT/'cases.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(ROOT/manifest['source'])==manifest['sourceSHA256']
assert (ROOT/'capture-receipt.json').exists(), 'Native capture receipt required'
pdf=ROOT/'powerpoint.pdf';assert sha(pdf)==manifest['pdfSHA256'];doc=fitz.open(pdf);reader=PdfReader(pdf);assert len(doc)==len(reader.pages)==1
page=doc[0];assert page.rect==fitz.Rect(0,0,720,720)
(ROOT/'page-1-content.txt').write_bytes(page.read_contents())
def convert(value):
 if isinstance(value,(fitz.Point,fitz.Rect)):return list(value)
 if isinstance(value,(list,tuple)):return [convert(x) for x in value]
 if isinstance(value,dict):return {k:convert(v) for k,v in value.items()}
 return value
# Preserve all path fields, including raw command vertices, opacity and paint order.
paths=page.get_drawings();records=[]
for case in cases:
 frame=fitz.Rect(case['x'],case['y'],case['x']+case['width'],case['y']+case['height']);expanded=frame+(-3,-3,3,3)
 observed=[]
 for index,path in enumerate(paths):
  rect=path['rect']
  # Zero-width line rectangles are not valid rectangle intersections. Test
  # coordinate overlap explicitly, retaining edges that extend at corners.
  overlaps=rect.x1>=expanded.x0 and rect.x0<=expanded.x1 and rect.y1>=expanded.y0 and rect.y0<=expanded.y1
  if overlaps and rect.width<300 and rect.height<300:
   observed.append(dict(index=index,**convert(path)))
 glyphs=[]
 for span in page.get_texttrace():
  for scalar,glyph,origin,bounds in span['chars']:
   if expanded.contains(fitz.Point(origin)):
    glyphs.append(dict(text=chr(scalar),glyph=glyph,origin=list(origin),bounds=list(bounds),font=span['font'],size=span['size'],color=span['color'],type=span['type'],seqno=span['seqno']))
 assert ''.join(g['text'] for g in glyphs)==case['text'],(case['id'],glyphs)
 records.append(dict(id=case['id'],frame=list(frame),paths=observed,glyphs=glyphs))
operators=[]
for operands,operator in ContentStream(reader.pages[0].get_contents(),reader).operations:
 operators.append(dict(operator=operator.decode('latin1'),operands=[str(v) for v in operands]))
record=dict(source=manifest['source'],sourceSHA256=manifest['sourceSHA256'],pdfSHA256=sha(pdf),pageCount=1,cases=records,allPaths=convert(paths),rawOperators=operators,limitations='Vector extraction observations only. No expected fill/style inferred; glyph trace is a completeness/position control, not a new font-outline identity proof.')
(ROOT/'native-vectors.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(dict(cases=len(records),glyphs=sum(len(c['glyphs']) for c in records),pdfSHA256=record['pdfSHA256'],paths=[dict(id=c['id'],count=len(c['paths'])) for c in records]),indent=2))

# Compact test projection derives only from the retained native operators.
paints=[]
for case,native in zip(cases,records):
 p=dict(id=native['id'],x=case['x'],y=case['y'],width=case['width'],height=case['height'],fills=[],lines=[],glyphs=native['glyphs'])
 for path in native['paths']:
  assert len(path['items'])==1
  item=path['items'][0]
  if path['type']=='f':
   assert item[0]=='re';p['fills'].append(dict(bounds=item[1],color=path['fill'],opacity=path['fill_opacity']))
  else:
   assert path['type']=='s' and item[0]=='l';p['lines'].append(dict(points=item[1]+item[2],color=path['color'],opacity=path['stroke_opacity'],width=path['width']))
 paints.append(p)
(ROOT/'paint-reference.json').write_text(json.dumps(paints,indent=2)+'\n')
