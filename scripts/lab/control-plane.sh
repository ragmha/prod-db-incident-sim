#!/usr/bin/env bash
# The lab's stand-in for a cloud control plane. Terraform's provisioners call it
# to create and delete the production database on the local PostgreSQL server.
# Like a real cloud API, it carries out any valid request: it does not ask
# whether the caller's Terraform state was the right one.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

command=${1:-}
name=${2:-}
lab_valid_name "$name"

case "$command" in
  create-database)
    if lab_db_exists "$name"; then
      lab_die "Conflict: database \"$name\" already exists on the production server."
    fi
    lab_psql postgres -c "CREATE DATABASE $name"
    echo "Created database $name."
    ;;
  delete-database)
    # Mirrors aws_db_instance.delete_automated_backups.
    if [ "${3:-true}" = "true" ]; then
      lab_compose exec -T postgres sh -c "rm -f /snapshots/$name-*.dump"
      echo "Deleted the automated backups of $name."
    else
      echo "Retained the automated backups of $name."
    fi
    lab_psql postgres -c "DROP DATABASE IF EXISTS $name WITH (FORCE)"
    echo "Deleted database $name."
    ;;
  snapshot)
    lab_db_exists "$name" || lab_die "Database $name does not exist."
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    lab_compose exec -T postgres sh -c "pg_dump -U admin -Fc $name > /snapshots/$name-$stamp.dump"
    echo "Created automated backup $name-$stamp.dump on the database server."
    ;;
  list-snapshots)
    lab_compose exec -T postgres sh -c "ls -1 /snapshots | grep '^$name-' || echo 'No automated backups found.'"
    ;;
  *)
    lab_die "Usage: control-plane.sh create-database|delete-database|snapshot|list-snapshots <name> [delete_automated_backups]"
    ;;
esac
