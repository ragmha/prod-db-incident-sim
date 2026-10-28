#!/usr/bin/env bash
# Checks the lab toolchain without starting containers or changing anything.
set -uo pipefail

missing=0
check() {
  local name=$1
  shift
  if output=$("$@" 2>&1 | head -n 1); then
    printf '  %-16s %s\n' "$name" "$output"
  else
    printf '  %-16s MISSING\n' "$name"
    missing=1
  fi
}
optional() {
  local name=$1
  shift
  if output=$("$@" 2>&1 | head -n 1); then
    printf '  %-16s %s\n' "$name" "$output"
  else
    printf '  %-16s not installed (optional)\n' "$name"
  fi
}

echo "Required:"
check docker docker --version
check "docker compose" docker compose version
check terraform terraform version
check node node --version
echo "Optional:"
optional "GitHub CLI" gh --version
optional "Copilot CLI" copilot --version
optional "gh-aw" gh aw --version

if [ "$missing" -ne 0 ]; then
  echo "Install the missing tools or open the repository in its Codespace."
  exit 1
fi
echo "Toolchain ready. Nothing was started. Next: make setup"
