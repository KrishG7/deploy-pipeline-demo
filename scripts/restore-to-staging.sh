#!/usr/bin/env bash
# Usage: scripts/restore-to-staging.sh <backup-file>
#   <backup-file> is a file name such as production_daily_20261027T101500Z.dump
#   (its folder in the bucket is worked out from the name) or a full path
#   inside the bucket such as production/daily/production_daily_....dump
#
# Restores a backup into STAGING (never production):
#   1. stop the staging api so nothing holds the database open
#   2. in the staging backup container: download, verify checksum, drop and
#      recreate the database, pg_restore, compare the row count with the count
#      recorded at backup time
#   3. start the api and wait for /health = ok
#   4. check the row count served by the API matches as well
# Prints the total time taken.
set -euo pipefail

arg=${1:?usage: restore-to-staging.sh <backup-file>}
root=$(cd "$(dirname "$0")/.." && pwd)
dir=${DEPLOY_ENV_DIR:-$HOME/.deploy-pipeline-demo}
compose() { "$root/scripts/compose.sh" staging "$@"; }
now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }
log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [restore-to-staging] $*"; }

case "$arg" in
  */*) object=$arg ;;
  *_*_*.dump) object="$(echo "$arg" | cut -d_ -f1)/$(echo "$arg" | cut -d_ -f2)/$arg" ;;
  *) echo "cannot work out the bucket path for '$arg'" >&2; exit 2 ;;
esac
case "$object" in *[!A-Za-z0-9._/-]*|*..*) echo "invalid backup path: $object" >&2; exit 2 ;; esac

port=$(sed -n 's/^HTTPS_PORT=//p' "$dir/staging.env" | tail -1)
domain=$(sed -n 's/^SITE_DOMAIN=//p' "$dir/staging.env" | tail -1)
base="https://$domain:$port"
ca="$dir/staging-caddy-root.crt"
curl_args=(-fsS --max-time 3)
[ -f "$ca" ] && curl_args+=(--cacert "$ca")

t0=$(now_ms)
log "restoring $object into staging"
log "staging before: $(curl "${curl_args[@]}" "$base/health" || echo unreachable)"

log "step 1/4: stopping staging api"
compose stop api 2>&1 | sed 's/^/    /'

log "step 2/4: download, verify, drop + recreate database, pg_restore"
t1=$(now_ms)
rc=0
out=$(compose exec -T backup /restore.sh "$object" 2>&1) || rc=$?
echo "$out" | sed 's/^/    /'
restore_ms=$(( $(now_ms) - t1 ))
if [ "$rc" -ne 0 ] || ! echo "$out" | grep -q 'row count check: OK'; then
  log "FAILED: restore step exited $rc"
  compose start api >/dev/null 2>&1 || true
  exit 1
fi
expected=$(compose exec -T backup psql -XAtc 'SELECT count(*) FROM appointments' | tr -d '\r')

log "step 3/4: starting staging api, waiting for /health"
compose start api 2>&1 | sed 's/^/    /'
healthy=""
for _ in $(seq 1 30); do
  body=$(curl "${curl_args[@]}" "$base/health" 2>/dev/null || true)
  if echo "$body" | grep -q '"status":"ok"'; then healthy=$body; break; fi
  sleep 2
done
[ -n "$healthy" ] || { log "FAILED: staging /health not ok after 60s"; exit 1; }
log "health: $healthy"

log "step 4/4: row count served by the API"
served=$(curl "${curl_args[@]}" "$base/api/appointments" | grep -o '"id":' | wc -l | tr -d ' ')
log "API returns $served appointments, database has $expected (recorded at backup time and checked in step 2)"
[ "$served" = "$expected" ] || { log "FAILED: API count differs"; exit 1; }

total_ms=$(( $(now_ms) - t0 ))
log "RESULT: restore OK. restore step (download, verify, drop, pg_restore, count) ${restore_ms} ms; total time $(awk -v ms="$total_ms" 'BEGIN{printf "%.1f", ms/1000}') s (${total_ms} ms)"
