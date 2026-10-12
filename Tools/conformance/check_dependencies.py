#!/usr/bin/env python3
"""Require working, pinned portable oracles before tests can silently skip them."""
import importlib
import importlib.metadata
from pathlib import Path
import shutil
import sys


def check():
    errors = []
    requirements = Path(__file__).with_name('requirements.txt').read_text().splitlines()
    for requirement in requirements:
        if not requirement or requirement.startswith('#'):
            continue
        name, expected = requirement.split('==')
        try:
            actual = importlib.metadata.version(name)
            if actual != expected:
                errors.append(f'{name}: expected {expected}, found {actual}')
        except importlib.metadata.PackageNotFoundError:
            errors.append(f'{name}=={expected}: missing')
    for module in ('pptx', 'PIL.Image', 'resvg_py', 'lxml.etree', 'typing_extensions', 'xlsxwriter'):
        try:
            importlib.import_module(module)
        except (ImportError, OSError) as error:
            errors.append(f'{module}: cannot load ({error})')
    for command in ('zip', 'unzip'):
        if shutil.which(command) is None:
            errors.append(f'{command}: missing from PATH')
    return errors


if __name__ == '__main__':
    errors = check()
    if errors:
        print('Portable oracle preflight failed:\n  ' + '\n  '.join(errors), file=sys.stderr)
        print('Install zip/unzip and use a Python venv with: '
              'python3 -m pip install -r Tools/conformance/requirements.txt', file=sys.stderr)
        sys.exit(1)
    print('Portable oracle dependencies verified.')
