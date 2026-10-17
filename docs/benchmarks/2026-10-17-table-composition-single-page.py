"""Supplemental one-page controls: this-file.py BINARY_DIRECTORY OUTPUT.json."""
import json,statistics,subprocess,tempfile,time,sys
from pathlib import Path
root=Path(sys.argv[1]);records=[]
for pair in range(7):
 for sizing in ['measured','estimated']:
  order=['baseline','candidate'] if pair%2==0 else ['candidate','baseline']
  item={'pair':pair,'sizing':sizing,'order':order}
  for v in order:
   with tempfile.NamedTemporaryFile() as usage:
    start=time.perf_counter()
    p=subprocess.run([str(root/'measure-child'),usage.name,str(root/v),'1','distinct',sizing,'5','compose'],capture_output=True,text=True,check=True)
    item[v]={'samples':json.loads(p.stdout),'process_elapsed_ms':(time.perf_counter()-start)*1000,**json.load(usage)}
    assert all(s['pages']==1 for s in item[v]['samples'])
  records.append(item)
Path(sys.argv[2]).write_text(json.dumps({'pairs':records},indent=2,sort_keys=True)+'\n')
for sizing in ['measured','estimated']:
 items=[p for p in records if p['sizing']==sizing]
 print(sizing)
 for k in ['compose_cpu_ms','process_cpu_ms','rss_kib']:
  def val(p,v):return p[v][k] if k in p[v] else statistics.median(s[k] for s in p[v]['samples'][1:])
  deltas=[(val(p,'candidate')/val(p,'baseline')-1)*100 for p in items]
  print(k,statistics.median(deltas),'faster pairs',sum(d<0 for d in deltas))
