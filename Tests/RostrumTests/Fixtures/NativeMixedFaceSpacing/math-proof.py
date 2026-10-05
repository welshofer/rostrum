"""Source-font metric equivalence model, independently checked against native PDF.

This reuses the earlier independently calibrated single-face exact-spacing model;
it does not execute or modify Rostrum's layout implementation.
"""
from pathlib import Path
import json,math
from fontTools.ttLib import TTFont
R=Path(__file__).resolve().parent
nearest=lambda x:math.floor(x+.5+1e-9)
def predict(case,faces,rounded_extent=False):
 heights=[];signatures=[]
 for para in case['paragraphs']:
  for run in para['nodes']:
   if run['kind']!='run':continue
   f=faces[run.get('face',case.get('face','regular'))];o=f['OS/2'];u=f['head'].unitsPerEm
   signatures.append((o.usWinAscent/(o.usWinAscent+o.usWinDescent),(o.usWinAscent+o.usWinDescent)/u))
   size=run['size']*case.get('fontScale',100)/100
   if case.get('fontScale',100)!=100:size=nearest(size)
   heights.append(size*1.2)
 assert len(set(signatures))==1
 height=max(heights);share=signatures[0][0];descent=height*(1-share)
 pitch=nearest(case['paragraphs'][0]['spacing']['points']);ascent=pitch*.75
 baselines=[nearest(ascent),nearest(pitch+ascent)]
 extent=max(2*pitch-max(0,pitch-height),(baselines[-1] if rounded_extent else pitch+ascent)+descent)
 anchor=case.get('anchor','t');offset=(case['height']-extent)/(2 if anchor=='ctr' else 1) if anchor in ['ctr','b'] else 0
 return dict(baselines=[v+offset for v in baselines],extent=extent,naturalHeight=height,descent=descent,verticalSignature=list(signatures[0]))
rows=[]
for directory in [R/'base',R/'anchors']:
 manifest=json.loads((directory/'manifest.json').read_text());faces={k:TTFont(directory/v['file']) for k,v in manifest['faces'].items()}
 cases=json.loads((directory/'cases.json').read_text());native=json.loads((directory/'native-mixed-face-metrics.json').read_text())['cases'];base=json.loads((directory/'baseline-layout.json').read_text())
 assert len(cases)==len(native)==len(base)
 for case,actual,old in zip(cases,native,base):
  assert case['name']==actual['name']==old['name'];model=predict(case,faces);other=predict(case,faces,True);n=[l['baseline'] for l in actual['lines']]
  errors=[x-y for x,y in zip(model['baselines'],n)];old_errors=[l['baseline']-y for l,y in zip(old['lines'],n)]
  row=dict(name=case['name'],native=n,library=[l['baseline'] for l in old['lines']],libraryContentHeight=old['contentHeight'],model=model,errors=errors,passes=all(abs(e)<.121 for e in errors),oldErrors=old_errors,roundedExtentErrors=[x-y for x,y in zip(other['baselines'],n)])
  rows.append(row);print(case['name'],'native',n,'model',model['baselines'],'extent',round(model['extent'],6),'maxError',round(max(map(abs,errors)),6),'oldMax',round(max(map(abs,old_errors)),6))
record=dict(status='independent proposed metric-equivalence model; no production changes',cases=rows,passed=sum(r['passes'] for r in rows),total=len(rows),maxResidual=max(abs(v) for r in rows for v in r['errors']),roundedExtentRejectedCases=[r['name'] for r in rows if max(map(abs,r['roundedExtentErrors']))>=.121])
(R/'math-proof.json').write_text(json.dumps(record,indent=2)+'\n')
assert record['passed']==record['total']==12
