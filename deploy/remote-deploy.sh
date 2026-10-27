#!/usr/bin/env bash
# FOR REAL SERVERS, NOT RUN IN THIS DEMO.
#
# The SSH version of the deploy step. In the demo the GitHub runner sits on the
# same machine as the stacks and calls deploy/deploy.sh directly. With two real
# cloud servers, a GitHub-hosted runner deploys over SSH instead:
#
#   deploy/remote-deploy.sh <staging|production> <image tag>
#
# Expects (from GitHub environment secrets, per environment):
#   DEPLOY_HOST         server hostname
#   DEPLOY_USER         the unprivileged "deploy" user (docs/SERVER-HARDENING.md)
#   DEPLOY_SSH_KEY      private key whose public half is in the deploy user's
#                       authorized_keys
#   DEPLOY_KNOWN_HOSTS  the server's host key line (ssh-keyscan once, verify, store)
#   POSTGRES_PASSWORD, S3_SECRET_KEY, IMAGE_PREFIX (set by the workflow)
#
# The server has a checkout of this repository's deploy/ and scripts/ folders at
# /srv/appointments, and the deploy user is in the docker group.
set -euo pipefail

env=${1:?usage: remote-deploy.sh <staging|production> <tag>}
tag=${2:?usage: remote-deploy.sh <staging|production> <tag>}
case "$tag" in *[!A-Za-z0-9._-]*) echo "invalid tag" >&2; exit 2 ;; esac
: "${DEPLOY_HOST:?}" "${DEPLOY_USER:?}" "${DEPLOY_SSH_KEY:?}" "${DEPLOY_KNOWN_HOSTS:?}"
: "${POSTGRES_PASSWORD:?}" "${S3_SECRET_KEY:?}" "${IMAGE_PREFIX:?}"

ssh_dir=$(mktemp -d)
trap 'rm -rf "$ssh_dir"' EXIT
umask 077
printf '%s\n' "$DEPLOY_SSH_KEY" > "$ssh_dir/key"
printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > "$ssh_dir/known_hosts"
ssh_opts=(-i "$ssh_dir/key" -o UserKnownHostsFile="$ssh_dir/known_hosts"
          -o StrictHostKeyChecking=yes -o BatchMode=yes -o ConnectTimeout=10)
target="$DEPLOY_USER@$DEPLOY_HOST"

# 1. Update the deploy scripts on the server to this commit's version.
git archive --format=tar HEAD deploy scripts | ssh "${ssh_opts[@]}" "$target" \
  'tar -x -C /srv/appointments'

# 2. Write the env file on the server from secrets (sent on stdin, never on the
#    command line, so they do not show up in the server's process list).
printf 'POSTGRES_PASSWORD=%s\nS3_SECRET_KEY=%s\nIMAGE_PREFIX=%s\n' "$POSTGRES_PASSWORD" "$S3_SECRET_KEY" "$IMAGE_PREFIX" |
  ssh "${ssh_opts[@]}" "$target" "set -a; . /dev/stdin; set +a; /srv/appointments/deploy/write-env.sh $env"

# 3. Pre-deploy backup (production only), then the same deploy script the demo uses.
if [ "$env" = production ]; then
  ssh "${ssh_opts[@]}" "$target" "/srv/appointments/deploy/predeploy-backup.sh $env $tag"
fi
ssh "${ssh_opts[@]}" "$target" "/srv/appointments/deploy/deploy.sh $env $tag"
