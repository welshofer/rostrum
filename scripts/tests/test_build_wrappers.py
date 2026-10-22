"""Real XcodeGen refresh with stubbed build execution in isolated projects."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class BuildWrappersTests(unittest.TestCase):
    def test_production_configuration_preserves_signing_and_isolation(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'scripts').mkdir()
            shutil.copy(ROOT / 'Lectern/scripts/build.sh', root / 'scripts/build.sh')
            (root / 'scripts/generate-project.sh').write_text('touch generated\n')
            (root / '.signing.local').write_text('LECTERN_SIGN_IDENTITY="stable identity"\n')
            bindir = root / 'bin'; bindir.mkdir()
            builder = bindir / 'xcodebuild'
            builder.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > arguments\n')
            builder.chmod(0o755)
            env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'],
                       LECTERN_DERIVED_DATA_PATH=str(root / 'isolated products'))
            for configuration in [None, 'Release', 'Debug']:
                env.pop('LECTERN_BUILD_CONFIGURATION', None)
                if configuration:
                    env['LECTERN_BUILD_CONFIGURATION'] = configuration
                result = subprocess.run(['bash', str(root / 'scripts/build.sh'), '-quiet'],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                args = (root / 'arguments').read_text().splitlines()
                self.assertEqual(args.count('-configuration'), 1)
                self.assertEqual(args[args.index('-configuration') + 1], configuration or 'Debug')
                self.assertEqual(args[args.index('-derivedDataPath') + 1], str(root / 'isolated products'))
                self.assertIn('CODE_SIGN_IDENTITY=stable identity', args)
                self.assertIn('CODE_SIGN_STYLE=Manual', args)
                self.assertIn('-quiet', args)
            (root / 'arguments').unlink()
            (root / 'generated').unlink()
            env['LECTERN_BUILD_CONFIGURATION'] = 'Invalid'
            result = subprocess.run(['bash', str(root / 'scripts/build.sh')],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Debug or Release', result.stderr)
            self.assertFalse((root / 'arguments').exists())
            self.assertFalse((root / 'generated').exists())

    @unittest.skipUnless(shutil.which('xcodegen'), 'XcodeGen required')
    def test_fresh_and_changed_project_for_every_wrapper(self):
        for wrapper in ['build.sh', 'build-ios.sh', 'test-app.sh']:
            with self.subTest(wrapper=wrapper), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                shutil.copytree(ROOT / 'Lectern/scripts', root / 'scripts')
                (root / 'App').mkdir()
                (root / 'App/main.swift').write_text('print("fixture")')
                (root / '.signing.local').write_text('LECTERN_SIGN_IDENTITY="stable-audit-identity"\n')
                bindir = root / 'bin'; bindir.mkdir()
                process_check = bindir / 'pgrep'
                process_check.write_text('#!/bin/bash\nexit 1\n')
                process_check.chmod(0o755)
                builder = bindir / 'xcodebuild'
                builder.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > build-arguments.txt\n')
                builder.chmod(0o755)
                env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'])
                env.pop('LECTERN_TEST_DERIVED_DATA_PATH', None)
                for marker in ['first', 'changed']:
                    (root / 'project.yml').write_text(f'''name: Lectern
settings:
  base:
    AUDIT_MARKER: {marker}
targets:
  Lectern:
    type: application
    platform: macOS
    sources: [App]
''')
                    subprocess.run(['/bin/bash', str(root / 'scripts' / wrapper), '-quiet'], env=env, check=True, capture_output=True)
                    self.assertIn(f'AUDIT_MARKER = {marker}', (root / 'Lectern.xcodeproj/project.pbxproj').read_text())
                args = (root / 'build-arguments.txt').read_text()
                self.assertIn('-quiet', args)
                if wrapper == 'build-ios.sh':
                    self.assertIn('CODE_SIGN_IDENTITY=-', args)
                    self.assertIn('CODE_SIGN_ENTITLEMENTS=App/Lectern-iOS-Sim.entitlements', args)
                else:
                    self.assertIn('CODE_SIGN_IDENTITY=stable-audit-identity', args)
                    self.assertIn('CODE_SIGN_STYLE=Manual', args)
                if wrapper == 'test-app.sh':
                    self.assertIn('LecternTests', args)
                    self.assertIn('.build-xcode-tests', args)
                    subprocess.run(['/bin/bash', str(root / 'scripts' / wrapper), '--build-only'],
                                   env=env, check=True, capture_output=True)
                    actions = (root / 'build-arguments.txt').read_text().splitlines()
                    self.assertIn('build-for-testing', actions)
                    self.assertNotIn('test', actions)
                # Same missing-tool error, even when an old generated project exists.
                (bindir / 'dirname').symlink_to('/usr/bin/dirname')
                (bindir / 'bash').symlink_to('/bin/bash')
                env['PATH'] = str(bindir)
                result = subprocess.run(['/bin/bash', str(root / 'scripts' / wrapper)], env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('brew install xcodegen', result.stderr)

if __name__ == '__main__':
    unittest.main()
