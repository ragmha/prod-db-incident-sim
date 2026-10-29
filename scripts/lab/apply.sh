#!/usr/bin/env bash
# Applies exactly the plan that make plan-check saved and you reviewed. A saved
# plan never prompts, and Terraform refuses it if production changed since.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
lab_require_tools terraform

[ -f "$LAB_DIR/change.tfplan" ] || lab_die "No reviewed plan to apply. Run make plan-check first."
terraform -chdir="$LAB_ROOT/infrastructure/lab" apply -input=false -no-color "$LAB_DIR/change.tfplan"
rm -f "$LAB_DIR/change.tfplan"
