"""Exercise orchestration and failure handling without launching a native app."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]


class PreviewRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.scripts = self.root / 'Lectern/scripts'
        self.scripts.mkdir(parents=True)
        shutil.copy(ROOT / 'Lectern/scripts/test-preview.sh', self.scripts)
        self.deck = self.root / 'input deck.pptx'
        self.deck.write_bytes(b'original deck')
        self.output = self.root / 'test results'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.command('uname', 'echo "${TEST_PLATFORM:-Darwin}"')
        for tool in ('xcodebuild', 'xcodegen'):
            self.command(tool, 'exit 0')
        self.command('xcrun', 'cat "$TEST_ROOT/test-summary.json"')
        (self.root / 'test-summary.json').write_text(json.dumps({
            'result': 'Passed', 'totalTestCount': 3, 'passedTests': 3,
            'failedTests': 0, 'skippedTests': 0,
        }))
        (self.root / 'timings.json').write_text(json.dumps({'samples': [{
            'operationInProcess': i, 'firstBitmapAvailableSeconds': 0.5,
            'thumbnailCacheAccountedBytes': 1000, 'appProcessLifetimePeakRSSBytes': 2000,
        } for i in (1, 2)]}))
        (self.root / 'provenance.json').write_text(json.dumps({
            'sourceRevision': 'test-revision', 'sourceDirty': False, 'inputSHA256': 'test-hash',
        }))
        (self.scripts / 'profile-preview.sh').write_text('''set -eu
echo profile >> "$TEST_ROOT/order"
echo profile-log
[ "${TEST_FAIL:-}" != profile ] || exit 17
[ "$1" = "$TEST_ROOT/input deck.pptx" ]
mkdir "$2"
cp "$TEST_ROOT/timings.json" "$TEST_ROOT/provenance.json" "$2/"
echo '<svg/>' > "$2/slide-1.svg"
''')
        (self.scripts / 'test-app.sh').write_text('''set -eu
echo regressions >> "$TEST_ROOT/order"
echo regression-log
[ "$LECTERN_TEST_CONFIGURATION" = Release ]
[ -z "${TEST_RUNNER_LECTERN_PREVIEW_PROFILE_INPUT:-}" ]
printf '%s\\n' "$@" > "$TEST_ROOT/arguments"
[ "${TEST_FAIL:-}" != regressions ] || exit 23
''')
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        TEST_ROOT=str(self.root), TEST_RUNNER_LECTERN_PREVIEW_PROFILE_INPUT='stale')

    def command(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)

    def run_script(self, *args):
        return subprocess.run(['bash', str(self.scripts / 'test-preview.sh'), *args],
                              cwd=self.root, env=self.env, capture_output=True, text=True)

    def test_relative_paths_spaces_order_and_evidence_bundle(self):
        result = self.run_script('input deck.pptx', 'test results')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / 'order').read_text().splitlines(), ['profile', 'regressions'])
        arguments = (self.root / 'arguments').read_text()
        for suite in ('SlidePreviewGeometryTests', 'SlideRasterizerTests', 'PreviewPipelineTraceTests'):
            self.assertIn('-only-testing:LecternAppTests/' + suite, arguments)
        self.assertIn('-parallel-testing-enabled\nNO\n', arguments)
        with zipfile.ZipFile(str(self.output) + '.zip') as archive:
            names = archive.namelist()
            self.assertIn('test results/profile/slide-1.svg', names)
            self.assertIn('test results/profile/provenance.json', names)
            self.assertIn('test results/regressions.log', names)
            self.assertIn('3 passed', archive.read('test results/SUMMARY.txt').decode())
            self.assertFalse(any(name.endswith('.pptx') for name in names))
        self.assertEqual(self.deck.read_bytes(), b'original deck')

    def test_default_output_is_inside_ignored_build_directory(self):
        result = self.run_script(str(self.deck))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(list((self.root / '.build').glob('preview-test-*.zip'))), 1)

    def test_failures_survive_tee_and_keep_logs_without_success_archive(self):
        for stage, code in [('profile', 17), ('regressions', 23)]:
            with self.subTest(stage=stage):
                self.env['TEST_FAIL'] = stage
                output = self.root / stage
                result = self.run_script(str(self.deck), str(output))
                self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                self.assertIn('Failed at', result.stderr)
                self.assertTrue((output / 'profile.log').exists())
                self.assertFalse(Path(str(output) + '.zip').exists())
                if stage == 'profile':
                    self.assertFalse((self.root / 'arguments').exists())

    def test_zero_tests_or_failed_results_never_produce_success_bundle(self):
        for count, failed, status in [(0, 0, 'Passed'), (3, 1, 'Failed'), (3, 0, 'Unknown')]:
            with self.subTest(count=count, failed=failed, status=status):
                (self.root / 'test-summary.json').write_text(json.dumps({
                    'result': status, 'totalTestCount': count, 'passedTests': count - failed,
                    'failedTests': failed, 'skippedTests': 0,
                }))
                output = self.root / f'result-{count}-{failed}-{status}'
                result = self.run_script(str(self.deck), str(output))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(Path(str(output) + '.zip').exists())

    def test_existing_output_or_archive_is_preserved(self):
        for path in (self.output, Path(str(self.output) + '.zip')):
            path.write_text('keep')
            result = self.run_script(str(self.deck), str(self.output))
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(path.read_text(), 'keep')
            self.assertFalse((self.root / 'order').exists())
            path.unlink()

    def test_non_mac_stops_before_tests_and_help_is_portable(self):
        self.env['TEST_PLATFORM'] = 'Linux'
        self.assertEqual(self.run_script('--help').returncode, 0)
        result = self.run_script(str(self.deck), str(self.output))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('needs macOS', result.stderr)
        self.assertFalse(self.output.exists())
