import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('preview_profile', ROOT / 'Tools/preview-profile/run.py')
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


class NativePreviewProfileWrapperTests(unittest.TestCase):
    """Run the real wrapper and receipt validator with a controlled native exit."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        scripts = self.root / 'scripts'; scripts.mkdir()
        for name in ('profile-preview.sh', 'compare-preview-loading.py'):
            shutil.copy(ROOT / 'Lectern/scripts' / name, scripts / name)
        (scripts / 'test-app.sh').write_text('''mkdir "$TEST_RUNNER_LECTERN_PREVIEW_PROFILE_OUTPUT"
cp "$PROFILE_FIXTURE"/* "$TEST_RUNNER_LECTERN_PREVIEW_PROFILE_OUTPUT/"
exit "$PROFILE_NATIVE_STATUS"
''')
        bindir = self.root / 'bin'; bindir.mkdir()
        for name, body in {'uname': 'echo Darwin', 'xcodebuild': 'echo fixture-xcode',
                           'git': 'if [ "$1" = rev-parse ]; then echo fixture-revision; fi'}.items():
            command = bindir / name
            command.write_text('#!/bin/bash\n' + body + '\n')
            command.chmod(0o755)
        products = self.root / 'isolated products'
        for suffix in ('MacOS/LecternTestHost', 'PlugIns/LecternAppTests.xctest/Contents/MacOS/LecternAppTests'):
            binary = products / 'Build/Products/Release/LecternTestHost.app/Contents' / suffix
            binary.parent.mkdir(parents=True, exist_ok=True)
            binary.write_bytes(b'fixture executable')
        self.fixture = self.root / 'profile fixture'; self.fixture.mkdir()
        (self.fixture / 'slide-1.svg').write_text('<svg/>')
        (self.fixture / 'diagnostics.json').write_text('[]')
        self.deck = self.root / 'input with spaces.pptx'; self.deck.write_bytes(b'fixture input')
        self.output = self.root / 'new output'
        self.env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'],
                        LECTERN_TEST_DERIVED_DATA_PATH=str(products), LECTERN_PREVIEW_REUSE_BUILD='1',
                        PROFILE_FIXTURE=str(self.fixture))

    def execute(self, mode='shared', status=0, mismatch=False, mutation=None):
        report = {'schemaVersion': 3, 'buildMode': 'release', 'platform': 'macOS', 'fontResourceMode': mode,
                  'bitmapComparisonCount': int(mode == 'shared'),
                  'bitmapParityCount': int(mode == 'shared' and not mismatch),
                  'bitmapMismatchSlides': [1] if mismatch else [],
                  'samples': [{'operationInProcess': operation, 'firstBitmapAvailableSeconds': 0.5,
                               'appProcessLifetimePeakRSSBytes': 12345,
                               'stages': {'droppedSamples': 0, 'samples': [{'stage': 'thumbnail.request',
                                'cpuSeconds': 0.1, 'elapsedSeconds': 0.2, 'outcome': outcome}]}}
                              for operation, outcome in enumerate(('rendered', 'cacheHit'), 1)]}
        if mutation: mutation(report)
        (self.fixture / 'timings.json').write_text(json.dumps(report))
        env = dict(self.env, PROFILE_NATIVE_STATUS=str(status),
                   LECTERN_PREVIEW_SHARED_FONTS='1' if mode == 'shared' else '0')
        return subprocess.run(['bash', str(self.root / 'scripts/profile-preview.sh'), str(self.deck), str(self.output)],
                              env=env, capture_output=True, text=True)

    def test_valid_inline_and_shared_profiles_preserve_success(self):
        for mode in ('inline', 'shared'):
            with self.subTest(mode=mode):
                self.output = self.root / mode
                result = self.execute(mode=mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                provenance = json.loads((self.output / 'provenance.json').read_text())
                self.assertEqual(provenance['nativeExitStatus'], 0)
                self.assertTrue(provenance['pixelAcceptance'])
                self.assertEqual(provenance['sourceRevision'], 'fixture-revision')

    def test_complete_rejected_native_profile_keeps_provenance_and_native_failure(self):
        result = self.execute(status=65, mismatch=True)
        self.assertEqual(result.returncode, 65, result.stderr)
        provenance = json.loads((self.output / 'provenance.json').read_text())
        self.assertEqual(provenance['nativeExitStatus'], 65)
        self.assertFalse(provenance['pixelAcceptance'])
        self.assertTrue(provenance['testHostSHA256'])

    def test_pixel_mismatch_cannot_pass_even_if_native_process_returns_success(self):
        result = self.execute(mismatch=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('did not pass exact native bitmap comparison', result.stderr)
        provenance = json.loads((self.output / 'provenance.json').read_text())
        self.assertEqual(provenance['nativeExitStatus'], 0)
        self.assertFalse(provenance['pixelAcceptance'])

    def test_incomplete_evidence_never_gets_provenance_and_preserves_native_failure(self):
        for status in (0, 65):
            with self.subTest(status=status):
                self.output = self.root / str(status)
                result = self.execute(status=status, mutation=lambda report: report['samples'].pop())
                self.assertNotEqual(result.returncode, 0)
                if status: self.assertEqual(result.returncode, status)
                self.assertFalse((self.output / 'provenance.json').exists())

    def test_unrelated_native_failure_is_never_swallowed(self):
        result = self.execute(status=17)
        self.assertEqual(result.returncode, 17)
        provenance = json.loads((self.output / 'provenance.json').read_text())
        self.assertEqual(provenance['nativeExitStatus'], 17)
        self.assertTrue(provenance['pixelAcceptance'])


class PreviewProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.deck = self.root / 'input.pptx'
        self.deck.write_bytes(b'fixed input')
        self.binary = self.root / 'runner'
        self.binary.write_bytes(b'fixed executable')
        self.config = self.root / 'workloads.json'
        self.config.write_text(json.dumps({'workloads': [{'name': 'control', 'kind': 'inspect', 'input': 'input.pptx'}]}))
        self.output = self.root / 'output'

    def execute(self, mutation=None, **options):
        def process(command, log):
            directory = Path(command[2])
            for index in range(int(command[-1])):
                target = directory / f'run-{index + 1}'
                target.mkdir(parents=True)
                (target / 'slide-1.svg').write_text('<svg/>')
                (target / 'inspection.json').write_text('{"diagnostics":[]}')
                (target / 'timings.json').write_text(json.dumps({'seconds': index + 1, 'stages': {'samples': [], 'droppedSamples': 0}}))
                if mutation:
                    mutation(target, index)
            return {'peakRSSBytes': 1234, 'elapsedSeconds': 0.1}
        with patch.object(profile.shared, 'process_sample', side_effect=process), \
             patch.object(profile.shared, 'command_output', return_value='test'):
            return profile.collect(self.config, self.output, self.binary, runs=2, warmups=1, **options)

    def test_raw_warmups_and_process_repeats_are_retained(self):
        result = self.execute()
        self.assertTrue(result['complete'])
        samples = result['workloads'][0]['samples']
        self.assertEqual([s['warmup'] for s in samples], [True, False, False])
        self.assertEqual(len(samples[0]['timings']), 2)
        self.assertEqual(samples[0]['artifactSHA256'], samples[2]['artifactSHA256'])
        self.assertNotIn('timings.json', samples[0]['artifactSHA256'])
        self.assertEqual(result['workloads'][0]['inputSHA256'][str(self.deck)], profile.shared.sha256(self.deck))

    def test_paired_variants_alternate_and_share_output_checks(self):
        baseline = self.root / 'baseline-runner'
        baseline.write_bytes(b'baseline executable')
        result = self.execute(baseline_inspection=baseline)
        samples = result['workloads'][0]['samples']
        self.assertEqual([s['variant'] for s in samples],
                         ['candidate', 'baseline', 'baseline', 'candidate', 'candidate', 'baseline'])
        self.assertEqual(len({json.dumps(s['artifactSHA256'], sort_keys=True) for s in samples}), 1)
        self.assertEqual(len(result['executableSHA256']), 2)

    def test_truncated_trace_does_not_claim_a_complete_profile(self):
        def truncate(target, index):
            (target / 'timings.json').write_text(json.dumps({'stages': {'droppedSamples': 1}}))
        with self.assertRaisesRegex(ValueError, 'truncated stage trace'):
            self.execute(truncate)

    def test_changed_svg_between_repeated_operations_fails(self):
        with self.assertRaisesRegex(ValueError, 'Repeated inspection output changed'):
            self.execute(lambda target, index: (target / 'slide-1.svg').write_text(str(index)))
        self.assertFalse(json.loads((self.output / 'manifest.json').read_text())['complete'])

    def test_changed_diagnostics_between_repeats_fail(self):
        with self.assertRaisesRegex(ValueError, 'Repeated inspection output changed'):
            self.execute(lambda target, index: (target / 'inspection.json').write_text(str(index)))

    def test_input_mutation_fails(self):
        with self.assertRaisesRegex(ValueError, 'modified its source'):
            self.execute(lambda target, index: self.deck.write_bytes(b'mutated'))

    def test_executable_mutation_fails(self):
        with self.assertRaisesRegex(ValueError, 'Executable or config changed'):
            self.execute(lambda target, index: self.binary.write_bytes(b'changed'))

    def test_existing_output_is_never_overwritten(self):
        self.output.mkdir()
        with self.assertRaisesRegex(ValueError, 'already exists'):
            self.execute()

    def test_unsafe_names_are_refused(self):
        self.config.write_text(json.dumps({'workloads': [{'name': '../escape', 'kind': 'inspect', 'input': 'input.pptx'}]}))
        with self.assertRaisesRegex(ValueError, 'directory names'):
            profile.load_workloads(self.config)

    def test_composition_normalizes_paths_and_snapshot_order_only(self):
        root = self.root / 'composition'
        root.mkdir()
        deck = root / 'deck.pptx'; deck.write_bytes(b'deterministic')
        snapshot = root / 'random.json'; snapshot.write_text('{"b":2,"a":1}')
        manifest = [{'deck': str(deck), 'snapshot': str(snapshot), 'renderSeconds': 1,
                     'warnings': [], 'structuralStatus': 'passed'}]
        (root / 'manifest.json').write_text(json.dumps(manifest))
        before = profile.composition_artifacts(root)
        snapshot.write_text('{"a":1,"b":2}')
        manifest[0]['renderSeconds'] = 99
        (root / 'manifest.json').write_text(json.dumps(manifest))
        self.assertEqual(before, profile.composition_artifacts(root))
        manifest[0]['warnings'] = ['different']
        (root / 'manifest.json').write_text(json.dumps(manifest))
        self.assertNotEqual(before, profile.composition_artifacts(root))
