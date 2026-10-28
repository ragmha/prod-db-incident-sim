#!/usr/bin/env bash
# Plans infrastructure/lab against production's state and saves the plan for
# make apply. Fails, and discards the plan, when it would delete or replace
# anything. It never changes infrastructure.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
lab_require_tools terraform node

config="$LAB_ROOT/infrastructure/lab"
mkdir -p "$LAB_DIR"
rm -f "$LAB_DIR/change.tfplan"
lab_tf_init "$config"
terraform -chdir="$config" plan -input=false -no-color -out="$LAB_DIR/change.tfplan"
if ! terraform -chdir="$config" show -json "$LAB_DIR/change.tfplan" | node "$LAB_ROOT/scripts/lab/plan-guard.mjs"; then
  rm -f "$LAB_DIR/change.tfplan"
  exit 1
fi
echo "Review the plan above. To apply exactly this plan: make apply"
