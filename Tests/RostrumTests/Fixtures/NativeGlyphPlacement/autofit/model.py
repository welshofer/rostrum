"""Independent font-data model of paint, placement and normal baselines; no Rostrum calls."""
from pathlib import Path
from fontTools.ttLib import TTFont
import json,math
ROOT=Path(__file__).resolve().parent
REPO=next(p for p in ROOT.parents if (p/'Package.swift').exists())
font=TTFont(REPO/'Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf')
units=font['head'].unitsPerEm;cmap=font.getBestCmap();os2=font['OS/2'];share=os2.usWinAscent/(os2.usWinAscent+os2.usWinDescent)
def halfup(x):return math.floor(x+.5+1e-9)
def adv(c,size,tracking):return halfup(font['hmtx'][cmap[ord(c)]][0]*size/units*8)/8+tracking
out=[]
for folder in [ROOT.parent/'primary',ROOT]:
 cases=json.loads((folder/'cases.json').read_text());native=json.loads((folder/'native-paint-metrics.json').read_text())['cases']
 assert len(cases)==len(native)
 for case,capture in zip(cases,native):
  assert case['name']==capture['name']
  scale=case.get('fontScale',100)/100;scaled=scale!=1;tokens=[]
  for p in case['paragraphs']:
   for r in p['nodes']:
    effective=r['size']*scale;measure=halfup(effective) if scaled else effective;paint=halfup(effective) if scaled else round(effective)
    tokens.extend((c,measure,paint,r.get('tracking',0)*scale) for c in r['text'])
  predicted_lines=None
  if case.get('wrap'):
   assert all(c != ' ' for c,_,_,_ in tokens)
   predicted_lines=[];current='';width=0;capacity=math.floor(case['width']*8+1e-9)/8
   for c,size,paint,tracking in tokens:
    a=adv(c,size,tracking)
    if current and width+a>capacity+1e-9:
     predicted_lines.append(current);current='';width=0
    current+=c;width+=a
   if current:predicted_lines.append(current)
   assert predicted_lines==[line['visibleText'] for line in capture['lines']],(case['name'],predicted_lines)
  offset=0;cursor=0;xe=[];pe=[];be=[];se=[];ink=[]
  for line in capture['lines']:
   x=0;sizes=[]
   for g in line['characters']:
    while tokens[offset][0]==' ':
     c,size,paint,tracking=tokens[offset];offset+=1;x+=adv(c,size,tracking);sizes.append(size)
    c,size,paint,tracking=tokens[offset];offset+=1;assert c==g['text'];sizes.append(size)
    xe.append(g['x']-x);pe.extend(axis-paint for axis in g['rawPDFPaintScale'])
    # Ink dimensions test the actual matched outline at candidate paint scale;
    # position/baseline residuals are measured separately rather than conflated.
    b=g['sourceGlyphBounds'];native_ink=g['geometricInkBounds']
    ink.extend([(native_ink[2]-native_ink[0])-(b[2]-b[0])*paint/units,(native_ink[3]-native_ink[1])-(b[3]-b[1])*paint/units])
    x+=adv(c,size,tracking)
   height=max(sizes)*1.2;baseline=halfup(cursor+height*share)
   be.append(line['baseline']-baseline)
   snapped=round((case['y']+baseline)/.24)*.24-case['y'];se.append(line['baseline']-snapped)
   cursor+=height
  assert offset==len(tokens)
  out.append(dict(name=case['name'],group=folder.name,independentlyPredictedWrapLines=predicted_lines,maxOriginResidual=max(map(abs,xe)),maxPaintScaleResidual=max(map(abs,pe)),maxInkDimensionResidual=max(map(abs,ink)),maxWholePointBaselineResidual=max(map(abs,be)),maxPrintGridBaselineResidual=max(map(abs,se)),baselineResiduals=be))
record=dict(caseCount=len(out),independentlyPredictedWrapCaseCount=sum(c['independentlyPredictedWrapLines'] is not None for c in out),visibleScalarCount=sum(len(l['characters']) for folder in [ROOT.parent/'primary',ROOT] for c in json.loads((folder/'native-paint-metrics.json').read_text())['cases'] for l in c['lines']),fontAscentShare=share,model='Scale100: authored metric size and nearest-even paint; scale below100: nearest-half-up metric/paint. Normal baseline from1.2 metric size times Windows ascent share, cumulative line advance, then whole point. Print-grid comparison is extraction context only, not proposed SVG snapping.',maxima={k:max(c[k] for c in out) for k in out[0] if k.startswith('max')},cases=out)
(ROOT/'model-comparison.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({k:v for k,v in record.items() if k!='cases'},indent=2))
