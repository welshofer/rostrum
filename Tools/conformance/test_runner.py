import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('oracle',Path(__file__).with_name('powerpoint_check.py'))
oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)
class RunnerTests(unittest.TestCase):
    def test_only_exact_open_is_success(self):
        self.assertEqual(oracle.classify('OPEN'),0)
        for state in ['REPAIR','REPAIRED','TIMEOUT','WAIT','DIALOG','UNAVAILABLE','', 'OK:other.pptx']:
            self.assertNotEqual(oracle.classify(state),0,state)
    def test_cleanup_is_scoped_by_name(self):
        self.assertIn('name of p is item 1 of argv',oracle.CLOSE)
        self.assertNotIn('close every presentation',oracle.CLOSE)
if __name__=='__main__': unittest.main()
