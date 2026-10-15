import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('preview_loading', ROOT / 'Lectern/scripts/compare-preview-loading.py')
loading = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(loading)


class PreviewLoadingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.deck = self.root / 'deck with spaces.pptx'
        self.deck.write_bytes(b'original')
        self.output = self.root / 'new results'
        self.calls = []

    def execute(self, change=None):
        def run(command, env, check):
            self.assertTrue(check)
            self.assertEqual(command[2], str(self.deck))
            mode = 'shared' if env['LECTERN_PREVIEW_SHARED_FONTS'] == '1' else 'inline'
            self.calls.append(mode)
            target = Path(command[3]); (target / 'profile').mkdir(parents=True)
            files = {
                'profile/provenance.json': {'inputSHA256': loading.sha256(self.deck),
                    'sourceRevision': 'fixed', 'testHostSHA256': 'binary', 'testBundleSHA256': 'tests', 'xcode': 'fixed'},
                'profile/timings.json': {'fontResourceMode': mode, 'buildMode': 'release', 'bitmapParityCount': 1, 'platform': 'macOS',
                    'samples': [{'firstBitmapAvailableSeconds': 0.5, 'appProcessLifetimePeakRSSBytes': 12345,
                        'stages': {'droppedSamples': 0, 'samples': [{'stage': 'thumbnail.request', 'cpuSeconds': 0.1,
                            'outcome': outcome}]}} for outcome in ('rendered', 'cacheHit')]},
                'svg-manifest.json': {'slide-1.svg': {'sha256': 'same', 'bytes': 42}},
                'regressions.json': {'result': 'Passed', 'failedTests': 0, 'skippedTests': 0, 'passedTests': 14},
            }
            if change:
                change(files, len(self.calls))
            for name, data in files.items():
                (target / name).write_text(json.dumps(data))
            with zipfile.ZipFile(str(target) + '.zip', 'w') as archive:
                archive.writestr('SUMMARY.txt', 'run evidence')
        return loading.collect(self.deck, self.output, pairs=2, run=run)

    def test_pairs_alternate_with_warmups_and_small_archive(self):
        result = self.execute()
        self.assertEqual(self.calls, ['inline', 'shared', 'shared', 'inline', 'inline', 'shared'])
        self.assertTrue(result['complete'])
        self.assertEqual(sum(r['warmup'] for r in result['samples']), 2)
        with zipfile.ZipFile(str(self.output) + '.zip') as archive:
            self.assertEqual(len(archive.namelist()), 8)
            self.assertFalse(any(n.endswith(('.pptx', '.svg')) for n in archive.namelist()))

    def test_changed_output_or_host_never_produces_success_archive(self):
        for field in ('svg-manifest.json', 'profile/provenance.json'):
            with self.subTest(field=field):
                self.output = self.root / field.replace('/', '-')
                self.calls = []
                def change(files, call):
                    if call == 2:
                        if field == 'svg-manifest.json': files[field]['slide-1.svg']['sha256'] = 'changed'
                        else: files[field]['testHostSHA256'] = 'changed'
                with self.assertRaises(ValueError): self.execute(change)
                self.assertFalse(Path(str(self.output) + '.zip').exists())
                self.assertFalse(json.loads((self.output / 'comparison.json').read_text())['complete'])
                with zipfile.ZipFile(str(self.output) + '.failed.zip') as archive:
                    self.assertTrue(any(n.endswith('comparison.json') for n in archive.namelist()))
                    self.assertFalse(any(n.endswith(('.pptx', '.svg')) for n in archive.namelist()))

    def test_missing_parity_skipped_tests_or_incomplete_trace_fail(self):
        for issue in ('parity', 'skipped', 'dropped', 'wrong-mode'):
            with self.subTest(issue=issue):
                self.output = self.root / issue
                self.calls = []
                def change(files, call):
                    if call != 2: return
                    if issue == 'parity': files['profile/timings.json']['bitmapParityCount'] = 0
                    if issue == 'skipped': files['regressions.json']['skippedTests'] = 1
                    if issue == 'dropped': files['profile/timings.json']['samples'][0]['stages']['droppedSamples'] = 1
                    if issue == 'wrong-mode': files['profile/timings.json']['fontResourceMode'] = 'inline'
                with self.assertRaises(ValueError): self.execute(change)
                self.assertFalse(Path(str(self.output) + '.zip').exists())

    def test_existing_outputs_and_archives_are_preserved(self):
        for path in (self.output, Path(str(self.output) + '.zip'), Path(str(self.output) + '.failed.zip')):
            path.write_text('keep')
            with self.assertRaises(ValueError): self.execute()
            self.assertEqual(path.read_text(), 'keep')
            path.unlink()
        self.assertFalse(self.calls)
