"""Extract native marker origins and actual PDF glyph-outline identities."""
from pathlib import Path
from io import BytesIO
import hashlib,json
import fitz
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
ROOT=Path(__file__).resolve().parent
FONT=ROOT.parent.parent/'Typography/DejaVuSans.ttf'
def signature(glyphs,name):
    pen=RecordingPen();glyphs[name].draw(pen)
    return hashlib.sha256(repr(pen.value).encode()).hexdigest()
source=TTFont(FONT);source_glyphs=source.getGlyphSet();cmap=source.getBestCmap()
source_ids={char:signature(source_glyphs,cmap[ord(char)]) for char in 'ABZ'}
manifest=json.loads((ROOT/'manifest.json').read_text());pdf=ROOT/'powerpoint.pdf';doc=fitz.open(pdf)
fonts={}
for page in doc:
    for xref,ext,kind,name,*rest in page.get_fonts():
        key=name.split('+')[-1]
        if key in fonts:continue
        try:
            data=doc.extract_font(xref)[3];font=TTFont(BytesIO(data))
            fonts[key]=dict(font=font,glyphs=font.getGlyphSet(),order=font.getGlyphOrder(),sha256=hashlib.sha256(data).hexdigest())
        except Exception:pass
results=[]
for case in json.loads((ROOT/'cases.json').read_text()):
    authored=[dict(text=t['text'],size=t['size'],effectiveSize=t['size']*case.get('fontScale',100)/100,paragraph=i) for i,p in enumerate(case['paragraphs']) for t in p['nodes'] if t['kind']=='run']
    markers=[]
    for span in doc[case['page']].get_texttrace():
        for scalar,glyph,origin,bounds in span['chars']:
            x,y=origin
            if not(case['x']-.1<=x<case['x']+case['width'] and case['y']<=y<case['y']+case['height']):continue
            native=fonts.get(span['font']);assert native is not None,(case['name'],span['font'])
            outline=signature(native['glyphs'],native['order'][glyph]);text=chr(scalar)
            assert outline==source_ids.get(text),(case['name'],text,'source glyph identity mismatch')
            markers.append(dict(text=text,x=x-case['x'],baseline=y-case['y'],pdfFont=span['font'],pdfSize=span['size'],glyphID=glyph,outlineSHA256=outline,sourceGlyphMatches=True,paintType=span['type']))
    markers.sort(key=lambda c:(c['baseline'],c['x']))
    assert len(markers)==len(authored),(case['name'],'extra/missing native markers',markers,authored)
    assert ''.join(m['text'] for m in markers)==''.join(a['text'] for a in authored),case['name']
    for actual,expected in zip(markers,authored):actual['authored']=expected
    results.append(dict(name=case['name'],markers=markers))
    print(case['name'],[(m['text'],round(m['baseline'],4)) for m in markers])
output=dict(source=manifest['source'],sourceSHA256=manifest['sourceSHA256'],pdf=pdf.name,pdfSHA256=hashlib.sha256(pdf.read_bytes()).hexdigest(),fontSHA256=manifest['fontSHA256'],subsets={k:v['sha256'] for k,v in fonts.items()},cases=results)
(ROOT/'native-metrics.json').write_text(json.dumps(output,indent=2)+'\n')
