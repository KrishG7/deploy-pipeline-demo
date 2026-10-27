#!/usr/bin/env bash
# Usage: scripts/watch-release.sh <run id> <expected version> [environment]
# Evidence helper: polls the run's pending production approval and the
# environment's /health once a second, printing UTC timestamps, so the time
# from approval to healthy can be measured from the outside.
set -uo pipefail
run=${1:?run id}; want=${2:?expected version}; env=${3:-production}
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
dir=${DEPLOY_ENV_DIR:-$HOME/.deploy-pipeline-demo}
if [ "$env" = production ]; then url=https://app.localhost/health; else url=https://staging.localhost:8443/health; fi
ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time*1000'; }
ts() { perl -MTime::HiRes=time -MPOSIX=strftime -e '$t=time; printf "%s.%03dZ\n", strftime("%Y-%m-%dT%H:%M:%S", gmtime($t)), ($t-int($t))*1000'; }
health() { local ca="$dir/$env-caddy-root.crt" a=(-sS --max-time 2); [ -f "$ca" ] && a+=(--cacert "$ca"); curl "${a[@]}" "$url" 2>&1 | head -c 200; }
echo "$(ts) watching run $run, waiting for approval; expecting $env /health version $want"
echo "$(ts) BEFORE: $(health)"
# Wait for the production job to be waiting for review, then for it to be approved.
until [ "$(gh api "repos/$repo/actions/runs/$run/pending_deployments" --jq length 2>/dev/null || echo 0)" -gt 0 ]; do sleep 2; done
echo "$(ts) WAITING FOR REVIEW (pending deployment to $env)"
echo "$(ts) BEFORE (while waiting): $(health)"
approved=""
while :; do
  n=$(gh api "repos/$repo/actions/runs/$run/pending_deployments" --jq length 2>/dev/null || echo "?")
  if [ "$n" = 0 ]; then approved=$(ms); echo "$(ts) APPROVED (no pending deployment left)"; break; fi
  sleep 1
done
while :; do
  h=$(health)
  echo "$(ts) DURING: $h"
  if echo "$h" | grep -q '"status":"ok"' && echo "$h" | grep -q "\"version\":\"$want\""; then
    echo "$(ts) HEALTHY on $want; approval to healthy: $(awk -v d=$(( $(ms) - approved )) 'BEGIN{printf "%.1f", d/1000}') s"
    break
  fi
  sleep 1
done
sleep 5; echo "$(ts) AFTER: $(health)"
