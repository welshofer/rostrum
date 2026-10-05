"""Compare frozen pre-fix layout with independent native observations."""
from pathlib import Path
import json,math
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
R=Path(__file__).resolve().parent
manifest=json.loads((R/'manifest.json').read_text())
fonts={key:TTFont(R/face['file']) for key,face in manifest['faces'].items()}
native=json.loads((R/'native-marker-metrics.json').read_text())['cases']
base=json.loads((R/'baseline-layout.json').read_text())
inputs=json.loads((R/'cases.json').read_text())
assert len(native)==len(base)==len(inputs)==6
results=[]
for case,actual,expected in zip(inputs,base,native):
 assert case['name']==actual['name']==expected['name']
 predicted={'marker':[],'body':[]};body_lines=[]
 for line_index,line in enumerate(actual['lines']):
  body_text=''
  for span_index,span in enumerate(line['spans']):
   role='marker' if line_index==0 and span_index==0 else 'body'
   face=next(key for key,f in manifest['faces'].items() if f['family']==span['family'] and f['bold']==span['bold'] and f['italic']==span['italic'])
   font=fonts[face];cmap=font.getBestCmap();glyphs=font.getGlyphSet();units=font['head'].unitsPerEm
   x=span['x'];positions=span.get('scalarPositions')
   if positions is not None:assert len(positions)==len(span['text'])
   for index,char in enumerate(span['text']):
    if not char.isspace():
     pen=BoundsPen(glyphs);glyphs[cmap[ord(char)]].draw(pen);b=pen.bounds
     predicted[role].append(dict(text=char,x=positions[index] if positions is not None else x,baseline=line['baseline'],paint=span['paintSize'],face=face,inkWidth=(b[2]-b[0])*span['paintSize']/units,inkHeight=(b[3]-b[1])*span['paintSize']/units))
    if role=='body':body_text+=char
    x+=font['hmtx'][cmap[ord(char)]][0]*span['fontSize']/units
  body_lines.append(''.join(c for c in body_text if not c.isspace()))
 row=dict(name=case['name'],baselineFits=actual['fits'],baselineContentHeight=actual['contentHeight'],nativeBodyLines=[l['visibleText'] for l in expected['bodyLines']],libraryBodyLines=body_lines,diagnostics=actual['diagnostics'])
 row['sameBodyWrapping']=row['nativeBodyLines']==body_lines
 for role,key in [('marker','markerGlyphs'),('body','bodyGlyphs')]:
  lhs=predicted[role];rhs=expected[key]
  if role=='marker' and expected['explicitlyOmittedMarkers']:
   assert len(lhs)==len(expected['explicitlyOmittedMarkers']) and not rhs
   row[role]=dict(libraryCount=len(lhs),nativeCount=0,nativeOmission=expected['explicitlyOmittedMarkers'])
   continue
  assert len(lhs)==len(rhs)
  assert ''.join(g['text'] for g in lhs)==''.join(g['text'] for g in rhs)
  errors=[]
  for a,b in zip(lhs,rhs):
   bounds=b['geometricInkBounds']
   errors.append(dict(text=a['text'],x=a['x']-b['x'],baseline=a['baseline']-b['baseline'],paint=a['paint']-b['rawPDFPaintScale'][0],inkWidth=a['inkWidth']-(bounds[2]-bounds[0]),inkHeight=a['inkHeight']-(bounds[3]-bounds[1]),libraryFace=a['face'],nativeMatchingFaces=b['matchingSourceFaces'],faceCompatible=a['face'] in b['matchingSourceFaces']))
  row[role]=dict(count=len(lhs),nativePaint=sorted(set(g['rawPDFPaintScale'][0] for g in rhs)),libraryPaint=sorted(set(g['paint'] for g in lhs)),maxAbs={name:max(abs(g[name]) for g in errors) for name in ['x','baseline','paint','inkWidth','inkHeight']},glyphs=errors)
 results.append(row)
 print(row['name'],'wrap',row['sameBodyWrapping'],'marker',row['marker'].get('nativePaint','omitted'),'versus',row['marker'].get('libraryPaint'),'markerErrors',row['marker'].get('maxAbs'),'bodyErrors',row['body']['maxAbs'])
(R/'baseline-native-comparison.json').write_text(json.dumps(dict(baselineCommit='83a1c72be443b51f05070f1b3858c3665aa71efb',cases=results),indent=2)+'\n')
