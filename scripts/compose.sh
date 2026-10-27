#!/usr/bin/env bash
# Usage: scripts/compose.sh <staging|production> <docker compose arguments...>
#
# Runs docker compose for one environment's project with its env file and the
# currently deployed image tag (the .release file written by deploy/deploy.sh).
set -euo pipefail

env=${1:?usage: compose.sh <staging|production> <compose args...>}
shift
case "$env" in staging|production) ;; *) echo "unknown environment: $env" >&2; exit 2 ;; esac

root=$(cd "$(dirname "$0")/.." && pwd)
dir=${DEPLOY_ENV_DIR:-$HOME/.deploy-pipeline-demo}
[ -f "$dir/$env.env" ] || { echo "missing $dir/$env.env (run deploy/write-env.sh $env)" >&2; exit 2; }

args=(--env-file "$dir/$env.env")
[ -f "$dir/$env.release" ] && args+=(--env-file "$dir/$env.release")
exec docker compose -p "$env" -f "$root/deploy/compose.yml" "${args[@]}" "$@"
