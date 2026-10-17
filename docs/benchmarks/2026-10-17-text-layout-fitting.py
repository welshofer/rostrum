from pathlib import Path
import hashlib,json,os,subprocess,statistics,tempfile,time,sys
root=Path(sys.argv[1]); mode=sys.argv[2]; out=root/('fitting-preservation.json' if mode=='preserve' else 'fitting-results.json')
cases=['plain-unique','plain-fallback-unique','mixed-unique','shrink','shrink-unique']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record={'binary_hashes':{v:sha(root/(v+'-fitting')) for v in ['baseline','candidate']},'preservation':[],'pairs':[],'processes_per_variant':5,'cpu_affinity':sorted(os.sched_getaffinity(0)) if hasattr(os,'sched_getaffinity') else None}
if mode=='preserve':
 for case in cases:
  values={}
  for v in ['baseline','candidate']:
   p=root/(v+'-fitting-'+case+'.pptx')
   data=json.loads(subprocess.check_output([str(root/(v+'-fitting')),case,str(p)],text=True))
   values[v]={k:x for k,x in data.items() if k not in ('cpuMS','elapsedMS')}
  assert values['baseline']==values['candidate']
  a=root/('baseline-fitting-'+case+'.pptx');b=root/('candidate-fitting-'+case+'.pptx')
  assert a.read_bytes()==b.read_bytes()
  record['preservation'].append({'case':case,'deck_sha256':sha(b),'result':values['candidate']})
  print(case,values['candidate'],flush=True)
else:
 previous=json.loads((root/'fitting-preservation.json').read_text());assert previous['binary_hashes']==record['binary_hashes']; record['preservation']=previous['preservation']
 def run(v,case):
  with tempfile.NamedTemporaryFile() as usage:
   start=time.perf_counter();p=subprocess.run([str(root/'measure-child'),usage.name,str(root/(v+'-fitting')),case],capture_output=True,text=True,check=True)
   return {'phase':json.loads(p.stdout),'process_elapsed_ms':(time.perf_counter()-start)*1000,**json.load(usage)}
 record['warmup']=[{'case':case,**{v:run(v,case) for v in ['baseline','candidate']}} for case in cases]
 for i in range(7):
  for case in cases:
   order=['baseline','candidate'] if i%2==0 else ['candidate','baseline']
   record['pairs'].append({'pair':i,'case':case,'order':order,**{v:{'samples':[run(v,case) for _ in range(5)]} for v in order}})
  out.write_text(json.dumps(record,indent=2,sort_keys=True)+'\n');print('Fitting pair',i+1,flush=True)
 for case in cases:
  print(case)
  pairs=[p for p in record['pairs'] if p['case']==case]
  for key in ['cpuMS','elapsedMS','process_cpu_ms','process_elapsed_ms','rss_kib']:
   def value(p,v):return statistics.median(x[key] if key in x else x['phase'][key] for x in p[v]['samples'])
   deltas=[(value(p,'candidate')/value(p,'baseline')-1)*100 for p in pairs]
   print(key,'baseline',statistics.median(value(p,'baseline') for p in pairs),'candidate',statistics.median(value(p,'candidate') for p in pairs),'paired_percent',statistics.median(deltas),'faster_pairs',sum(x<0 for x in deltas))
out.write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
