#!/usr/bin/env bash
# Usage: IMAGE_PREFIX=... POSTGRES_PASSWORD=... S3_SECRET_KEY=... deploy/write-env.sh <staging|production>
#
# Builds the runtime env file for one environment from the committed template
# plus secrets taken from the environment (GitHub environment secrets in CI).
# The file is written outside the repository, readable only by its owner.
set -euo pipefail

env=${1:?usage: write-env.sh <staging|production>}
case "$env" in staging|production) ;; *) echo "unknown environment: $env" >&2; exit 2 ;; esac
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is not set}"
: "${S3_SECRET_KEY:?S3_SECRET_KEY is not set}"

root=$(cd "$(dirname "$0")/.." && pwd)
dir=${DEPLOY_ENV_DIR:-$HOME/.deploy-pipeline-demo}
mkdir -p "$dir"
chmod 700 "$dir"

# IMAGE_PREFIX (ghcr.io/<owner>/<repo>) comes from the workflow, so the owner is
# not hard-coded in the repository.
: "${IMAGE_PREFIX:?IMAGE_PREFIX is not set (for example ghcr.io/<owner>/deploy-pipeline-demo)}"
case "$IMAGE_PREFIX" in *'<'*|*[A-Z]*) echo "IMAGE_PREFIX must be a real, lowercase image path" >&2; exit 2 ;; esac

umask 077
{
  grep -vE '^[[:space:]]*(#|$)|^IMAGE_PREFIX=' "$root/deploy/.env.$env.example"
  printf 'IMAGE_PREFIX=%s\n' "$IMAGE_PREFIX"
  printf 'POSTGRES_PASSWORD=%s\n' "$POSTGRES_PASSWORD"
  printf 'S3_SECRET_KEY=%s\n' "$S3_SECRET_KEY"
} > "$dir/$env.env.tmp"
mv "$dir/$env.env.tmp" "$dir/$env.env"
echo "wrote $env env file ($(grep -c . "$dir/$env.env") variables, mode 600)"
