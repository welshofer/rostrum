"""Capture numeric advance metrics and independently exported PDF word geometry.
No font program/outlines are redistributed. Requires fonttools and PyMuPDF.
"""
from pathlib import Path
import hashlib, json
import fitz
from fontTools.ttLib import TTFont
root=Path(__file__).parent
fonts=[]
for name in ['Arial.ttf','Arial Bold.ttf']:
    path=Path('/System/Library/Fonts/Supplemental')/name
    f=TTFont(path); cmap=f.getBestCmap()
    fonts.append(dict(file=name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                      unitsPerEm=f['head'].unitsPerEm,
                      advances=[f['hmtx'].metrics[cmap[n]][0] for n in range(32,127)]))
pdf=root/'paragraph-justification-v2.pdf'
page=fitz.open(pdf)[0]
cases=[]
for name,x,y in [('regular',30,42),('mixed',380,42),('hard-break',30,167),('bullet',380,292)]:
    words=[w for w in page.get_text('words') if abs(w[1]-(y+1.71))<1 and x-1<=w[0]<x+300]
    cases.append(dict(name=name,words=[dict(text=w[4],x=w[0]-x,end=w[2]-x) for w in words if w[4] != "•"]))
output=dict(pdf=pdf.name,pdfSHA256=hashlib.sha256(pdf.read_bytes()).hexdigest(),fonts=fonts,cases=cases,tolerancePoints=0.25)
(root/'native-word-geometry.json').write_text(json.dumps(output,indent=2)+'\n')
