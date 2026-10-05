from pathlib import Path
import json, hashlib, datetime
root = Path('/path/to/user/Developer/rostrum')
manifest = root / 'docs/benchmarks/2026-10-04-table-transitions-integration-verification.json'
folder = root / 'docs/benchmarks/2026-10-04-table-transitions-integration'
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(manifest) == '0c7a9802ed35d70dc808edc5724b54af79cfb3b374bebf6d3ee1e819a1fa8b90'
snapshot = Path('/tmp/lectern-fidelity21-integration-acceptance-before/promoted-manifest.json')
assert not snapshot.exists(); snapshot.write_bytes(manifest.read_bytes())
m = json.loads(manifest.read_text())
items = [('/tmp/rostrum-s21-promotion-correction-independent-review.json', 'independent-promotion-correction.json', '9c568319828c246d356b1d277a5433b58f1585a7ba5db3225571f04f2e1f46d4'),
         ('/tmp/rostrum-s21-promotion-final-independent-review.json', 'independent-promotion-final.json', 'a894c11996cceaf524e9fad80412ad09bb774013a3b6224d563cf1a57177a2cb'),
         (str(snapshot), 'preclosure-promoted-manifest.json', sha(snapshot)),
         (__file__, 'closure.py', sha(__file__))]
for source, name, expected in items:
    source = Path(source); assert sha(source) == expected
    target = folder / name; assert not target.exists(); target.write_bytes(source.read_bytes())
    m['pins'][str(source)] = expected; m['pins'][str(target)] = expected
    m['exports'].append(dict(source=str(source), export=str(target.relative_to(root)), sha256=expected))
m['promotionClosure'] = dict(status='APPROVED_POST_PROMOTION', review=items[1][0], reviewSHA256=items[1][2],
    reviewedManifestSHA256=sha(snapshot), correctionReview=items[0][0], correctionReviewSHA256=items[0][2],
    finalChanges='Only exact receipt copies, approved promoted-manifest snapshot and count/hash updates; no source, report or measurement changes.')
m['acceptance']['physicalPins'] = len(m['pins']); m['acceptance']['exports'] = len(m['exports'])
m['acceptance']['closureUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
assert len(m['exports']) == len({x['export'] for x in m['exports']})
for x in m['exports']: assert sha(root / x['export']) == x['sha256']
for p, h in m['pins'].items(): assert sha(p) == h, p
manifest.write_text(json.dumps(m, indent=2, sort_keys=True) + '\n')
print(json.dumps(dict(manifestSHA256=sha(manifest), **m['acceptance'])))
