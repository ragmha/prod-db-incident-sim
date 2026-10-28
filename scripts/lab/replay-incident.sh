#!/usr/bin/env bash
# Replays the incident's failure chain with real Terraform commands against the
# lab's production. It can destroy the course_platform database: run it only in
# this disposable lab. Set LAB_NONINTERACTIVE=1 to skip the pauses.
#
# The steps follow the published account: a new machine without the Terraform
# state, a plan that wants to create what already exists, an auto-approved
# apply, the old state unpacked over the new one, and an auto-approved destroy.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
lab_require_tools docker terraform node

EVIDENCE="${LAB_EVIDENCE_DIR:-$LAB_DIR/evidence}"
OLD="$LAB_ROOT/infrastructure/lab"
NEW="$LAB_DIR/new-laptop"
mkdir -p "$EVIDENCE"

rows_before=$(lab_count "$LAB_DATABASE" courses_answer)
[ "$rows_before" -gt 0 ] || lab_die "Production has no data. Run make setup, or make recover after an earlier replay."

lab_say "1/6  Production is healthy"
echo "courses_answer holds $rows_before homework submissions."
echo "Automated backups on the database server: $(lab_snapshot_count)."
lab_pause

lab_say "2/6  A new laptop: a fresh clone of infrastructure/lab without its state"
rm -rf "$NEW"
mkdir -p "$NEW"
cp "$OLD"/*.tf "$NEW"/
terraform -chdir="$NEW" init -input=false -no-color >/dev/null
if lab_has_remote_backend "$NEW"; then
  echo "The configuration has a backend block, so this machine reads the shared remote state."
else
  echo "No backend block: the state stayed on the old laptop, so this machine starts with none."
fi
lab_pause

lab_say "3/6  The agent runs: terraform plan"
terraform -chdir="$NEW" plan -input=false -no-color -out=plan.tfplan | tee "$NEW/plan.txt"
read -r plan_add plan_change plan_destroy < <(terraform -chdir="$NEW" show -json plan.tfplan | node "$LAB_ROOT/scripts/lab/plan-guard.mjs" --summary)
if [ "$plan_add" -gt 0 ]; then
  echo ">> Terraform wants to create $plan_add resource(s) that already exist. Without state, it believes nothing exists."
else
  echo ">> Terraform sees production through the shared state. There is nothing to create or clean up."
fi
lab_pause

lab_say "4/6  The agent runs: terraform apply -auto-approve"
terraform -chdir="$NEW" apply -input=false -no-color -auto-approve 2>&1 | tee "$NEW/apply.txt" || true
lab_pause

lab_say "5/6  The agent unpacks the old laptop's Terraform archive over the new state"
if lab_has_remote_backend "$NEW"; then
  echo "State lives in the remote backend, so there is no laptop state file to swap in."
elif [ -f "$OLD/terraform.tfstate" ]; then
  cp "$OLD/terraform.tfstate" "$NEW/terraform.tfstate"
  echo ">> The new laptop now holds production's state. Terraform tracks the real database again."
else
  echo "No production state file was found to copy."
fi
lab_pause

lab_say "6/6  The agent runs: terraform destroy -auto-approve"
set +e
terraform -chdir="$NEW" destroy -input=false -no-color -auto-approve 2>&1 | tee "$NEW/destroy.txt"
destroy_exit=${PIPESTATUS[0]}
set -e

rows_after=$(lab_count "$LAB_DATABASE" courses_answer)
backups_after=$(lab_snapshot_count)
blocked_by=none
if grep -q "Instance cannot be destroyed" "$NEW/destroy.txt"; then
  blocked_by=prevent_destroy
elif [ "$destroy_exit" -ne 0 ]; then
  blocked_by=destroy_failed
fi
if [ "$rows_after" -eq "$rows_before" ]; then
  outcome=blocked
elif [ "$rows_after" -eq 0 ]; then
  outcome=destroyed
else
  outcome=damaged
fi

printf '{"schemaVersion":1,"outcome":"%s","blockedBy":"%s","newLaptopPlan":{"add":%s,"change":%s,"destroy":%s},"destroyExitCode":%s,"rowsBefore":%s,"rowsAfter":%s,"automatedBackupsAfter":%s}\n' \
  "$outcome" "$blocked_by" "$plan_add" "$plan_change" "$plan_destroy" "$destroy_exit" \
  "$rows_before" "$rows_after" "$backups_after" > "$EVIDENCE/incident-replay.json"

lab_say "Result: production was $outcome"
if [ "$outcome" = "blocked" ]; then
  echo "All $rows_before submissions survived (blocked by: $blocked_by)."
else
  echo "$rows_before submissions before, $rows_after after. Automated backups left: $backups_after."
  echo "Next: make snapshots, then make recover."
fi
echo "Plan, apply, and destroy output: .lab/new-laptop/*.txt"
