#!/usr/bin/env bash
# The independent backup: a logical export kept outside the database server and
# outside Terraform's lifecycle, with a manifest of row counts captured at export
# time. In a real platform this would live in another account or vault.
#
#   offsite-backup.sh export
#   offsite-backup.sh restore [database]   restore and verify against the manifest
#   offsite-backup.sh verify [database]    compare row counts with the manifest
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

OFFSITE="$LAB_DIR/offsite"
DUMP="$OFFSITE/$LAB_DATABASE.dump"
MANIFEST="$OFFSITE/manifest.json"

verify_manifest() {
  local target=$1
  node -e '
    const fs = require("node:fs");
    const expected = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).tables;
    const actual = JSON.parse(process.argv[2]);
    const tables = Object.keys(expected);
    const wrong = tables.filter((table) => expected[table] !== actual[table]);
    if (!tables.length || wrong.length) {
      console.error(`Row counts differ from the backup manifest: ${wrong.join(", ") || "no tables"}.`);
      process.exit(1);
    }
  ' "$MANIFEST" "$(lab_counts_json "$target")"
  echo "Row counts in $target match the backup manifest ($(lab_total_rows "$target") rows)."
}

case "${1:-}" in
  export)
    [ "$(lab_count "$LAB_DATABASE" courses_answer)" -gt 0 ] || lab_die "Nothing to export: $LAB_DATABASE is missing or empty."
    mkdir -p "$OFFSITE"
    lab_compose exec -T postgres pg_dump -U admin -Fc "$LAB_DATABASE" > "$DUMP.tmp"
    mv "$DUMP.tmp" "$DUMP"
    printf '{"database":"%s","createdAt":"%s","tables":%s}\n' \
      "$LAB_DATABASE" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(lab_counts_json)" > "$MANIFEST"
    echo "Exported $LAB_DATABASE to .lab/offsite, independent of Terraform and the database server."
    ;;
  restore)
    target=${2:-$LAB_DATABASE}
    lab_valid_name "$target"
    [ -s "$DUMP" ] && [ -s "$MANIFEST" ] || lab_die "No independent backup in .lab/offsite. Run make setup first."
    lab_db_exists "$target" || lab_psql postgres -c "CREATE DATABASE $target"
    lab_compose exec -T postgres pg_restore -U admin -d "$target" --clean --if-exists --no-owner --exit-on-error < "$DUMP"
    verify_manifest "$target"
    ;;
  verify)
    [ -s "$MANIFEST" ] || lab_die "No backup manifest in .lab/offsite. Run make setup first."
    verify_manifest "${2:-$LAB_DATABASE}"
    ;;
  *)
    lab_die "Usage: offsite-backup.sh export | restore [database] | verify [database]"
    ;;
esac
