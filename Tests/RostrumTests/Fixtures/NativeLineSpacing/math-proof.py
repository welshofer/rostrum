"""Candidate numerical model, independent of Rostrum; not an implementation."""
from pathlib import Path
import json, math
from fontTools.ttLib import TTFont
ROOT=Path(__file__).resolve().parent
REPO=next(p for p in ROOT.parents if (p/'Package.swift').exists())
font_paths={'DejaVu Sans':REPO/'Tests/RostrumTests/Fixtures/Typography/DejaVuSans.ttf','Arial':Path('/System/Library/Fonts/Supplemental/Arial.ttf')}
metrics={}
for name,path in font_paths.items():
    f=TTFont(path); o=f['OS/2']; metrics[name]={'unitsPerEm':f['head'].unitsPerEm,'winAscent':o.usWinAscent,'winDescent':o.usWinDescent}
def nearest(value):
    # All coordinates here are positive; epsilon prevents binary representation
    # of an exact half point from selecting the lower integer.
    return math.floor(value+0.5+1e-9)
def model(case,descent_model):
    m=metrics[case.get('font','DejaVu Sans')]; share=m['winAscent']/(m['winAscent']+m['winDescent'])
    compat=case.get('compatLnSpc','1')!='0'
    cursor=0; measured=0; trailing_gap=0; result=[]
    for para in case['paragraphs']:
        spacing=para.get('spacing'); lines=[]; current=[]
        default=para.get('default') or case.get('listSize',18)
        for node in para['nodes']:
            if node['kind']=='run':current.append(node)
            else:
                lines.append({'text':''.join(n['text'] for n in current),'size':max(n['size'] for n in current) if current else node.get('size') or default})
                current=[]
        if current or not para['nodes'] or para['nodes'][-1]['kind']=='break':
            lines.append({'text':''.join(n['text'] for n in current),'size':max(n['size'] for n in current) if current else para.get('end') or default})
        for node in lines:
            size=node['size']*case.get('fontScale',100)/100
            if case.get('fontScale',100)!=100:size=nearest(size)
            natural=size*1.2 if compat else size*(m['winAscent']+m['winDescent'])/m['unitsPerEm']
            ascent=natural*share
            explicit=spacing is not None and (('points' in spacing) or spacing['percent']!=100)
            if spacing and 'points' in spacing:
                advance=nearest(spacing['points']); shifted_ascent=advance*.75
            elif spacing and spacing['percent']!=100:
                advance=natural*(spacing['percent']-case.get('lineSpacingReduction',0))/100; shifted_ascent=advance*.75
            else:advance=natural;shifted_ascent=ascent
            baseline=nearest(cursor+shifted_ascent)
            descent=natural-ascent
            if explicit and descent_model=='rounded-normalized':descent=nearest(descent)
            if explicit and descent_model=='rounded-font-windows':descent=nearest(size*m['winDescent']/m['unitsPerEm'])
            if explicit and descent_model=='rounded-height-minus-ascent':descent=nearest(natural)-nearest(ascent)
            extent_baseline=cursor+shifted_ascent if explicit and descent_model in ['unrounded-spacing-extent','explicit-trailing-gap'] else baseline
            measured=max(measured,extent_baseline+descent)
            trailing_gap=max(0,advance-natural) if spacing and ('points' in spacing or (explicit and descent_model=='explicit-trailing-gap')) else 0
            result.append({'text':node['text'],'baseline':baseline,'advance':advance,'ascent':shifted_ascent,'descent':descent})
            cursor+=advance
    extent=max(cursor-trailing_gap,measured)
    anchor=case.get('anchor','t');offset=(case['height']-extent)/(2 if anchor=='ctr' else 1) if anchor in ['ctr','b'] else 0
    for line in result:line['baseline']+=offset
    return [line for line in result if line['text']],extent
out={'status':'research hypothesis, not source implementation','metrics':metrics,'cases':[],'models':{}}
for model_name in ['explicit-trailing-gap','unrounded-spacing-extent','unrounded-normalized','rounded-normalized','rounded-font-windows','rounded-height-minus-ascent']:
    records=[]
    for directory in [ROOT/'base',ROOT/'followup',ROOT/'compatibility',ROOT/'descent',ROOT/'scale',ROOT/'fractional',ROOT/'reduction',ROOT/'reduction-anchor',ROOT/'percentage-anchor',ROOT.parent/'NativeBreakMetrics']:
        cases=json.loads((directory/'cases.json').read_text());native=json.loads((directory/'native-metrics.json').read_text())['cases']
        assert len(cases)==len(native)
        for c,n in zip(cases,native):
            assert c['name']==n['name']
            predicted,extent=model(c,model_name);assert len(predicted)==len(n['markers'])
            errors=[a['baseline']-b['baseline'] for a,b in zip(predicted,n['markers'])]
            records.append({'name':c['name'],'predicted':predicted,'native':[m['baseline'] for m in n['markers']],'errors':errors,'extent':extent,'passes':all(abs(e)<.121 for e in errors)})
    out['models'][model_name]={'passed':sum(r['passes'] for r in records),'total':len(records),'failures':[r for r in records if not r['passes']]}
    if model_name=='explicit-trailing-gap':out['cases']=records
    print(model_name,out['models'][model_name]['passed'],'/',len(records),[r['name'] for r in records if not r['passes']])
(ROOT/'math-proof.json').write_text(json.dumps(out,indent=2)+'\n')
