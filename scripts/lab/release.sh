#!/usr/bin/env bash
# Steps of the Release workflow (.github/workflows/release.yml).
#
# The lab keeps no production between workflow runs, so every run rebuilds
# production with the configuration the starter shipped, then plans this
# commit's configuration against it. The plan job publishes the plan. After a
# human approves the production environment, the apply job plans again,
# refuses anything other than the approved changes, and applies them.
#
#   release.sh plan
#   release.sh apply    reads APPROVED_CHANGES from the plan job
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
lab_require_tools git docker terraform node

mode=${1:-}
[ "$mode" = plan ] || [ "$mode" = apply ] || lab_die "Usage: release.sh plan|apply"
config=infrastructure/lab
guard="$LAB_ROOT/scripts/lab/plan-guard.mjs"
baseline=$(git -C "$LAB_ROOT" log --diff-filter=A --format=%H -- "$config/main.tf" | tail -n 1)
[ -n "$baseline" ] || lab_die "No commit adds $config/main.tf. Create your repository from the template so it keeps the starter's history."

lab_say "Rebuilding production with the starter's configuration (${baseline:0:12})"
git -C "$LAB_ROOT" checkout --no-overlay "$baseline" -- "$config"
bash "$LAB_ROOT/scripts/lab/setup.sh"
git -C "$LAB_ROOT" checkout --no-overlay HEAD -- "$config"

lab_say "Planning this commit's configuration against production"
bash "$LAB_ROOT/scripts/lab/plan-check.sh"
plan=$(terraform -chdir="$LAB_ROOT/$config" show -json "$LAB_DIR/change.tfplan")
changes=$(node "$guard" --changes <<<"$plan")
read -r add change destroy < <(node "$guard" --summary <<<"$plan")

if [ "$mode" = plan ]; then
  [ -z "${GITHUB_OUTPUT:-}" ] || echo "changes=$changes" >> "$GITHUB_OUTPUT"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "## Plan for review"
      echo
      echo "$add to add, $change to change, $destroy to destroy. Approve the production deployment only if this is the change you reviewed."
      echo
      echo '```'
      terraform -chdir="$LAB_ROOT/$config" show -no-color "$LAB_DIR/change.tfplan"
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi

if [ "$changes" != "${APPROVED_CHANGES:-}" ]; then
  lab_die "This plan ($changes) differs from the approved plan (${APPROVED_CHANGES:-none}). Run Release again."
fi
lab_say "Applying the approved plan"
bash "$LAB_ROOT/scripts/lab/apply.sh"
evidence="${LAB_EVIDENCE_DIR:-$LAB_DIR/evidence}"
mkdir -p "$evidence"
printf '{"baseline":"%s","plan":{"add":%s,"change":%s,"destroy":%s},"applied":true}\n' \
  "$baseline" "$add" "$change" "$destroy" > "$evidence/release.json"
