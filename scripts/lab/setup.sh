#!/usr/bin/env bash
# Builds the lab's production as it existed before the incident: Terraform
# creates the database, the platform holds years of course data, a nightly
# automated backup sits on the database server, and an independent export
# exists elsewhere. Safe to rerun: it never changes provisioned infrastructure.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
lab_require_tools docker terraform node

lab_say "Starting the database server and the Terraform state store"
lab_compose up --detach --wait --quiet-pull

config="$LAB_ROOT/infrastructure/lab"
lab_tf_init "$config"
if [ "$(lab_tf_resources "$config")" -eq 0 ]; then
  if lab_db_exists "$LAB_DATABASE"; then
    lab_die "The $LAB_DATABASE database exists, but Terraform's state doesn't record it: the lab's own new-laptop problem. Run make reset to rebuild a clean lab."
  fi
  lab_say "Provisioning production with Terraform (infrastructure/lab)"
  # Stands in for how production was created long before the incident. Later
  # changes go through make plan-check and make apply, or the Release workflow.
  terraform -chdir="$config" apply -input=false -no-color -auto-approve
else
  echo "Production is already provisioned. Change it with make plan-check, then make apply."
fi

if ! lab_db_exists "$LAB_DATABASE"; then
  lab_die "Terraform state says production exists, but the $LAB_DATABASE database is gone. Run make recover, or make reset for a clean lab."
fi

if [ "$(lab_count "$LAB_DATABASE" courses_answer)" -eq 0 ]; then
  lab_say "Loading the course platform's data"
  lab_psql "$LAB_DATABASE" -f - < "$LAB_ROOT/database/seed-data.sql" >/dev/null
fi

lab_say "Taking the nightly automated backup and the independent export"
bash "$LAB_ROOT/scripts/lab/control-plane.sh" snapshot "$LAB_DATABASE"
bash "$LAB_ROOT/scripts/lab/offsite-backup.sh" export

lab_say "Production is ready"
bash "$LAB_ROOT/database/verify.sh"
