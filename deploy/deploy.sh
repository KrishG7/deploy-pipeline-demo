#!/usr/bin/env bash
# Usage: deploy/deploy.sh <staging|production> <image tag>
#
# Deploys an already-built image tag to one environment on THIS host:
#   1. record the tag as the environment's release
#   2. pull that tag
#   3. docker compose up -d
#   4. wait until /health reports status ok AND the version baked into the image
# Exits non-zero (failing the GitHub job) if that does not happen within
# HEALTH_TIMEOUT seconds (default 60). Nothing is built here.
set -euo pipefail

env=${1:?usage: deploy.sh <staging|production> <image tag>}
tag=${2:?usage: deploy.sh <staging|production> <image tag>}
case "$tag" in *[!A-Za-z0-9._-]*) echo "invalid tag: $tag" >&2; exit 2 ;; esac
timeout=${HEALTH_TIMEOUT:-60}

root=$(cd "$(dirname "$0")/.." && pwd)
dir=${DEPLOY_ENV_DIR:-$HOME/.deploy-pipeline-demo}
compose() { "$root/scripts/compose.sh" "$env" "$@"; }
log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [deploy:$env] $*"; }
envval() { sed -n "s/^$1=//p" "$dir/$env.env" | tail -1; }

prefix=$(envval IMAGE_PREFIX)
domain=$(envval SITE_DOMAIN)
port=$(envval HTTPS_PORT)
url="https://$domain$([ "$port" = 443 ] || echo ":$port")/health"

previous=$(sed -n 's/^IMAGE_TAG=//p' "$dir/$env.release" 2>/dev/null || true)
log "deploying tag $tag (previous: ${previous:-none})"

umask 077
echo "IMAGE_TAG=$tag" > "$dir/$env.release"

if [ "${DEPLOY_SKIP_PULL:-}" = 1 ]; then
  log "DEPLOY_SKIP_PULL=1: using images already on this host (local testing only)"
else
  log "pulling images"
  compose pull --quiet api web backup
fi
expected=$(docker image inspect "$prefix-api:$tag" --format '{{ index .Config.Labels "org.opencontainers.image.version" }}')
digest=$(docker image inspect "$prefix-api:$tag" --format '{{ index .RepoDigests 0 }}' 2>/dev/null || echo "local build")
log "api image $prefix-api:$tag is version $expected ($digest)"

start=$(date +%s)
compose up -d --remove-orphans
log "containers started, waiting up to ${timeout}s for $url to report version $expected"

# With "tls internal" the certificate comes from this stack's Caddy CA, so
# trust exactly that CA (no -k). On real servers the Let's Encrypt chain is
# already trusted by the system.
curl_args=(-fsS --max-time 3)
if [ -n "$(envval CADDY_TLS)" ]; then
  ca="$dir/$env-caddy-root.crt"
  for _ in $(seq 1 20); do
    compose exec -T caddy cat /data/caddy/pki/authorities/local/root.crt > "$ca.tmp" 2>/dev/null && break
    sleep 1
  done
  mv "$ca.tmp" "$ca"
  curl_args+=(--cacert "$ca")
fi

body=""
while [ $(( $(date +%s) - start )) -lt "$timeout" ]; do
  body=$(curl "${curl_args[@]}" "$url" 2>/dev/null || true)
  if echo "$body" | grep -q '"status":"ok"' && echo "$body" | grep -q "\"version\":\"$expected\""; then
    elapsed=$(( $(date +%s) - start ))
    log "HEALTHY after ${elapsed}s: $body"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $tag $expected" >> "$dir/$env.history"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      printf '### %s deployed\n\n| | |\n|---|---|\n| tag | `%s` |\n| version | %s |\n| image | `%s` |\n| healthy after | %ss |\n' \
        "$env" "$tag" "$expected" "$digest" "$elapsed" >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 0
  fi
  sleep 2
done

log "FAILED: $url did not report version $expected within ${timeout}s; last response: ${body:-<none>}"
compose ps
compose logs --tail 30 api
exit 1
