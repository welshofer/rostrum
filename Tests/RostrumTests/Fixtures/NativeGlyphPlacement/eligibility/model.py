"""Independent candidate arithmetic; native captures remain unchanged."""
from pathlib import Path
from fontTools.ttLib import TTFont
import json,math,subprocess
ROOT=Path(__file__).resolve().parent
cases=json.loads((ROOT/'cases.json').read_text());native=json.loads((ROOT/'native-paint-metrics.json').read_text())['cases'];manifest=json.loads((ROOT/'manifest.json').read_text())
def nearest(v):return math.floor(v+.5+1e-9)
rows=[]
for case,capture in zip(cases,native):
 assert case['name']==capture['name']
 face=manifest['faces'][case.get('face','regular')];path=ROOT/face['file'];font=TTFont(path);units=font['head'].unitsPerEm;cmap=font.getBestCmap();os=font['OS/2'];share=os.usWinAscent/(os.usWinAscent+os.usWinDescent)
 # Table observation is evaluated as a separate candidate, not hidden in the source size.
 scale=1 if case.get('table') else case.get('fontScale',100)/100
 tokens=[];kerning_choices=[]
 for para in case['paragraphs']:
  for run in para['nodes']:
   effective=run['size']*scale;size=max(1,nearest(effective)) if scale!=1 else effective;paint=max(1,nearest(effective)) if scale!=1 else round(effective)
   # The local omitted case inherits generated defRPr kern=0.
   threshold=run.get('kern',0);threshold=0 if threshold is None else threshold
   kern=threshold>0 and size>=threshold
   kerning_choices.append(dict(threshold=threshold,measurementSize=size,enabled=kern))
   text=run['text'];clean=text.replace('\t','')
   shaped=json.loads(subprocess.check_output(['hb-shape',str(path),clean,'--no-glyph-names','--output-format=json',f'--features=liga=0,kern={int(kern)}'],text=True))
   assert len(shaped)==len(clean)
   iterator=iter(shaped)
   for char in text:
    if char=='\t':tokens.append(dict(char=char,size=size,paint=paint,advance=0));continue
    glyph=next(iterator);raw=font['hmtx'][cmap[ord(char)]][0]
    width=nearest(raw*size/units*8)/8+(glyph['ax']-raw)*size/units
    tokens.append(dict(char=char,size=size,paint=paint,advance=width))
 # Greedy wrapping with spaces as break opportunities, otherwise scalar breaks.
 predicted=[];current=[];width=0;capacity=math.floor(case['width']*8+1e-9)/8
 for token in tokens:
  if case.get('wrap') and current and width+token['advance']>capacity+1e-9:
   spaces=[i for i,t in enumerate(current) if t['char']==' ']
   if spaces:
    i=spaces[-1]+1;predicted.append(current[:i]);current=current[i:];width=sum(t['advance'] for t in current)
   else:predicted.append(current);current=[];width=0
  current.append(token);width+=token['advance']
 if current:predicted.append(current)
 predicted_text=[''.join(t['char'] for t in line if t['char'] not in [' ','\t']) for line in predicted]
 actual_text=[line['visibleText'] for line in capture['lines']]
 assert predicted_text==actual_text,(case['name'],predicted_text,actual_text)
 xe=[];be=[];pe=[];ie=[];cursor=0
 for li,(line,actual) in enumerate(zip(predicted,capture['lines'])):
  trimmed=list(line)
  while trimmed and trimmed[-1]['char']==' ':trimmed.pop()
  stretch=0
  if case.get('alignment')=='just' and li<len(predicted)-1:
   spaces=sum(t['char']==' ' for t in trimmed);stretch=(capacity-sum(t['advance'] for t in trimmed))/spaces
  x=0;gi=0
  for ti,t in enumerate(line):
   if t['char']=='\t':
    after=line[ti+1:];before_decimal=[]
    for item in after:
     if item['char']=='.':break
     before_decimal.append(item)
    x=case['tab']['position']-sum(item['advance'] for item in before_decimal);continue
   if t['char']!=' ':
    g=actual['characters'][gi];gi+=1;assert g['text']==t['char'];xe.append(g['x']-x);pe.extend(a-t['paint'] for a in g['rawPDFPaintScale'])
    b=g['sourceGlyphBounds'];ink=g['geometricInkBounds'];ie.extend([(ink[2]-ink[0])-(b[2]-b[0])*t['paint']/units,(ink[3]-ink[1])-(b[3]-b[1])*t['paint']/units])
   x+=t['advance']+(stretch if t['char']==' ' else 0)
  assert gi==len(actual['characters'])
  height=max(t['size'] for t in line)*1.2;baseline=nearest(cursor+height*share);be.append(actual['baseline']-baseline);cursor+=height
 rows.append(dict(name=case['name'],predictedLines=predicted_text,kerning=kerning_choices,maxOriginResidual=max(map(abs,xe)),maxBaselineResidual=max(map(abs,be)),maxPaintResidual=max(map(abs,pe)),maxInkDimensionResidual=max(map(abs,ie))))
record=dict(caseCount=len(rows),visibleScalarCount=sum(c['consumedVisibleScalars'] for c in native),maxima={k:max(c[k] for c in rows) for k in rows[0] if k.startswith('max')},cases=rows,qualifications=['Local omitted kern inherits zero; no truly omitted default inference.','Table stored scale ignored by this candidate because native paints and measures20 instead of13.5.','Tiny candidate min1point only tested at effective0.49/0.50/0.51; no universal minimum claimed.'])
(ROOT/'model-comparison.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record,indent=2))
