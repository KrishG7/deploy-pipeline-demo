#!/bin/sh
# Usage: /backup.sh [daily|predeploy|manual] [label]
#
# Dumps the database with pg_dump -Fc, checks the dump is readable, and uploads
# it with a small metadata file to the offsite bucket:
#   <bucket>/<env>/<kind>/<env>_<kind>_<UTC timestamp>[_<label>].dump
# Daily backups are pruned afterwards (see /prune.sh).
set -eu
[ -f /etc/backup.env ] && . /etc/backup.env

kind=${1:-daily}
label=${2:-}
case "$kind" in daily|predeploy|manual) ;; *) echo "unknown backup kind: $kind" >&2; exit 2 ;; esac
case "$label" in *[!A-Za-z0-9._-]*) echo "label may only contain A-Z a-z 0-9 . _ -" >&2; exit 2 ;; esac

: "${BACKUP_ENV:?}" "${S3_ENDPOINT:?}" "${S3_ACCESS_KEY:?}" "${S3_SECRET_KEY:?}" "${S3_BUCKET:?}"
export MC_HOST_offsite="${S3_ENDPOINT%%://*}://${S3_ACCESS_KEY}:${S3_SECRET_KEY}@${S3_ENDPOINT#*://}"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [backup:$BACKUP_ENV] $*"; }

ts=$(date -u +%Y%m%dT%H%M%SZ)
name="${BACKUP_ENV}_${kind}_${ts}${label:+_$label}.dump"
dest="offsite/${S3_BUCKET}/${BACKUP_ENV}/${kind}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

start=$(date +%s)
log "starting $kind backup of database '$PGDATABASE' -> $dest/$name"

# Row count taken immediately before the dump, so a restore can be checked
# against it.
rows=$(psql -XAtc 'SELECT count(*) FROM appointments')
pg_dump -Fc --no-owner -f "$work/$name"

# A dump that pg_restore cannot list is not a backup.
entries=$(pg_restore --list "$work/$name" | grep -vc '^;')
size=$(wc -c < "$work/$name" | tr -d ' ')
sha=$(sha256sum "$work/$name" | cut -d' ' -f1)

cat > "$work/$name.meta.json" <<EOF
{"environment":"$BACKUP_ENV","kind":"$kind","file":"$name","created_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","database":"$PGDATABASE","appointments_rows":$rows,"toc_entries":$entries,"size_bytes":$size,"sha256":"$sha","pg_dump":"$(pg_dump --version | sed 's/pg_dump (PostgreSQL) //')"}
EOF

mc --quiet cp "$work/$name" "$work/$name.meta.json" "$dest/" >/dev/null
mc --quiet stat "$dest/$name" >/dev/null
log "uploaded $name ($size bytes, $entries TOC entries, appointments rows=$rows, sha256=$sha) in $(( $(date +%s) - start ))s"

if [ "$kind" = daily ]; then
  /prune.sh "${S3_BUCKET}/${BACKUP_ENV}/daily"
fi
