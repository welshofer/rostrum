#!/usr/bin/env python3
"""Run release benchmarks in fresh processes; preserve samples and corpus hashes.

Example: python3 Tools/rostrum-bench/run.py --output /tmp/baseline.json
No speed promise is inferred from a single run. Compare same-machine reports.
"""
import argparse, hashlib, json, os, platform, statistics, subprocess, sys, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--runs',type=int,default=5)
p.add_argument('--warmups',type=int,default=1)
p.add_argument('--quick',action='store_true')
p.add_argument('--binary',type=Path)
a = p.parse_args()
assert a.runs >= 2 and a.warmups >= 0
if not a.binary:
    subprocess.run(['swift','build','-c','release','--product','rostrum-bench'],cwd=ROOT,check=True,stdout=sys.stderr)
    bindir = subprocess.check_output(['swift','build','-c','release','--show-bin-path'],cwd=ROOT,text=True).strip()
    a.binary = Path(bindir)/'rostrum-bench'
scenarios = ['slides-10','table-20x10','images-repeated','images-unique']
if not a.quick: scenarios += ['slides-100','slides-1000','table-100x20','table-200x50']
corpus = sorted((ROOT/'Tests/RostrumTests/Fixtures/RealDecks').glob('*.pptx'))
if not a.quick: scenarios += ['file:'+str(f) for f in corpus]
report = {'schema':1,'compiler':subprocess.check_output(['swift','--version'],text=True).strip(),
          'platform':platform.platform(),'machine':platform.machine(),'processor':platform.processor(),
          'revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
          'font':os.environ.get('ROSTRUM_BENCH_FONT'),
          'fontSHA256':hashlib.sha256(Path(os.environ['ROSTRUM_BENCH_FONT']).read_bytes()).hexdigest() if os.environ.get('ROSTRUM_BENCH_FONT') else None,
          'warmups':a.warmups,'runs':a.runs,
          'corpus':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in corpus},'scenarios':{}}
# wait4 returns per-child peak RSS; subprocess children aggregate RSS would hide
# smaller cases behind the maximum of earlier scenarios.
for scenario in scenarios:
    samples=[]
    with tempfile.TemporaryDirectory(prefix='rostrum-bench-') as temp:
        output = Path(temp)/'output.pptx'
        env=dict(os.environ,ROSTRUM_BENCH_OUTPUT=str(output))
        for iteration in range(a.warmups+a.runs):
            args=[str(a.binary)]+(['file',scenario[5:]] if scenario.startswith('file:') else [scenario])
            with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
                proc=subprocess.Popen(args,stdout=stdout,stderr=stderr,env=env,cwd=ROOT)
                _,status,usage=os.wait4(proc.pid,0)
                proc.returncode=os.waitstatus_to_exitcode(status)
                stdout.seek(0); stderr.seek(0)
                if proc.returncode: raise RuntimeError(stderr.read().decode())
                sample=json.loads(stdout.read())
                sample['peakRSSBytes']=usage.ru_maxrss*(1 if sys.platform=='darwin' else 1024)
                sample['outputSHA256']=hashlib.sha256(output.read_bytes()).hexdigest()
                if iteration>=a.warmups: samples.append(sample)
        # Independently reopen and traverse every table cell in the output.
        from pptx import Presentation
        check=Presentation(output)
        for slide in check.slides:
            for shape in slide.shapes:
                if shape.has_table:
                    for row in shape.table.rows:
                        for cell in row.cells: _=cell.text
        phases={}
        for phase in samples[0]['phases']:
            values=sorted(s['phases'][phase] for s in samples)
            median=statistics.median(values)
            phases[phase]={'medianMS':median,'p95MS':values[min(len(values)-1,int(.95*len(values)))],
                           'minMS':min(values),'maxMS':max(values),
                           'relativeSpread':(max(values)-min(values))/median if median else 0}
        report['scenarios'][scenario]={'phases':phases,'samples':samples}
        a.output.write_text(json.dumps(report,indent=2)+'\n')
        print(scenario+': '+json.dumps(phases),file=sys.stderr)
