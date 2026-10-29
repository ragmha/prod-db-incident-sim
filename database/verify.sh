#!/usr/bin/env bash
# Shows production row counts. Exits non-zero when production is missing or empty.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lab/common.sh"

if ! lab_db_exists "$LAB_DATABASE"; then
  echo "The $LAB_DATABASE database does not exist." >&2
  exit 1
fi

counts=$(lab_counts "$LAB_DATABASE")
if [ -z "$counts" ]; then
  echo "The $LAB_DATABASE database exists but holds no course tables." >&2
  exit 1
fi

printf '%-20s %10s\n' "table" "rows"
printf '%s\n' "$counts" | awk '{ printf "%-20s %10s\n", $1, $2 }'
answers=$(lab_count "$LAB_DATABASE" courses_answer)
[ "$answers" -gt 0 ] || { echo "courses_answer is empty." >&2; exit 1; }
echo "Production holds $answers homework submissions in courses_answer."
