#!/bin/sh
# Usage: /restore.sh <object path inside the bucket>
# Runs inside the STAGING backup container (called by scripts/restore-to-staging.sh).
# Downloads the dump, drops and recreates $PGDATABASE, restores, and compares the
# appointments row count with the count recorded when the backup was taken.
set -eu
[ -f /etc/backup.env ] && . /etc/backup.env

object=${1:?usage: restore.sh <path inside bucket>}
: "${BACKUP_ENV:?}" "${S3_ENDPOINT:?}" "${S3_ACCESS_KEY:?}" "${S3_SECRET_KEY:?}" "${S3_BUCKET:?}"
if [ "$BACKUP_ENV" != staging ]; then
  echo "refusing to restore: this container belongs to '$BACKUP_ENV', restores only go to staging" >&2
  exit 3
fi
export MC_HOST_offsite="${S3_ENDPOINT%%://*}://${S3_ACCESS_KEY}:${S3_SECRET_KEY}@${S3_ENDPOINT#*://}"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [restore] $*"; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
file="$work/$(basename "$object")"

log "downloading offsite/$S3_BUCKET/$object"
mc --quiet cp "offsite/$S3_BUCKET/$object" "$file" >/dev/null
mc --quiet cp "offsite/$S3_BUCKET/$object.meta.json" "$file.meta.json" >/dev/null
expected_rows=$(sed -n 's/.*"appointments_rows":\([0-9]*\).*/\1/p' "$file.meta.json")
expected_sha=$(sed -n 's/.*"sha256":"\([0-9a-f]*\)".*/\1/p' "$file.meta.json")
actual_sha=$(sha256sum "$file" | cut -d' ' -f1)
log "downloaded $(wc -c < "$file" | tr -d ' ') bytes; sha256 $actual_sha"
if [ "$actual_sha" != "$expected_sha" ]; then
  echo "checksum mismatch: metadata says $expected_sha" >&2
  exit 4
fi
log "checksum matches metadata; rows at backup time: $expected_rows"

log "dropping and recreating database '$PGDATABASE'"
dropdb --if-exists --force --maintenance-db=postgres "$PGDATABASE"
createdb --maintenance-db=postgres "$PGDATABASE"

log "pg_restore into '$PGDATABASE'"
pg_restore --no-owner --exit-on-error -d "$PGDATABASE" "$file"

actual_rows=$(psql -XAtc 'SELECT count(*) FROM appointments')
log "appointments rows after restore: $actual_rows (expected $expected_rows)"
if [ "$actual_rows" != "$expected_rows" ]; then
  echo "ROW COUNT MISMATCH" >&2
  exit 5
fi
log "row count check: OK"
