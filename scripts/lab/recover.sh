#!/usr/bin/env bash
# Restores production after a loss. Prefers the newest automated backup on the
# database server; falls back to the independent export when none survived.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
lab_require_tools docker node

start=$(date +%s)
lab_say "Checking for automated backups on the database server"
latest=$(lab_compose exec -T postgres sh -c "ls -1 /snapshots 2>/dev/null | grep '^$LAB_DATABASE-' | sort | tail -n 1" || true)

if lab_db_exists "$LAB_DATABASE" && [ "$(lab_count "$LAB_DATABASE" courses_answer)" -gt 0 ]; then
  echo "Production still holds data; nothing to recover."
  exit 0
fi
lab_db_exists "$LAB_DATABASE" || bash "$LAB_ROOT/scripts/lab/control-plane.sh" create-database "$LAB_DATABASE"

if [ -n "$latest" ]; then
  echo "Restoring the automated backup $latest."
  lab_compose exec -T postgres pg_restore -U admin -d "$LAB_DATABASE" --clean --if-exists --no-owner --exit-on-error "/snapshots/$latest"
  bash "$LAB_ROOT/scripts/lab/offsite-backup.sh" verify
else
  echo "No automated backups survived. Restoring the independent export in .lab/offsite."
  bash "$LAB_ROOT/scripts/lab/offsite-backup.sh" restore
fi

lab_say "Production restored in $(( $(date +%s) - start )) seconds"
bash "$LAB_ROOT/database/verify.sh"
