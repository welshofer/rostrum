"""Capture native wrap decisions, PDF face names and portable numeric metrics."""
from pathlib import Path
import hashlib,json,sys
import fitz
from fontTools.ttLib import TTFont
root=Path(__file__).parent
suffix='-coordinates' if '--coordinates' in sys.argv else '-scale' if '--scale' in sys.argv else '-final' if '--final' in sys.argv else '-followup' if '--followup' in sys.argv else ''
manifest=json.loads((root/f'input-manifest{suffix}.json').read_text())
faces=[]
for entry in manifest['fonts']:
 f=TTFont(entry['path']);cmap=f.getBestCmap();reverse={cmap[c]:c for c in range(32,127)}
 pairs={}
 if 'kern' in f:
  for table in f['kern'].kernTables:
   for (a,b),v in table.kernTable.items():
    if a in reverse and b in reverse:pairs[(reverse[a]-31,reverse[b]-31)]=v
 faces.append(dict(name=entry['name'],sha256=entry['sha256'],unitsPerEm=f['head'].unitsPerEm,
                   advances=[f['hmtx'].metrics[cmap[c]][0] for c in range(32,127)],
                   kern=[[a,b,v] for (a,b),v in sorted(pairs.items())]))
pdf=root/f'powerpoint{suffix}.pdf'; doc=fitz.open(pdf); captures=[]
for case in json.loads((root/f'cases{suffix}.json').read_text()):
 x,y=case['x'],case['y'];groups={}
 for block in doc[case['page']].get_text('rawdict',clip=fitz.INFINITE_RECT())['blocks']:
  for line in block.get('lines',[]):
   for span in line['spans']:
    for char in span['chars']:
     cx,cy=char['origin']
     if x-.2<=cx<x+330 and y<=cy<y+case['height']:
      key=round(cy,2)
      groups.setdefault(key,[]).append(dict(text=char['c'],x=cx-x,end=char['bbox'][2]-x,font=span['font'],size=span['size']))
 lines=[]
 for baseline,chars in sorted(groups.items()):
  chars.sort(key=lambda c:c['x'])
  lines.append(dict(text=''.join(c['text'] for c in chars),baseline=baseline-y,characters=chars))
 captures.append(dict(name=case['name'],lines=lines))
source='line-break'+suffix+'.pptx' if suffix else 'line-break-boundaries.pptx'
out=dict(source=source,sourceSHA256=hashlib.sha256((root/source).read_bytes()).hexdigest(),
 pdf=pdf.name,pdfSHA256=hashlib.sha256(pdf.read_bytes()).hexdigest(),
 provenance='Independent native Microsoft PowerPoint export; application version and acceptance supplied by root capture record.',
 faces=faces,cases=captures)
(root/f'native-geometry{suffix}.json').write_text(json.dumps(out,indent=2)+'\n')
for case,native in zip(json.loads((root/f'cases{suffix}.json').read_text()),captures):
 print(case['name'],round(case['width'],5),repr([l['text'] for l in native['lines']]))
