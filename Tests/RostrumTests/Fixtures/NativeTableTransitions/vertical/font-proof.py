from pathlib import Path
from io import BytesIO
import hashlib,json
import fitz
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
R=Path(__file__).resolve().parent;root=next(p for p in R.parents if (p/'Package.swift').exists());source=root/'Tests/RostrumTests/Fixtures/NativeListMarkers/fonts/DejaVuSans.ttf';original=TTFont(source);doc=fitz.open(R/'powerpoint.pdf');refs=json.loads((R/'native-vectors.json').read_text());records=[];fonts={}
def outline(font,name):
 gs=font.getGlyphSet();pen=DecomposingRecordingPen(gs);gs[name].draw(pen);return pen.value
for page in doc:
 for xref,ext,kind,base,res,encoding,owner in page.get_fonts(full=True):
  if xref in fonts:continue
  name,extension,kind,data=doc.extract_font(xref);assert extension=='ttf';(R/f'pdf-font-{xref}.ttf').write_bytes(data);fonts[xref]=TTFont(BytesIO(data))
for case in refs['cases']:
 candidates=doc[case['page']].get_fonts(full=True);assert len(candidates)==1
 xref=candidates[0][0];font=fonts[xref];assert original['head'].unitsPerEm==font['head'].unitsPerEm
 for g in case['glyphs']:
  source_name=original.getBestCmap()[ord(g['text'])];pdf_name=font.getGlyphOrder()[g['glyph']]
  expected=outline(original,source_name);actual=outline(font,pdf_name);assert actual==expected,(case['id'],g['text'])
  records.append(dict(case=case['id'],text=g['text'],pdfGlyphID=g['glyph'],sourceGlyph=source_name,outlineSHA256=hashlib.sha256(repr(actual).encode()).hexdigest(),exact=True))
assert len(records)==124
(R/'font-proof.json').write_text(json.dumps(dict(sourceFontSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),pdfSHA256=refs['pdfSHA256'],fontSubsetSHA256={str(xref):hashlib.sha256((R/f'pdf-font-{xref}.ttf').read_bytes()).hexdigest() for xref in fonts},glyphs=records,scope='Exact decomposed source/subset glyph-outline identity and UPEM; no raster or transformed absolute ink claim'),indent=2)+'\n')
print('all124 native subset glyph outlines exactly match pinned DejaVu source')
