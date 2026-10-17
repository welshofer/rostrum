import json,subprocess,statistics,os,sys
from pathlib import Path
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
r=[]
for pair in range(7):
 for kind in ['', '-spans','-rotated']:
  v={}
  for variant in (['baseline','candidate'] if pair%2==0 else ['candidate','baseline']):
   args=[str(Path(sys.argv[1])/(variant+kind)),'24','distinct','measured','30','compose']
   if kind=='-rotated': args+=['--rotated']
   p=subprocess.run(args,capture_output=True,text=True,check=True)
   v[variant]=json.loads(p.stdout)
  r.append({'pair':pair,'kind':kind,**v})
Path(sys.argv[2]).write_text(json.dumps(r,indent=2)+'\n')
for kind in ['', '-spans','-rotated']:
 for key in ['plan_cpu_ms','compose_cpu_ms']:
  x=[100*(statistics.median(s[key] for s in p['candidate'][1:])/statistics.median(s[key] for s in p['baseline'][1:])-1) for p in r if p['kind']==kind]
  print(kind,key,'paired median %',statistics.median(x),'all',x,flush=True)
