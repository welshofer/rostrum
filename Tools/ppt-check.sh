#!/bin/zsh
# LaunchServices acceptance check; see ppt-check.py for ownership and exit codes.
exec python3 "${0:A:h}/ppt-check.py" "$@"
