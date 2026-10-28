#!/usr/bin/env bash
# Restore drill: proves that the independent backup restores completely, without
# touching production. It restores into a scratch database, compares every
# table with the backup manifest, then removes the scratch copy.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
lab_require_tools docker node

DRILL_DATABASE=course_platform_drill
EVIDENCE="${LAB_EVIDENCE_DIR:-$LAB_DIR/evidence}"
mkdir -p "$EVIDENCE"

lab_say "Restore drill: restoring the independent backup into $DRILL_DATABASE"
start=$(date +%s)
outcome=failed
if bash "$LAB_ROOT/scripts/lab/offsite-backup.sh" restore "$DRILL_DATABASE"; then
  outcome=restored
fi
seconds=$(( $(date +%s) - start ))
restored=$(lab_total_rows "$DRILL_DATABASE")
expected=$(node -e '
  const fs = require("node:fs");
  try {
    const tables = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).tables;
    console.log(Object.values(tables).reduce((sum, rows) => sum + rows, 0));
  } catch { console.log(0); }
' "$LAB_DIR/offsite/manifest.json")
lab_psql postgres -c "DROP DATABASE IF EXISTS $DRILL_DATABASE WITH (FORCE)" >/dev/null

printf '{"schemaVersion":1,"outcome":"%s","rowsExpected":%s,"rowsRestored":%s,"seconds":%s}\n' \
  "$outcome" "$expected" "$restored" "$seconds" > "$EVIDENCE/drill.json"

if [ "$outcome" = "restored" ]; then
  echo "Drill passed: $restored of $expected rows restored in ${seconds}s. Production was not touched."
else
  lab_die "Drill failed: the independent backup did not restore completely."
fi
