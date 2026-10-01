#!/bin/zsh
# Delegates to the input-owned strict runner; nonzero means no acceptance.
exec python3 "${0:A:h}/conformance/powerpoint_check.py" "$@"
