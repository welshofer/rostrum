import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('preview_loading', ROOT / 'Lectern/scripts/compare-preview-loading.py')
loading = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(loading)


class PreviewLoadingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.deck = self.root / 'deck with spaces.pptx'
        self.deck.write_bytes(b'original')
        self.output = self.root / 'new results'
        self.calls = []
        self.commands = []
        self.identity = {'sourceRevision': 'fixed', 'testHostSHA256': 'binary',
                         'testBundleSHA256': 'tests', 'testResourcesSHA256': 'resources', 'xcode': 'fixed'}
        self.regressions = {'result': 'Passed', 'totalTestCount': 14, 'failedTests': 0,
                            'skippedTests': 0, 'passedTests': 14}

    def execute(self, change=None, fail=None, diagnose=False, pairs=2, profile_status=None):
        def run(command, env, check, stdout, **kwargs):
            self.assertTrue(check)
            name = Path(command[1]).name if command[0] == 'bash' else command[0]
            self.commands.append(name)
            self.assertEqual(env['LECTERN_TEST_CONFIGURATION'], 'Release')
            self.assertEqual(env['LECTERN_TEST_DERIVED_DATA_PATH'], str(self.output / 'build'))
            if name == fail:
                stdout.write('failed-command-log')
                raise subprocess.CalledProcessError(17, command)
            if name == 'xcrun':
                stdout.write(json.dumps(self.regressions))
                return
            stdout.write('command-log')
            if name == 'test-app.sh':
                self.assertEqual(command[2:], ['--build-only'])
                return
            if name == 'test-preview-regressions.sh':
                self.assertEqual(command[2], str(self.output / 'regressions.xcresult'))
                return
            self.assertEqual(name, 'profile-preview.sh')
            self.assertEqual(env['LECTERN_PREVIEW_REUSE_BUILD'], '1')
            self.assertEqual(command[2], str(self.deck))
            mode = 'shared' if env['LECTERN_PREVIEW_SHARED_FONTS'] == '1' else 'inline'
            self.calls.append(mode)
            status = profile_status(mode, len(self.calls)) if profile_status else 0
            target = Path(command[3]); target.mkdir(parents=True)
            files = {
                'provenance.json': dict(self.identity, inputSHA256=loading.sha256(self.deck),
                                        nativeExitStatus=status, pixelAcceptance=True),
                'timings.json': {'schemaVersion': 3, 'fontResourceMode': mode, 'buildMode': 'release',
                    'bitmapComparisonCount': int(mode == 'shared'),
                    'bitmapParityCount': int(mode == 'shared'), 'bitmapMismatchSlides': [], 'platform': 'macOS',
                    'samples': [{'operationInProcess': operation, 'firstBitmapAvailableSeconds': 0.5,
                        'appProcessLifetimePeakRSSBytes': 12345,
                        'stages': {'droppedSamples': 0, 'samples': [{'stage': 'thumbnail.request',
                            'cpuSeconds': 0.1, 'elapsedSeconds': 0.2, 'outcome': outcome}]}}
                        for operation, outcome in enumerate(('rendered', 'cacheHit'), 1)]},
                'diagnostics.json': {'issues': ['first', 'second']},
            }
            (target / 'slide-1.svg').write_text('<svg/>')
            if change:
                change(files, len(self.calls), target)
            for name, data in files.items():
                (target / name).write_text(json.dumps(data))
            if status:
                raise subprocess.CalledProcessError(status, command)
        return loading.collect(self.deck, self.output, pairs=pairs, run=run,
                               identity_reader=lambda *_: dict(self.identity),
                               diagnose_pixel_mismatches=diagnose)

    @staticmethod
    def pixel_rejection(files, call, target):
        if files['timings.json']['fontResourceMode'] == 'shared':
            files['timings.json']['bitmapParityCount'] = 0
            files['timings.json']['bitmapMismatchSlides'] = [1]
            files['provenance.json']['pixelAcceptance'] = False
            (target / 'native-bitmaps').mkdir()
            (target / 'native-bitmaps/slide-1.png').write_bytes(b'private pixels')

    def assert_failure_bundle(self):
        self.assertFalse(Path(str(self.output) + '.zip').exists())
        self.assertFalse(json.loads((self.output / 'comparison.json').read_text())['complete'])
        with zipfile.ZipFile(str(self.output) + '.failed.zip') as archive:
            self.assertTrue(any(n.endswith('comparison.json') for n in archive.namelist()))
            self.assertFalse(any(n.endswith(('.pptx', '.svg', '.png', 'diagnostics.json')) for n in archive.namelist()))

    def test_one_build_alternating_processes_then_one_regression_run(self):
        result = self.execute()
        self.assertEqual(self.calls, ['inline', 'shared', 'shared', 'inline', 'inline', 'shared'])
        self.assertEqual(self.commands, ['test-app.sh'] + ['profile-preview.sh'] * 6 +
                         ['test-preview-regressions.sh', 'xcrun'])
        self.assertTrue(result['complete'])
        self.assertTrue(result['collectionComplete'])
        self.assertTrue(result['pixelAcceptance'])
        self.assertEqual(sum(r['warmup'] for r in result['samples']), 2)
        self.assertEqual(result['summary'][0]['metrics']['firstBitmapSeconds']['pairedDeltas'], [0.0, 0.0])
        with zipfile.ZipFile(str(self.output) + '.zip') as archive:
            names = archive.namelist()
            self.assertIn('new results/regressions.json', names)
            self.assertIn('new results/00-inline/svg-manifest.json', names)
            self.assertFalse(any(n.endswith(('.pptx', '.svg', 'diagnostics.json')) or '/build/' in n for n in names))

    def test_default_still_fails_fast_on_complete_native_pixel_rejection(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.execute(self.pixel_rejection, profile_status=lambda mode, _: 65 if mode == 'shared' else 0)
        self.assertEqual(self.calls, ['inline', 'shared'])
        self.assertNotIn('test-preview-regressions.sh', self.commands)
        self.assert_failure_bundle()
        self.assertFalse(json.loads((self.output / 'comparison.json').read_text())['collectionComplete'])

    def test_diagnostic_rejections_complete_five_pairs_but_never_pass(self):
        with self.assertRaisesRegex(ValueError, 'exact bitmap acceptance failed'):
            self.execute(self.pixel_rejection, diagnose=True, pairs=5,
                         profile_status=lambda mode, _: 65 if mode == 'shared' else 0)
        self.assertEqual(len(self.calls), 12)
        self.assertEqual(self.commands.count('test-app.sh'), 1)
        self.assertEqual(self.commands.count('test-preview-regressions.sh'), 1)
        self.assert_failure_bundle()
        manifest = json.loads((self.output / 'comparison.json').read_text())
        self.assertTrue(manifest['collectionComplete'])
        self.assertFalse(manifest['pixelAcceptance'])
        self.assertEqual(len(manifest['samples']), 12)
        self.assertEqual(len(manifest['summary'][0]['metrics']['firstBitmapSeconds']['pairedDeltas']), 5)
        self.assertEqual([r['nativeExitStatus'] for r in manifest['samples'] if r['mode'] == 'shared'], [65] * 6)
        summary = (self.output / 'SUMMARY.txt').read_text()
        self.assertIn('REJECTED', summary)
        self.assertIn('do not establish a speedup or support adoption', summary)
        self.assertNotIn('all candidate bitmaps match inline', summary)
        with zipfile.ZipFile(str(self.output) + '.failed.zip') as archive:
            self.assertIn('new results/SUMMARY.txt', archive.namelist())
            self.assertEqual(sum(n.endswith('/timings.json') for n in archive.namelist()), 12)

    def test_diagnostic_mode_allows_normal_passing_collection(self):
        result = self.execute(diagnose=True)
        self.assertTrue(result['complete'])
        self.assertTrue(result['collectionComplete'])
        self.assertTrue(result['pixelAcceptance'])
        self.assertFalse(Path(str(self.output) + '.failed.zip').exists())

    def test_diagnostic_mode_never_accepts_other_failures_or_incomplete_pixel_evidence(self):
        issues = ('wrong-exit', 'inline-failure', 'no-mismatch', 'successful-rejection',
                  'missing-count', 'partial-count', 'duplicate-slide', 'unknown-slide', 'bool-count',
                  'false-parity', 'missing-operation', 'truncated', 'provenance-status', 'provenance-pixels',
                  'changed-svg', 'changed-diagnostics', 'changed-resources')
        for issue in issues:
            with self.subTest(issue=issue):
                self.output = self.root / issue
                self.calls = []
                self.commands = []
                def status(mode, call):
                    if issue == 'inline-failure': return 65
                    if mode == 'inline' or issue == 'successful-rejection': return 0
                    return 17 if issue == 'wrong-exit' else 65
                def change(files, call, target):
                    self.pixel_rejection(files, call, target)
                    if call != 2: return
                    timings = files['timings.json']
                    if issue == 'no-mismatch':
                        timings.update(bitmapParityCount=1, bitmapMismatchSlides=[])
                        files['provenance.json']['pixelAcceptance'] = True
                    if issue == 'missing-count': timings.pop('bitmapComparisonCount')
                    if issue == 'partial-count': timings['bitmapComparisonCount'] = 0
                    if issue == 'duplicate-slide': timings['bitmapMismatchSlides'] = [1, 1]
                    if issue == 'unknown-slide': timings['bitmapMismatchSlides'] = [2]
                    if issue == 'bool-count': timings['bitmapComparisonCount'] = True
                    if issue == 'false-parity': timings['bitmapParityCount'] = 1
                    if issue == 'missing-operation': timings['samples'].pop()
                    if issue == 'truncated': timings['samples'][0]['stages']['droppedSamples'] = 1
                    if issue == 'provenance-status': files['provenance.json']['nativeExitStatus'] = 0
                    if issue == 'provenance-pixels': files['provenance.json']['pixelAcceptance'] = True
                    if issue == 'changed-svg': (target / 'slide-1.svg').write_text('changed')
                    if issue == 'changed-diagnostics': files['diagnostics.json']['issues'].reverse()
                    if issue == 'changed-resources': self.identity['testResourcesSHA256'] += 'changed'
                with self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    self.execute(change, diagnose=True, profile_status=status)
                self.assertLessEqual(len(self.calls), 2)
                self.assertNotIn('test-preview-regressions.sh', self.commands)
                self.assert_failure_bundle()
                self.assertFalse(json.loads((self.output / 'comparison.json').read_text())['collectionComplete'])

    def test_changed_svg_diagnostics_or_host_never_produces_success_archive(self):
        for field in ('svg', 'diagnostics', 'host', 'resources', 'input'):
            with self.subTest(field=field):
                self.output = self.root / field
                self.calls = []
                def change(files, call, target):
                    if call != 2: return
                    if field == 'svg': (target / 'slide-1.svg').write_text('changed')
                    if field == 'diagnostics': files['diagnostics.json']['issues'].reverse()
                    if field == 'host': files['provenance.json']['testHostSHA256'] = 'changed'
                    if field == 'resources': self.identity['testResourcesSHA256'] = 'changed'
                    if field == 'input': self.deck.write_bytes(b'changed')
                with self.assertRaises(ValueError): self.execute(change)
                self.assert_failure_bundle()

    def test_missing_parity_or_invalid_measurements_fail(self):
        for issue in ('parity', 'dropped', 'null-dropped', 'wrong-mode', 'nan', 'negative', 'null',
                      'operation', 'bool-operation', 'cache-miss'):
            with self.subTest(issue=issue):
                self.output = self.root / issue
                self.calls = []
                def change(files, call, target):
                    if call != 2: return
                    timings = files['timings.json']; sample = timings['samples'][0]
                    if issue == 'parity': timings['bitmapParityCount'] = 0
                    if issue == 'dropped': sample['stages']['droppedSamples'] = 1
                    if issue == 'null-dropped': sample['stages']['droppedSamples'] = None
                    if issue == 'wrong-mode': timings['fontResourceMode'] = 'inline'
                    if issue == 'nan': sample['firstBitmapAvailableSeconds'] = float('nan')
                    if issue == 'negative': sample['stages']['samples'][0]['cpuSeconds'] = -1
                    if issue == 'null': sample['firstBitmapAvailableSeconds'] = None
                    if issue == 'operation': sample['operationInProcess'] = 2
                    if issue == 'bool-operation': sample['operationInProcess'] = True
                    if issue == 'cache-miss': timings['samples'][1]['stages']['samples'][0]['outcome'] = 'rendered'
                with self.assertRaises(ValueError): self.execute(change)
                self.assert_failure_bundle()

    def test_skipped_failed_or_missing_regressions_fail_after_measurements(self):
        for issue, value in [('skippedTests', 1), ('failedTests', 1), ('passedTests', 0), ('totalTestCount', 15)]:
            with self.subTest(issue=issue):
                self.output = self.root / issue
                self.regressions[issue] = value
                with self.assertRaisesRegex(ValueError, 'regressions'): self.execute()
                self.assert_failure_bundle()
                self.regressions[issue] = 14 if issue in ('passedTests', 'totalTestCount') else 0

    def test_build_or_regression_failures_keep_logs(self):
        for command, log in [('test-app.sh', 'build.log'), ('test-preview-regressions.sh', 'regressions.log')]:
            with self.subTest(command=command):
                self.output = self.root / command
                with self.assertRaises(subprocess.CalledProcessError): self.execute(fail=command)
                self.assert_failure_bundle()
                self.assertEqual((self.output / log).read_text(), 'failed-command-log')

    def test_existing_outputs_and_archives_are_preserved(self):
        for path in (self.output, Path(str(self.output) + '.zip'), Path(str(self.output) + '.failed.zip')):
            path.write_text('keep')
            with self.assertRaises(ValueError): self.execute()
            self.assertEqual(path.read_text(), 'keep')
            path.unlink()
        self.assertFalse(self.calls)

    def test_paired_summary_excludes_warmups_and_does_not_sum_nested_stages(self):
        records = []
        for pair, (a, b) in enumerate([(999, 100), (1, 4), (5, 3), (9, 10)]):
            for mode, elapsed in [('inline', a), ('shared', b)]:
                sample = {'firstBitmapAvailableSeconds': elapsed, 'appProcessLifetimePeakRSSBytes': 42,
                          'stages': {'samples': [
                              {'stage': 'thumbnail.request', 'cpuSeconds': 0.3, 'elapsedSeconds': 1},
                              {'stage': 'thumbnail.navigation', 'cpuSeconds': 0.1, 'elapsedSeconds': 0.5}]}}
                records.append({'pair': pair, 'warmup': pair == 0, 'mode': mode,
                                'timings': {'samples': [sample, copy.deepcopy(sample)]}})
        metrics = loading.summarize(records)[0]['metrics']
        self.assertEqual(metrics['firstBitmapSeconds']['pairedDeltas'], [3, -2, 1])
        self.assertEqual(metrics['firstBitmapSeconds']['pairedDeltaMedian'], 1)
        self.assertEqual(metrics['firstBitmapSeconds']['sharedMedian'], 4)
        self.assertEqual(metrics['firstBitmapSeconds']['inlineMedian'], 5)
        self.assertEqual(metrics['thumbnail.request.cpuSeconds']['inlineMedian'], 0.3)
        self.assertEqual(metrics['thumbnail.navigation.cpuSeconds']['inlineMedian'], 0.1)

    def test_build_identity_detects_resource_and_tracked_source_changes(self):
        products = self.root / 'products/Build/Products/Release'
        host = products / 'LecternTestHost.app'
        binary = host / 'Contents/MacOS/LecternTestHost'
        tests = host / 'Contents/PlugIns/LecternAppTests.xctest/Contents/MacOS/LecternAppTests'
        resource = products / 'LecternCore.bundle/data.json'
        for path in [binary, tests, resource]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'original')
        env = {'LECTERN_TEST_DERIVED_DATA_PATH': str(self.root / 'products')}
        def command(args, **kwargs):
            return b'diff' if args[0:2] == ('git', 'diff') else b'version'
        with patch.object(loading.subprocess, 'check_output', side_effect=command):
            before = loading.native_identity(self.root, env)
            resource.write_bytes(b'changed')
            after = loading.native_identity(self.root, env)
            self.assertEqual(before['testHostSHA256'], after['testHostSHA256'])
            self.assertNotEqual(before['testResourcesSHA256'], after['testResourcesSHA256'])
        with patch.object(loading.subprocess, 'check_output', return_value=b'changed'):
            self.assertNotEqual(after['trackedSourceDiffSHA256'], loading.native_identity(self.root, env)['trackedSourceDiffSHA256'])
