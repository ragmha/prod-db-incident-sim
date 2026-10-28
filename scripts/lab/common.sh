#!/usr/bin/env bash
# Shared helpers for the lab scripts. Source this file; do not execute it.

LAB_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LAB_DIR="$LAB_ROOT/.lab"
LAB_DATABASE=course_platform
LAB_TABLES=(courses students enrollments homework_questions courses_answer leaderboard login_providers)

# The separate state store from docker-compose.yml. Terraform's pg backend
# reads this variable, so no connection string is committed with the code.
export PG_CONN_STR="${PG_CONN_STR:-postgres://terraform@127.0.0.1:5433/terraform_state?sslmode=disable}"

lab_say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
lab_die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

lab_pause() {
  [ "${LAB_NONINTERACTIVE:-0}" = "1" ] && return 0
  [ -t 0 ] || return 0
  read -r -p "Press Enter to continue..." _
}

lab_require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || lab_die "$tool is required. Use the Codespace, or run make doctor."
  done
}

lab_compose() {
  docker compose --project-directory "$LAB_ROOT" -f "$LAB_ROOT/docker-compose.yml" "$@"
}

# lab_psql <database> [psql args]: prints bare values (-qtA) and stops on errors.
lab_psql() {
  local database=$1
  shift
  lab_compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U admin -d "$database" -qtA "$@"
}

lab_valid_name() {
  [[ "${1:-}" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] || lab_die "Invalid database name: '${1:-}'."
}

lab_db_exists() {
  [ "$(lab_psql postgres -c "SELECT 1 FROM pg_database WHERE datname = '$1'")" = "1" ]
}

# lab_count <database> <table>: row count, or 0 when the database or table is missing.
lab_count() {
  lab_db_exists "$1" || { echo 0; return 0; }
  lab_psql "$1" -c "SELECT count(*) FROM $2" 2>/dev/null || echo 0
}

# lab_counts <database>: "table rows" lines for every lab table; empty if unseeded.
lab_counts() {
  local database=${1:-$LAB_DATABASE} table sql=""
  lab_db_exists "$database" || return 0
  for table in "${LAB_TABLES[@]}"; do
    sql+="SELECT '$table', count(*) FROM $table UNION ALL "
  done
  lab_psql "$database" -F ' ' -c "${sql% UNION ALL }" 2>/dev/null || true
}

lab_counts_json() {
  lab_counts "${1:-$LAB_DATABASE}" |
    awk 'BEGIN { printf "{" } NR > 1 { printf "," } { printf "\"%s\":%s", $1, $2 } END { printf "}" }'
}

lab_total_rows() {
  lab_counts "${1:-$LAB_DATABASE}" | awk '{ total += $2 } END { print total + 0 }'
}

lab_snapshot_count() {
  lab_compose exec -T postgres sh -c "ls -1 /snapshots 2>/dev/null | grep -c '^$LAB_DATABASE-' || true"
}

# Terraform configurations with a backend block keep state outside this machine.
lab_has_remote_backend() {
  grep -Eqs '^[[:space:]]*backend[[:space:]]+"' "$1"/*.tf
}

# Initializes a configuration. When you add or change a backend, existing state
# is copied into it. Initialization never changes infrastructure.
lab_tf_init() {
  terraform -chdir="$1" init -input=false -no-color -migrate-state -force-copy >/dev/null
}

# Number of resources recorded in a configuration's state.
lab_tf_resources() {
  terraform -chdir="$1" state list 2>/dev/null | grep -c . || true
}
