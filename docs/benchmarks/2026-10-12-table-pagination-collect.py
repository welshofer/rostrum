import argparse, json, subprocess, statistics, os, hashlib, platform
from pathlib import Path
parser=argparse.ArgumentParser(description='Collect table pagination timings and alternate seven small-table process pairs.')
parser.add_argument('--baseline', type=Path, required=True)
parser.add_argument('--candidate', type=Path, required=True)
parser.add_argument('--scaling', type=Path, required=True)
parser.add_argument('--rss-kib', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args=parser.parse_args()
baseline=args.baseline.resolve()
candidate=args.candidate.resolve()
pairs=[]
for pair in range(7):
    outputs={}
    order=[('baseline',baseline),('candidate',candidate)]
    if pair % 2: order.reverse()
    for label,binary in order:
        outputs[label]=json.loads(subprocess.check_output([str(binary)],text=True))
    pairs.append({'pair':pair,'order':[x[0] for x in order],**outputs})
summary=[]
for unique in [False,True]:
    medians={label:[statistics.median(r['seconds'] for r in p[label] if r['unique']==unique and r['trial']>0) for p in pairs] for label in ['baseline','candidate']}
    changes=[(c/b-1)*100 for b,c in zip(medians['baseline'],medians['candidate'])]
    summary.append({'distinct_labels':unique,'baseline_median_ms':statistics.median(medians['baseline'])*1000,'candidate_median_ms':statistics.median(medians['candidate'])*1000,'median_paired_change_percent':statistics.median(changes),'slower_pairs':sum(x>0 for x in changes),'paired_change_percent':changes})
raw=json.loads(args.scaling.read_text())
scaling=[]
for count in [100,1000]:
 for distinct in [False,True]:
    samples=[r for r in raw if r['body_rows']==count and r['distinct_labels']==distinct and r['trial']>0]
    result={'body_rows':count,'distinct_labels':distinct,'pages':samples[0]['pages']}
    for metric in ['plan_seconds','compose_with_preflight_seconds','prefix_reference_seconds']:
        if metric in samples[0]: result[metric.replace('_seconds','_median_ms')]=statistics.median(r[metric] for r in samples)*1000
    scaling.append(result)
record={'base_commit':'91bcf62','swift':'6.1.3','platform':platform.platform(),'available_logical_cpus':len(os.sched_getaffinity(0)),'configuration':'Release -O','concurrent_builds_or_tests':False,'warmup_trials_excluded':1,'single_table_baseline_sha256':hashlib.sha256(baseline.read_bytes()).hexdigest(),'single_table_candidate_sha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'pagination_peak_rss_kib':int(args.rss_kib.read_text()),'single_table_summary':summary,'pagination_summary':scaling,'single_table_pairs':pairs,'pagination_samples':raw}
args.output.write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
print(json.dumps({'single_table':summary,'pagination':scaling,'rss_kib':record['pagination_peak_rss_kib']},indent=2))
