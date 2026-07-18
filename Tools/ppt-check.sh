#!/bin/zsh
# Repair-detector: LaunchServices open (implicit sandbox grant), then poll.
f="$1"
osascript -e 'tell application "Microsoft PowerPoint" to close every presentation saving no' >/dev/null 2>&1
open -a "Microsoft PowerPoint" "$f"
result=$(osascript - <<'APPLESCRIPT' 2>&1
with timeout of 40 seconds
    repeat with i from 1 to 25
        delay 1
        -- genuine repair dialog? (an alert with a Repair button)
        tell application "System Events"
            if exists process "Microsoft PowerPoint" then
                tell process "Microsoft PowerPoint"
                    repeat with w in windows
                        try
                            if exists button "Repair" of w then
                                click button "Cancel" of w
                                return "REPAIR-DIALOG"
                            end if
                        end try
                    end repeat
                end tell
            end if
        end tell
        tell application "Microsoft PowerPoint"
            if (count of presentations) > 0 then
                set nm to name of presentation 1
                close presentation 1 saving no
                return "OK:" & nm
            end if
        end tell
    end repeat
    return "TIMEOUT-NO-DIALOG-NO-PRESENTATION"
end timeout
APPLESCRIPT
)
case "$result" in
    OK:*)            echo "OK      $(basename $f)";;
    REPAIR-DIALOG)   echo "REPAIR  $(basename $f)";;
    *)               echo "STUCK   $(basename $f)  [$result]";;
esac
