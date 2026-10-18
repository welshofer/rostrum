#!/usr/bin/env python3
"""Run a test command and publish bounded failure context as Actions annotations.

Swift Testing failures are otherwise only present in external log storage. Keep
normal output and the command's exit status; annotations never turn a failure green.
"""
import collections
import subprocess
import sys


def escape(value):
    return value.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def main(arguments):
    if not arguments:
        print('Usage: ci-test.py COMMAND [ARGUMENT ...]', file=sys.stderr)
        return 2
    tail = collections.deque(maxlen=20)
    excerpts = []
    remaining = 0
    try:
        child = subprocess.Popen(arguments, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, encoding='utf-8', errors='replace')
        for line in child.stdout:
            print(line, end='', flush=True)
            bounded = line[:1000]
            tail.append(bounded)
            if remaining:
                excerpts[-1] += bounded
                remaining -= 1
            elif len(excerpts) < 10 and ('✘' in line or 'error:' in line):
                excerpts.append(bounded)
                remaining = 5
        status = child.wait()
    except OSError as error:
        status = 127
        tail.append(str(error))
    if status:
        for context in excerpts or [''.join(tail)]:
            print('::error title=Test command failed::' + escape(context[:6000]), flush=True)
    return status if status >= 0 else 128 - status


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
