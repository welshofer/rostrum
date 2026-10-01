#!/usr/bin/env python3
"""Strict Office open oracle. Never closes or saves user-owned presentations.

Each run opens its own uniquely named copy through LaunchServices, then checks
that exact document. A repair, timeout, inaccessible UI or missing application
is a failure. Temporary copies are retained on failure for inspection.
"""
import argparse, json, shutil, subprocess, sys, tempfile, time
from pathlib import Path


def apple(script, *args, timeout=15):
    result = subprocess.run(['osascript', '-e', script, *args], text=True,
                            capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'AppleScript failed')
    return result.stdout.strip()


PROBE = '''on run argv
set wanted to item 1 of argv
tell application "System Events"
    if not (exists process "Microsoft PowerPoint") then return "WAIT"
    tell process "Microsoft PowerPoint"
        repeat with w in windows
            set wn to name of w
            if wn contains wanted and wn contains "Repaired" then return "REPAIRED"
            if exists button "Repair" of w then return "REPAIR"
            if role of w is "AXDialog" then return "DIALOG"
        end repeat
    end tell
end tell
tell application "Microsoft PowerPoint"
    repeat with p in presentations
        if (name of p is wanted) or (name of p is wanted & ".pptx") then return "OPEN"
    end repeat
end tell
return "WAIT"
end run'''

CLOSE = '''on run argv
tell application "Microsoft PowerPoint"
    repeat with p in presentations
        if (name of p is item 1 of argv) or (name of p is (item 1 of argv) & ".pptx") then
            close p saving no
            return "CLOSED"
        end if
    end repeat
end tell
return "NOT-FOUND"
end run'''


def classify(status):
    if status == 'OPEN': return 0
    if status in ('REPAIR', 'REPAIRED'): return 2
    if status in ('WAIT', 'TIMEOUT'): return 3
    return 4


def check(path, timeout=45):
    if sys.platform != 'darwin' or not Path('/Applications/Microsoft PowerPoint.app').exists():
        return {'status':'UNAVAILABLE', 'exitCode':4}
    # Do not open anything while an existing modal dialog belongs to the user.
    before = apple(PROBE, '__rostrum_not_an_open_document__')
    if before != 'WAIT':
        return {'status':'EXISTING-DIALOG', 'exitCode':4}
    folder = Path(tempfile.mkdtemp(prefix='rostrum-office-'))
    own = folder / (folder.name + '.pptx')
    shutil.copyfile(path, own)
    subprocess.run(['open','-a','Microsoft PowerPoint',str(own)], check=True)
    deadline = time.monotonic() + timeout
    status, stable = 'TIMEOUT', 0
    while time.monotonic() < deadline:
        state = apple(PROBE, own.stem)
        if state == 'OPEN':
            stable += 1
            # Give Office time to finish asynchronous validation after open.
            if stable >= 3:
                status = 'OPEN'; break
        elif state != 'WAIT':
            status = state; break
        else: stable = 0
        time.sleep(1)
    code = classify(status)
    if code == 0:
        if apple(CLOSE, own.stem) != 'CLOSED':
            raise RuntimeError('owned document could not be closed')
        shutil.rmtree(folder)
    return {'status':status, 'exitCode':code, 'input':str(path),
            'retainedCopy':str(own) if code else None}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path)
    parser.add_argument('--timeout',type=float,default=45)
    args = parser.parse_args()
    try:
        if not args.file.is_file(): raise ValueError('input does not exist')
        result = check(args.file.resolve(), args.timeout)
    except Exception as error:
        result = {'status':'ERROR','exitCode':4,'error':str(error)}
    print(json.dumps(result))
    sys.exit(result['exitCode'])
