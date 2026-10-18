"""Compare retained Release CompositionRegression executables; no concurrent builds.
Usage: python3 collect.py REPO SCRATCH [RENDERS_PER_PROCESS]
SCRATCH contains retained baseline/candidate binaries and Calibri-4x3.potx.
See docs/GENERATED-LAYOUTS-20261017.md for the build and artifact contract.
"""
import hashlib,importlib.util,json,os,platform,statistics,subprocess,sys,time
from pathlib import Path
repo,scratch=map(lambda p:Path(p).resolve(),sys.argv[1:3])
repetitions=int(sys.argv[3]) if len(sys.argv)>3 else 1
assert repetitions > 0
suffix='' if repetitions==1 else f'-batch{repetitions}'
spec=importlib.util.spec_from_file_location('profile',repo/'Tools/preview-profile/run.py')
profile=importlib.util.module_from_spec(spec);spec.loader.exec_module(profile)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
if hasattr(os,'sched_setaffinity'):os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
inputs=scratch/'inputs';inputs.mkdir(exist_ok=True)
for rows in [8,100]:
 deck={'irVersion':'lectern.deck/1','meta':{'title':f'Plain table {rows}'},'slides':[
 {'id':'cover','layout':'title','title':'Keep the evidence editable'},
 {'id':'table','layout':'table','title':'Exact source records','body':{'table':{
 'headers':['Record','Observation','Value'],'rows':[[f'R{i}',f'Original observation {i} retains every source word.','1234'] for i in range(1,rows+1)]},'source':'Synthetic records.'},'notes':'Original notes.'}]}
 (inputs/f'table-{rows}.json').write_text(json.dumps(deck))
cases={'mixed':['']*repetitions,
       'small':['--replay',str(inputs/'table-8.json')]+['']*repetitions,
       'large':['--replay',str(inputs/'table-100.json')]+['']*repetitions,
       'template':['--replay',str(inputs/'table-8.json')]+[str(scratch/'font-templates/Calibri-4x3.potx')]*repetitions}
launcher=scratch/'measure-child'
subprocess.run(['cc','-O2',str(repo/'docs/benchmarks/2026-10-16-measure-child.c'),'-o',str(launcher)],check=True)
record={'baseline_commit':'4af22a1886a39d2fc0673fd46fa88783fcf85cb3','platform':platform.platform(),
 'toolchain':subprocess.check_output(['swift','--version'],text=True).strip(),
 'memory_method':'wait4 in native launcher; fresh process per sample',
 'binary_hashes':[{'variant':v,'sha256':sha(scratch/v/'CompositionRegression')} for v in ['baseline','candidate']],
 'inputs':[{'name':p.name,'sha256':sha(p)} for p in sorted(inputs.glob('*.json'))]+[{'name':'Calibri-4x3.potx','sha256':sha(scratch/'font-templates/Calibri-4x3.potx')}],
 'source_hashes':[{'path':str(p.relative_to(repo)),'sha256':sha(p)} for d in ['Sources','Lectern/Sources'] for p in sorted((repo/d).rglob('*.swift'))],
 'renders_per_process':repetitions,'pairs':[],'preservation':{},'warmups':1,'pairs_per_case':7,'complete':False}
refs={}
for pair in range(-1,7):
 for case,args in cases.items():
  item={'pair':pair,'warmup':pair<0,'case':case,'order':['baseline','candidate'] if pair%2==0 else ['candidate','baseline']}
  for variant in item['order']:
   output=scratch/('samples'+suffix)/f'{case}-{pair+1}-{variant}'
   usage=output.with_suffix('.usage.json');output.parent.mkdir(exist_ok=True)
   start=time.perf_counter()
   p=subprocess.run([str(launcher),str(usage),str(scratch/variant/'CompositionRegression'),str(output),*args],capture_output=True,text=True)
   if p.returncode:raise RuntimeError(p.stdout+p.stderr)
   item[variant]={'elapsed_ms':(time.perf_counter()-start)*1000,**json.loads(usage.read_text())}
   artifacts=profile.composition_artifacts(output)
   if case in refs: assert artifacts==refs[case],(case,variant,'preservation mismatch')
   else: refs[case]=artifacts
   item[variant]['stages']=json.loads((output/'timings.json').read_text())
  record['pairs'].append(item)
  record['preservation'][case]={'identical_artifacts':len(refs[case]),'hashes':refs[case]}
  (scratch/('comparison'+suffix+'.json')).write_text(json.dumps(record,indent=2)+'\n')
  print('preserved',case,'pair',pair,flush=True)
record['complete']=True
(scratch/('comparison'+suffix+'.json')).write_text(json.dumps(record,indent=2)+'\n')
for case in cases:
 pairs=[p for p in record['pairs'] if p['case']==case and not p['warmup']]
 print(case, {k:statistics.median(100*(p['candidate'][k]/p['baseline'][k]-1) for p in pairs) for k in ['elapsed_ms','process_cpu_ms','rss_kib']})
