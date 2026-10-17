"""Untimed optimized scanner equivalence. Arguments: BASELINE CANDIDATE NEW_OUTPUT."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys

baseline, candidate = (Path(p).resolve(strict=True) for p in sys.argv[1:3])
root = Path(sys.argv[3]).resolve()
root.mkdir(parents=True, exist_ok=False)
paths = []
for offset in range(16):
    for length in range(1, 18):
        payload = base64.b64encode(bytes([42]) * length).decode()
        text = (' ' * offset + '<svg><style type="text/css">'
                "@font-face{font-family:'RostrumEmbeddedFace1';font-style:normal;"
                "font-weight:400;src:url(data:font/ttf;base64," + payload
                + ") format('truetype');}</style><text>é中</text></svg>" + '<' * length)
        for kind, content in [('complete', text), ('truncated', text[:text.index('</style>') + length % 8])]:
            path = root / f'{offset}-{length}-{kind}.svg'
            path.write_text(content)
            paths.append(str(path))
manifest = root / 'inputs.json'
manifest.write_text(json.dumps(paths))
reports = []
for name, binary in [('baseline', baseline), ('candidate', candidate)]:
    output = root / name
    subprocess.run([str(binary), 'shared', str(manifest), 'verify', 'artifacts', str(output)],
                   check=True, stdout=subprocess.DEVNULL)
    reports.append({p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir()})
assert reports[0] == reports[1]
report = {'cases': len(paths), 'identicalFiles': len(reports[0]), 'exactReconstruction': True,
          'releaseEquivalence': True, 'binaryHashes': {
              name: hashlib.sha256(binary.read_bytes()).hexdigest()
              for name, binary in [('baseline', baseline), ('candidate', candidate)]}}
(root / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
print(root / 'result.json')
