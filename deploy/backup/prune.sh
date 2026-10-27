#!/bin/sh
# Usage: /prune.sh <bucket/prefix> [--dry-run]
#
# Grandfather-father-son retention for the backups under a prefix:
#   - keep the newest backup of each of the RETAIN_DAILY (7) most recent days
#   - keep the newest backup of each of the RETAIN_WEEKLY (4) most recent ISO weeks
#   - delete everything else (and its .meta.json)
# Dates come from the timestamp in the file name, not from object mtimes, so
# copied or re-uploaded files keep their real age.
set -eu
[ -f /etc/backup.env ] && . /etc/backup.env

prefix=${1:?usage: prune.sh <bucket/prefix> [--dry-run]}
dry_run=${2:-}
keep_daily=${RETAIN_DAILY:-7}
keep_weekly=${RETAIN_WEEKLY:-4}
: "${S3_ENDPOINT:?}" "${S3_ACCESS_KEY:?}" "${S3_SECRET_KEY:?}"
export MC_HOST_offsite="${S3_ENDPOINT%%://*}://${S3_ACCESS_KEY}:${S3_SECRET_KEY}@${S3_ENDPOINT#*://}"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [prune] $*"; }

# One line per backup: "<timestamp> <day> <iso-week> <name>", newest first.
list=$(mc --quiet ls "offsite/$prefix/" | awk '{print $NF}' | grep '\.dump$' | while read -r f; do
  stamp=$(echo "$f" | sed -n 's/.*_\([0-9]\{8\}T[0-9]\{6\}Z\).*/\1/p')
  [ -n "$stamp" ] || continue
  day=${stamp%%T*}
  week=$(date -u -d "$(echo "$day" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')" +%G-W%V)
  echo "$stamp $day $week $f"
done | sort -r)

total=$(printf '%s\n' "$list" | grep -c . || true)
log "$prefix: $total backups found, policy keeps $keep_daily daily + $keep_weekly weekly"

printf '%s\n' "$list" | awk -v kd="$keep_daily" -v kw="$keep_weekly" '
  NF == 4 {
    reason = ""
    if (!($2 in days) && nd < kd) { days[$2] = 1; nd++; reason = "daily" }
    if (!($3 in weeks) && nw < kw) { weeks[$3] = 1; nw++; reason = reason (reason ? "+" : "") "weekly" }
    print (reason ? "KEEP " : "DELETE ") $4 (reason ? " (" reason ")" : "")
  }' > /tmp/prune-plan.txt

kept=$(grep -c '^KEEP' /tmp/prune-plan.txt || true)
deleted=$(grep -c '^DELETE' /tmp/prune-plan.txt || true)
cat /tmp/prune-plan.txt

if [ "$dry_run" = --dry-run ]; then
  log "dry run: would keep $kept, delete $deleted"
  exit 0
fi
grep '^DELETE' /tmp/prune-plan.txt | awk '{print $2}' | while read -r f; do
  mc --quiet rm "offsite/$prefix/$f" >/dev/null
  mc --quiet rm "offsite/$prefix/$f.meta.json" >/dev/null 2>&1 || true
done
log "kept $kept, deleted $deleted"
