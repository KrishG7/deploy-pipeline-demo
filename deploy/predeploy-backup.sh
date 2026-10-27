#!/usr/bin/env bash
# Usage: deploy/predeploy-backup.sh <environment> <tag about to be deployed>
#
# Takes a backup right before a deploy, so a release that changes the database
# can be undone by restoring it (docs/ROLLBACK.md). Fails the deploy if the
# backup fails. Skipped only on the very first deploy, when there is no
# database yet.
set -euo pipefail
env=${1:?usage: predeploy-backup.sh <environment> <tag>}
tag=${2:?usage: predeploy-backup.sh <environment> <tag>}
root=$(cd "$(dirname "$0")/.." && pwd)
dir=${DEPLOY_ENV_DIR:-$HOME/.deploy-pipeline-demo}

if [ ! -f "$dir/$env.release" ] || [ -z "$("$root/scripts/compose.sh" "$env" ps --status running -q backup 2>/dev/null)" ]; then
  echo "no running $env stack yet (first deploy): nothing to back up"
  exit 0
fi
current=$(sed -n 's/^IMAGE_TAG=//p' "$dir/$env.release")
echo "pre-deploy backup of $env (running $current, about to deploy $tag)"
"$root/scripts/compose.sh" "$env" exec -T backup /backup.sh predeploy "before-$tag"
