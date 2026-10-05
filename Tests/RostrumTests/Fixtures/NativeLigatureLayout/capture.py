"""Capture native PDF glyph origins/identity, independently of Rostrum output."""
from pathlib import Path
from io import BytesIO
import hashlib,json
import fitz
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen

root=Path(__file__).parent
manifest=json.loads((root/'input-manifest.json').read_text())
source=TTFont(root.parent/'Typography/DejaVuSans.ttf');source_glyphs=source.getGlyphSet();cmap=source.getBestCmap()
def signature(glyphset,name):
 pen=RecordingPen();glyphset[name].draw(pen)
 return hashlib.sha256(repr(pen.value).encode()).hexdigest()
source_signatures={c:signature(source_glyphs,n) for c,n in cmap.items() if 32<=c<127}
pdf=root/'powerpoint-regular-table.pdf';doc=fitz.open(pdf)
fonts={}
for page in doc:
 for xref,ext,kind,name,*rest in page.get_fonts():
  short=name.split('+')[-1]
  if short in fonts:continue
  try:
   data=doc.extract_font(xref)[3];font=TTFont(BytesIO(data));glyphs=font.getGlyphSet()
   fonts[short]=dict(font=font,glyphs=glyphs,order=font.getGlyphOrder(),sha256=hashlib.sha256(data).hexdigest())
  except Exception:pass
captures=[]
seen_names=set()
for case in json.loads((root/'cases.json').read_text()):
 assert case['name'] not in seen_names
 seen_names.add(case['name'])
 authored=[]
 for run_index,run in enumerate(case['runs']):
  for scalar in run['text']:
   if scalar!='\n':authored.append(dict(text=scalar,runIndex=run_index,pointSize=run['size']*case.get('fontScale',100000)/100000,tracking=(run.get('tracking') or 0)*case.get('fontScale',100000)/100000))
 x,y=case['x'],case['y'];lines={}
 for span in doc[case['page']].get_texttrace():
  for scalar,glyph,origin,bounds in span['chars']:
   cx,cy=origin
   if not (x-.1<=cx<x+325 and y<=cy<y+case['height']):continue
   native=fonts.get(span['font']);identity=None
   if native and 0<=glyph<len(native['order']):
    name=native['order'][glyph]
    identity=dict(outlineSHA256=signature(native['glyphs'],name),advance=native['font']['hmtx'].metrics[name][0])
    identity['matchesSourceGlyph']=identity['outlineSHA256']==source_signatures.get(scalar)
   lines.setdefault(round(cy-y,3),[]).append(dict(text=chr(scalar),glyphID=glyph,x=cx-x,font=span['font'],pdfPointSize=span['size'],identity=identity))
 result=[];offset=0
 for baseline,characters in sorted(lines.items()):
  characters.sort(key=lambda c:c['x'])
  for character in characters:
   assert offset<len(authored),(case['name'],'extra native glyph',character)
   original=authored[offset];offset+=1
   assert character['text']==original['text'] or (original['text']=='\t' and character['text']==' '),(case['name'],character,original)
   character['authored']=original
  result.append(dict(text=''.join(c['authored']['text'] for c in characters if c['authored']['text']!='\t'),baseline=baseline,characters=characters))
 assert offset==len(authored),(case['name'],offset,len(authored))
 captures.append(dict(name=case['name'],lines=result))
 print(case['name'],case['width'],[l['text'] for l in result])
output=dict(source=manifest['source'],sourceSHA256=manifest['sourceSHA256'],pdf=pdf.name,pdfSHA256=hashlib.sha256(pdf.read_bytes()).hexdigest(),fontSHA256=manifest['fontSHA256'],fontSubsets={k:v['sha256'] for k,v in fonts.items()},cases=captures)
(root/'native-geometry.json').write_text(json.dumps(output,indent=2)+'\n')
