import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('preview_profile', ROOT / 'Tools/preview-profile/run.py')
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)


class PreviewProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
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
