#!/usr/bin/env bash
# Usage: scripts/test-retention.sh <output-dir>
#
# Tests the real /prune.sh against the real bucket, without touching real
# backups: creates 60 dummy backups (one per day, 02:00 UTC, ending today) under
# backups/production/retention-test/daily/, saves the file list, prunes with the
# production policy (7 daily + 4 weekly), saves the list again, then removes the
# test prefix.
#
# Writes <output-dir>/retention-before.txt, retention-prune.txt, retention-after.txt
set -euo pipefail
out=${1:?usage: test-retention.sh <output-dir>}
root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$out"
in_backup() {
  "$root/scripts/compose.sh" production exec -T backup sh -c \
    '. /etc/backup.env; export MC_HOST_offsite="http://${S3_ACCESS_KEY}:${S3_SECRET_KEY}@${S3_ENDPOINT#*://}"; '"$1"
}
prefix=backups/production/retention-test/daily
list() { in_backup "mc ls offsite/$prefix/" | awk '{print $NF}' | grep '\.dump$' | sort; }

in_backup "mc rm --recursive --force offsite/backups/production/retention-test/ >/dev/null 2>&1 || true"
in_backup '
  today=$(date -u +%s)
  i=0
  while [ $i -lt 60 ]; do
    d=$(date -u -d "@$((today - i * 86400))" +%Y%m%d)
    echo "dummy backup for $d" > /tmp/production_daily_${d}T020000Z.dump
    i=$((i + 1))
  done
  mc --quiet cp /tmp/production_daily_*T020000Z.dump offsite/'"$prefix"'/ >/dev/null
  rm -f /tmp/production_daily_*T020000Z.dump'

{
  echo "# $(date -u +%FT%TZ) BEFORE pruning: $(list | wc -l | tr -d ' ') dummy backups in $prefix"
  list
} > "$out/retention-before.txt"

in_backup "RETAIN_DAILY=7 RETAIN_WEEKLY=4 /prune.sh $prefix" > "$out/retention-prune.txt"

{
  echo "# $(date -u +%FT%TZ) AFTER pruning (7 daily + 4 weekly): $(list | wc -l | tr -d ' ') backups left"
  list | while read -r f; do
    d=$(echo "$f" | sed -E 's/.*_([0-9]{8})T.*/\1/')
    echo "$f  $(date -j -u -f %Y%m%d "$d" '+%a %Y-%m-%d ISO-week %G-W%V' 2>/dev/null || date -u -d "$d" '+%a %Y-%m-%d ISO-week %G-W%V')"
  done
} > "$out/retention-after.txt"

in_backup "mc rm --recursive --force offsite/backups/production/retention-test/ >/dev/null"
echo "before: $(($(wc -l < "$out/retention-before.txt") - 1)) files, after: $(($(wc -l < "$out/retention-after.txt") - 1)) files"
