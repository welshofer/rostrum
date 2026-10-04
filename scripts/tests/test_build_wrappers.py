"""Real XcodeGen refresh with stubbed build execution in isolated projects."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

@unittest.skipUnless(shutil.which('xcodegen'), 'XcodeGen required')
class BuildWrappersTests(unittest.TestCase):
    def test_fresh_and_changed_project_for_every_wrapper(self):
        for wrapper in ['build.sh', 'build-ios.sh', 'test-app.sh']:
            with self.subTest(wrapper=wrapper), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                shutil.copytree(ROOT / 'Lectern/scripts', root / 'scripts')
                (root / 'App').mkdir()
                (root / 'App/main.swift').write_text('print("fixture")')
                (root / '.signing.local').write_text('LECTERN_SIGN_IDENTITY="stable-audit-identity"\n')
                bindir = root / 'bin'; bindir.mkdir()
                builder = bindir / 'xcodebuild'
                builder.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > build-arguments.txt\n')
                builder.chmod(0o755)
                env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'])
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
                # Same missing-tool error, even when an old generated project exists.
                (bindir / 'dirname').symlink_to('/usr/bin/dirname')
                (bindir / 'bash').symlink_to('/bin/bash')
                env['PATH'] = str(bindir)
                result = subprocess.run(['/bin/bash', str(root / 'scripts' / wrapper)], env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('brew install xcodegen', result.stderr)

if __name__ == '__main__':
    unittest.main()
