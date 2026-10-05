from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, subprocess

root = Path('/path/to/user/Developer/rostrum')
draft = Path('/tmp/lectern-fidelity21-integration-accepted-performance/docs/benchmarks/2026-10-04-table-transitions-integration-verification.json')
review = Path('/tmp/rostrum-s21-integration-independent-review.json')
report = root / 'docs/LAYOUT-FIDELITY-20261004-21.md'
lab = root / 'docs/LIBRARY-LAB-20261002.md'
out = root / 'docs/benchmarks/2026-10-04-table-transitions-integration-verification.json'
folder = root / 'docs/benchmarks/2026-10-04-table-transitions-integration'
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(draft) == 'e899e962529ff39ae8bdc1b1816bf5beee94020c21d79e8afc76fb2f59cbc7d5'
assert sha(review) == '5253ae6bf916aba24a8edadd52ee99cf6863fd43943123bc028b5ae51ce252ab'
reviewed = json.loads(review.read_text())
assert sha(report) == reviewed['reportReviewed']['sha256']
assert not out.exists() and not folder.exists()
m = json.loads(draft.read_text())
for p, h in m['pins'].items():
    assert sha(p) == h, p
for p, h in m['sourcePins'].items():
    assert sha(root / p) == h, p
assert subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD:Sources']).decode().strip() == m['sourcesTree']
before = Path('/tmp/lectern-fidelity21-integration-acceptance-before')
before.mkdir(exist_ok=False)
(before / 'reviewed-report.md').write_bytes(report.read_bytes())
(before / 'reviewed-manifest.json').write_bytes(draft.read_bytes())
(before / 'final-library-lab.md').write_bytes(lab.read_bytes())
old = 'performance analysis passes independent review; final integration acceptance is\npending. The experiment establishes no speedup or nonregression claim.'
new = 'performance analysis and final integration evidence pass independent review.\nThe experiment establishes no speedup or nonregression claim.'
text = report.read_text(); assert text.count(old) == 1
report.write_text(text.replace(old, new) + '\nThe [accepted integration manifest](benchmarks/2026-10-04-table-transitions-integration-verification.json)\nretains the final independent review, original draft histories, capture and\nmanual receipts, and accepted performance evidence. Its 685 source pins are an\nexplicitly scoped inventory of Sources, Lectern, scripts and relevant tests and\nfixtures; they are not a complete repository count or a denominator comparable\nto earlier passes.\n')
folder.mkdir(parents=True)
exports = []
for row in m['exports']:
    source = Path(row['draftCopy']); assert sha(source) == row['sha256']
    target = root / row['proposedExport']; assert not target.exists()
    target.write_bytes(source.read_bytes())
    exports.append(dict(export=str(target.relative_to(root)), source=str(source), sha256=sha(target)))

def add(source, name):
    source = Path(source); target = folder / name
    assert not target.exists(); target.write_bytes(source.read_bytes())
    exports.append(dict(export=str(target.relative_to(root)), source=str(source), sha256=sha(target)))
    m['pins'][str(source)] = sha(source)
    m['pins'][str(target)] = sha(target)

add(review, 'independent-final-integration-review.json')
add('/tmp/rostrum-s21-integration-draft-independent-review.json', 'independent-initial-integration-review.json')
add(before / 'reviewed-report.md', 'preacceptance-reviewed-report.md')
add(before / 'reviewed-manifest.json', 'preacceptance-reviewed-manifest.json')
add(before / 'final-library-lab.md', 'final-library-lab.md')
add(__file__, 'acceptance.py')
m['pins'][str(report)] = sha(report)
m['exports'] = exports
m['status'] = 'ACCEPTED_INDEPENDENT_INTEGRATION_REVIEW'
m['trackedRootFilesWritten'] = True
m['independentFinalReview'] = dict(path=str(review), sha256=sha(review), reviewedManifestSHA256=sha(draft),
    postReviewEdits='Approved acceptance/scope prose, completed Library Lab status, additive snapshots and final review copies. Production source and numerical evidence unchanged.')
m['report'] = dict(path=str(report.relative_to(root)), sha256=sha(report))
m['acceptance'] = dict(utc=datetime.now(timezone.utc).isoformat(), script=str(Path(__file__)), scriptSHA256=sha(__file__),
    physicalPins=len(m['pins']), sourcePins=len(m['sourcePins']), exports=len(exports))
for row in exports:
    assert sha(root / row['export']) == row['sha256']
for p, h in m['pins'].items():
    assert sha(p) == h, p
out.write_text(json.dumps(m, indent=2, sort_keys=True) + '\n')
print(json.dumps(dict(manifest=str(out), manifestSHA256=sha(out), reportSHA256=sha(report), **m['acceptance'])))
