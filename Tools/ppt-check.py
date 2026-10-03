#!/usr/bin/env python3
"""Check a private copy without closing or modifying the user's presentations.

Exit codes: 0 accepted, 1 repair/rejected dialog, 2 invalid input, 3 timeout, 4 automation error.
Ambiguous dialogs fail closed and remain untouched. An unsuccessful check retains
its private copy so PowerPoint never refers to a file we deleted underneath it.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

OBSERVE = r'''
on run argv
    set targetPath to item 1 of argv
    set targetName to item 2 of argv
    set acceptedSamples to 0
    repeat 25 times
        delay 1
        tell application "System Events"
            tell process "Microsoft PowerPoint"
                repeat with w in windows
                    set windowName to name of w
                    if windowName contains targetName and windowName contains "Repaired" then return "REPAIR"
                    -- Newer Office presents repair as a document-backed AXDialog
                    -- with nested buttons, not the older top-level modal button.
                    if role of w is "AXDialog" or subrole of w is "AXDialog" then
                        try
                            if (value of attribute "AXDocument" of w) is ("file://" & targetPath) then return "REJECTED-DIALOG"
                        end try
                    end if
                    if windowName contains targetName or windowName is "" or windowName is "Microsoft PowerPoint" then
                      if exists button "Repair" of w then
                        -- A modal dialog can belong to unrelated user work. Do not click it.
                        set dialogText to windowName
                        repeat with t in static texts of w
                            set dialogText to dialogText & " " & value of t
                        end repeat
                        if dialogText contains targetName then return "REPAIR"
                        return "AMBIGUOUS-DIALOG"
                      end if
                    end if
                end repeat
            end tell
        end tell
        set foundTarget to false
        tell application "Microsoft PowerPoint"
            set expectedName to targetName & ".pptx"
            if exists presentation expectedName then
                set targetPresentation to presentation expectedName
                if (full name of targetPresentation as text) is targetPath then
                    set foundTarget to true
                    set acceptedSamples to acceptedSamples + 1
                    if acceptedSamples >= 2 then
                        if not saved of targetPresentation then return "UNSAVED-COPY"
                        close targetPresentation saving no
                        return "OK"
                    end if
                end if
            end if
        end tell
        if not foundTarget then set acceptedSamples to 0
    end repeat
    return "TIMEOUT"
end run
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    args = parser.parse_args()
    source = args.file.expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".pptx" or not zipfile.is_zipfile(source):
        parser.error("expected an existing .pptx ZIP file")
    folder = Path(tempfile.mkdtemp(prefix="rostrum-ppt-check-"))
    target = folder / (folder.name + ".pptx")
    try:
        shutil.copy2(source, target)
        opened = subprocess.run(["open", "-a", "Microsoft PowerPoint", str(target)],
                                capture_output=True, text=True, timeout=15)
        if opened.returncode:
            raise RuntimeError("LaunchServices could not open the copy")
        observed = subprocess.run(["osascript", "-", str(target), target.stem],
                                  input=OBSERVE, capture_output=True, text=True, timeout=90)
        if observed.returncode:
            raise RuntimeError("PowerPoint observation failed: " + observed.stderr.strip())
        result = observed.stdout.strip()
        code = {"OK": 0, "REPAIR": 1, "REJECTED-DIALOG": 1, "TIMEOUT": 3}.get(result, 4)
        print(f"{result if code != 4 else 'AUTOMATION: ' + result}  {source.name}")
        if code == 0:
            shutil.rmtree(folder)
        else:
            print(f"Private copy retained for inspection: {target}")
        return code
    except subprocess.TimeoutExpired:
        print(f"TIMEOUT  {source.name}; private copy retained: {target}")
        return 3
    except (OSError, RuntimeError) as error:
        print(f"AUTOMATION  {error}; private copy retained: {target}")
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
