"""Absolute resource measurements for the new fixed review decks.
Usage: python3 SCRIPT REPO SCRATCH
Uses the retained normal-Release candidate and private Calibri templates from
2026-10-17-generated-layouts.py; run after compilation/testing has stopped.
"""
import hashlib,importlib.util,json,os,subprocess,sys,time
from pathlib import Path
repo,scratch=map(lambda p:Path(p).resolve(),sys.argv[1:3])
spec=importlib.util.spec_from_file_location('profile',repo/'Tools/preview-profile/run.py')
profile=importlib.util.module_from_spec(spec);spec.loader.exec_module(profile)
if hasattr(os,'sched_setaffinity'):os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
binary=scratch/'candidate/CompositionRegression'
templates=[scratch/f'font-templates/Calibri-{ratio}.potx' for ratio in ['16x9','4x3']]
record={'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),
        'workload':'New layouts plus merged/rotated/repeated-header tables; both ratios, twelve output slides',
        'memory_method':'native wait4, fresh process, peak RSS in KiB',
        'templates':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in templates},
        'samples':[],'complete':False}
reference=None
for index in range(8):
 output=scratch/'new-samples'/str(index);output.parent.mkdir(exist_ok=True)
 usage=output.with_suffix('.usage.json')
 start=time.perf_counter()
 result=subprocess.run([str(scratch/'measure-child'),str(usage),str(binary),str(output),'--layouts',*map(str,templates)],capture_output=True,text=True)
 if result.returncode:raise RuntimeError(result.stdout+result.stderr)
 sample={'warmup':index==0,'elapsed_ms':(time.perf_counter()-start)*1000,**json.loads(usage.read_text()),
         'stages':json.loads((output/'timings.json').read_text())}
 artifacts=profile.composition_artifacts(output)
 if reference is None:reference=artifacts
 else:assert artifacts==reference,'Changed output between processes'
 record['samples'].append(sample)
 print('new workload preserved',index,flush=True)
record['artifacts']=reference
record['complete']=True
(scratch/'new-layouts.json').write_text(json.dumps(record,indent=2)+'\n')
