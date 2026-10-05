from pathlib import Path
from zipfile import ZipFile
from datetime import datetime
from uuid import UUID
from lxml import etree
from collections import Counter
import json, hashlib, sys

source, destination = map(Path, sys.argv[1:3])
assert not destination.exists()
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
MODERN = '{http://schemas.microsoft.com/office/powerpoint/2018/8/main}'
OLD = '{http://schemas.openxmlformats.org/presentationml/2006/main}'
ID_FIELDS = {(MODERN+'author','id'), (MODERN+'cm','id'), (MODERN+'cm','authorId'),
             (MODERN+'reply','id'), (MODERN+'reply','authorId')}
TIME_FIELDS = {(OLD+'cm','dt'), (MODERN+'cm','created'), (MODERN+'reply','created')}
receipt = json.loads(source.read_text()); results = []; captions = []
for entry in receipt['labPackageDifferences']:
    current, prior = Path(entry['current']), Path(entry['prior'])
    assert sha(current) == entry['currentSHA256'] and sha(prior) == entry['priorSHA256']
    mapping, inverse, diffs = {}, {}, Counter()
    with ZipFile(current) as a, ZipFile(prior) as b:
        assert set(a.namelist()) == set(b.namelist())
        changed = [name for name in sorted(a.namelist()) if a.read(name) != b.read(name)]
        assert changed == entry['parts']['changed']
        for name in changed:
            assert name == 'ppt/authors.xml' or name.startswith('ppt/comments/')
            aa, bb = etree.fromstring(a.read(name)), etree.fromstring(b.read(name))
            assert len(list(aa.iter())) == len(list(bb.iter()))
            for new, old in zip(aa.iter(), bb.iter()):
                assert new.tag == old.tag and new.text == old.text and new.tail == old.tail
                assert set(new.attrib) == set(old.attrib)
                for attribute in new.attrib:
                    nv, ov = new.get(attribute), old.get(attribute)
                    key = (new.tag, attribute)
                    if key in ID_FIELDS:
                        UUID(nv.strip('{}')); UUID(ov.strip('{}'))
                        assert mapping.setdefault(ov, nv) == nv
                        assert inverse.setdefault(nv, ov) == ov
                    if nv == ov: continue
                    assert key in ID_FIELDS | TIME_FIELDS, key
                    if key in TIME_FIELDS:
                        datetime.fromisoformat(nv.replace('Z','+00:00'))
                        datetime.fromisoformat(ov.replace('Z','+00:00'))
                    diffs[key] += 1
        # Author references and declared authors must remain the same graph.
        for name in changed:
            aa, bb = etree.fromstring(a.read(name)), etree.fromstring(b.read(name))
            for new, old in zip(aa.iter(),bb.iter()):
                for attribute in new.attrib:
                    if (new.tag,attribute) in ID_FIELDS:
                        assert mapping[old.get(attribute)] == new.get(attribute)
    results.append({'current': str(current), 'currentSHA256': sha(current),
        'prior': str(prior), 'priorSHA256': sha(prior), 'changedParts': changed,
        'uuidMappingBijectiveAndReferencesConsistent': True,
        'differences': [{'tag':t, 'attribute':k, 'count':n} for (t,k),n in sorted(diffs.items())],
        'classification': 'Only valid comment/author UUIDs and timestamps differ; mapping is bijective and consistent. All tags, text, tails, other attributes, part sets and other part bytes are exact.'})
assert len(results) == 4 and len(captions) == 0
result = {'status':'PASS_ONLY_COMMENT_UUID_TIMESTAMP_VARIATION', 'inputReceipt':str(source),
    'inputReceiptSHA256':sha(source),'packages':results,'captionPackages':captions,'script':str(Path(__file__)), 'scriptSHA256':sha(__file__)}
destination.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'receipt':str(destination),'sha256':sha(destination),'commentPackages':len(results),'captionPackages':len(captions)}))
