"""Capture independent native word anchors and numeric font metrics (no outlines)."""
from pathlib import Path
import hashlib,json
import fitz
from fontTools.ttLib import TTFont
root=Path(__file__).parent
fonts=[]
for name in ['Arial.ttf','Arial Bold.ttf']:
 path=Path('/System/Library/Fonts/Supplemental')/name
 f=TTFont(path); cmap=f.getBestCmap(); reverse={cmap[c]:c for c in range(32,127)}
 pairs=[]
 for table in f['kern'].kernTables:
  for (l,r),value in table.kernTable.items():
   if l in reverse and r in reverse: pairs.append([reverse[l]-31,reverse[r]-31,value])
 fonts.append(dict(file=name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),unitsPerEm=f['head'].unitsPerEm,
                   advances=[f['hmtx'].metrics[cmap[c]][0] for c in range(32,127)],kern=sorted(pairs)))
cases=[]; sources=[]
for version in [2,3,4,5]:
 pdf=root/f'powerpoint-v{version}.pdf'; doc=fitz.open(pdf)
 source=f'tab-layout-v{version}.pptx'
 sources.append(dict(pdf=pdf.name,pdfSHA256=hashlib.sha256(pdf.read_bytes()).hexdigest(),source=source,sourceSHA256=hashlib.sha256((root/source).read_bytes()).hexdigest()))
 for c in json.loads((root/f'cases-v{version}.json').read_text()):
  x,y=c['x'],c['y']; page=doc[c['page']]; pitch=12 if version==5 else 21.6
  words=[w for w in page.get_text('words',clip=fitz.INFINITE_RECT()) if x-1<=w[0] and (c['options'].get('nowrap') or w[0]<x+c['width']) and y<=w[1]<y+125 and w[4]!='•']
  lines=[]
  for w in words:
   if not lines or abs(lines[-1]['y']-(w[1]-y))>1:
    if lines:
     while w[1]-y-lines[-1]['y']>pitch*1.4: lines.append(dict(y=lines[-1]['y']+pitch,words=[]))
    lines.append(dict(y=w[1]-y,words=[]))
   lines[-1]['words'].append(dict(text=w[4],x=w[0]-x,end=w[2]-x))
  cases.append(dict(name=c['name'],source=source,page=c['page'],width=c['width'],height=c['height'],lines=lines))
output=dict(sources=sources,
 provenance='Microsoft PowerPoint for Mac 16.113.3, local Best for printing PDF export, 2026-10-03; source opened without repair and not saved.',
 fonts=fonts,cases=cases,tolerancePoints=.25)
(root/'native-geometry.json').write_text(json.dumps(output,indent=2)+'\n')
