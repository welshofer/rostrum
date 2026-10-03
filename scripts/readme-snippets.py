#!/usr/bin/env python3
"""Render marked README examples from the executable source; check by default."""
import argparse
from pathlib import Path
import re
import sys
import textwrap


def rendered(source: str, name: str) -> str:
    # Functions are top-level; their closing brace is unindented.
    match = re.search(r'^func ' + re.escape(name) + r'\(\) throws \{\n(.*?)^\}', source, re.M | re.S)
    if match is None:
        raise ValueError(f'missing executable snippet {name}')
    body = textwrap.dedent(match.group(1)).rstrip()
    body = body.replace('outDir.appending(path: "hello.pptx")', 'URL(filePath: "hello.pptx")')
    body = body.replace('outDir.appending(path: "review.pptx")', 'URL(filePath: "review.pptx")')
    body = body.replace('Design(contentsOf: sunflowerMD)', 'Design(contentsOf: URL(filePath: "sunflower.md"))')
    return '```swift\nimport Foundation\nimport Rostrum\n\n' + body + '\n```'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='update only marked README blocks')
    parser.add_argument('--readme', type=Path, help='alternate README for isolated verification')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    path = args.readme or root / 'README.md'
    source = (root / 'Examples/ReadmeSnippets/main.swift').read_text()
    original = path.read_text()
    updated = original
    for name in ['quickStart', 'designAuthoring']:
        pattern = re.compile(r'(<!-- snippet:' + name + r' -->\n).*?(\n<!-- /snippet:' + name + r' -->)', re.S)
        if len(pattern.findall(updated)) != 1:
            raise ValueError(f'expected one README block for {name}')
        updated = pattern.sub(lambda m: m[1] + rendered(source, name) + m[2], updated)
    if updated == original:
        print('README executable snippets match their source.')
        return 0
    if args.write:
        path.write_text(updated)
        print('Updated README executable snippets.')
        return 0
    print('README snippets differ from executable source. Run python3 scripts/readme-snippets.py --write.', file=sys.stderr)
    return 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f'readme-snippets: {error}', file=sys.stderr)
        sys.exit(2)
