#!/bin/bash
# Install the repository's git hooks. Run once per clone:
#
#   ./scripts/install-hooks.sh
#
# It points core.hooksPath at the tracked scripts/hooks directory, so the
# pre-push hook (which runs ./scripts/verify.sh, the full local gate) travels
# with the repo instead of living untracked in .git/hooks. Undo with:
#
#   git config --unset core.hooksPath
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/* 2>/dev/null || true

printf 'Installed: core.hooksPath -> scripts/hooks\n'
printf 'git push now runs ./scripts/verify.sh first (bypass one push with --no-verify).\n'
