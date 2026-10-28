#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
npm ci --ignore-scripts --no-fund --no-audit
npm test

if ! gh aw --version >/dev/null 2>&1; then
  gh extension install github/gh-aw --pin v0.86.2
fi
gh aw --version

printf '\nReady. Start with: make doctor && make setup\n'
printf 'The lab containers have NOT been started. Open the exercise issue in YOUR repository for the first lesson.\n'
