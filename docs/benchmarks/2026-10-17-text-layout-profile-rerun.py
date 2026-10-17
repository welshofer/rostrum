from pathlib import Path
import json,subprocess,statistics,sys
p=Path(sys.argv[1]); report=json.loads((p/'profile.json').read_text()); report['cases']=[]
for kind in ['plain','spans']:
 for rows,labels in [(24,'distinct'),(1000,'distinct'),(1000,'repeated')]:
  result=subprocess.run([str(p/kind),str(rows),labels,'measured','5','plan'],capture_output=True,text=True,check=True)
  entry={'kind':kind,'rows':rows,'labels':labels,'samples':json.loads(result.stdout),'profiles':[json.loads(x) for x in result.stderr.splitlines()]}
  report['cases'].append(entry)
  print(kind,rows,labels,'plan CPU',statistics.median(x['plan_cpu_ms'] for x in entry['samples'][1:]),flush=True)
  for k in sorted(entry['profiles'][0]['cpu_ms']):
   print(k,round(statistics.median(x['cpu_ms'][k] for x in entry['profiles'][1:]),2),entry['profiles'][0]['calls'][k],flush=True)
(p/'quiet-profile.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
