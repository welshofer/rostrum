from pathlib import Path
import hashlib
import json
import math
import random
import statistics
import zipfile
from lxml import etree
from pptx import Presentation

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'paired'
rows = json.loads((OUT / 'raw.json').read_text())
assert len(rows) == 44 and json.loads((OUT / 'execution-receipt.json').read_text())['status'] == 'PASS'
median = statistics.median

def percentile(values, fraction):
    index = (len(values) - 1) * fraction
    lower = math.floor(index)
    return values[lower] + (values[math.ceil(index)] - values[lower]) * (index - lower)

def summarize(baseline, candidate):
    deltas = [100 * (c / b - 1) for b, c in zip(baseline, candidate)]
    randomizer = random.Random(20261004)
    boot = sorted(median(randomizer.choices(deltas, k=len(deltas))) for _ in range(100_000))
    faster = sum(c < b for b, c in zip(baseline, candidate))
    slower = sum(c > b for b, c in zip(baseline, candidate))
    count = faster + slower
    sign_p = min(1.0, 2 * sum(math.comb(count, k) for k in range(min(faster, slower) + 1)) / 2**count) if count else 1.0
    return {'baseline': baseline, 'candidate': candidate, 'baselineMedian': median(baseline),
            'candidateMedian': median(candidate), 'ratioOfMediansPercent': 100 * (median(candidate) / median(baseline) - 1),
            'pairedDeltasPercent': deltas, 'medianPairedDeltaPercent': median(deltas),
            'bootstrap95Percent': [percentile(boot, .025), percentile(boot, .975)],
            'faster': faster, 'slower': slower, 'ties': len(deltas) - count, 'twoSidedSignP': sign_p}

results = []
for option in (False, True):
    selected = [r for r in rows if r['alternative'] == option and not r['warmup']]
    assert len(selected) == 20
    baseline = sorted((r for r in selected if r['kind'] == 'baseline'), key=lambda r: r['pair'])
    candidate = sorted((r for r in selected if r['kind'] == 'candidate'), key=lambda r: r['pair'])
    assert [r['pair'] for r in baseline] == [r['pair'] for r in candidate] == list(range(1, 11))
    time_result = summarize([r['seconds'] for r in baseline], [r['seconds'] for r in candidate])
    rss_result = summarize([r['peakRSSBytes'] for r in baseline], [r['peakRSSBytes'] for r in candidate])
    rss_result['medianPairedDifferenceMiB'] = median((c['peakRSSBytes'] - b['peakRSSBytes']) / 2**20 for b, c in zip(baseline, candidate))
    results.append({'alternative': option, 'seconds': time_result, 'wholeProcessPeakRSSBytes': rss_result})

packages = slides = xml_parts = 0
for row in rows:
    folder = Path(row['directory'])
    for name, expected in row['artifactHashes'].items():
        path = folder / name
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected
        if path.suffix != '.pptx':
            continue
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None
            assert len(archive.namelist()) == len(set(archive.namelist()))
            for member in archive.namelist():
                if member.endswith(('.xml', '.rels')):
                    etree.fromstring(archive.read(member), parser=etree.XMLParser(resolve_entities=False))
                    xml_parts += 1
        slides += len(Presentation(path).slides)
        packages += 1

receipt = {'status': 'MEASURED_AWAITING_INDEPENDENT_REVIEW', 'samples': '44 fresh children, four excluded warmup children; ten retained alternating pairs per alternative',
           'scope': 'Complete headless LibraryLab.run(.listMarkers), including saved-file checks, inspection and export; not GUI interaction or isolated library rendering',
           'statistics': '100000 percentile bootstrap samples, Random seed20261004 separately per metric; median of paired ratios distinct from ratio of medians; exact two-sided sign test excluding ties. Four comparisons exploratory/unadjusted.',
           'results': results, 'independentReopens': {'packages': packages, 'slides': slides, 'xmlRelationshipParts': xml_parts},
           'preservation': 'All nine non-report output files exact per alternative; report JSON exact excluding only elapsedSeconds. Driver directory and timing fields are process metadata, not compared for equality.',
           'rawSHA256': hashlib.sha256((OUT / 'raw.json').read_bytes()).hexdigest(),
           'analysisScriptSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
           'limits': 'Background host load remains uncontrolled. Peak RSS includes the whole child process and is not an allocation count or average memory estimate. No universal/cumulative/cross-platform gain inferred.'}
(OUT / 'analysis.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
for result in results:
    timing = result['seconds']
    print(result['alternative'], 'seconds', timing['baselineMedian'], '->', timing['candidateMedian'],
          'paired%', timing['medianPairedDeltaPercent'], 'CI', timing['bootstrap95Percent'],
          'faster', timing['faster'], 'RSS MiB delta', result['wholeProcessPeakRSSBytes']['medianPairedDifferenceMiB'])
print('reopens', packages, 'slides', slides, 'XML/rels', xml_parts)
