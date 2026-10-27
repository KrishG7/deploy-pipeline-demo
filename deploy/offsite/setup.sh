#!/usr/bin/env bash
# Usage: STAGING_S3_SECRET=... PRODUCTION_S3_SECRET=... deploy/offsite/setup.sh
#
# Creates the "backups" bucket and one least-privilege user per environment:
#   production-backup: read/write  backups/production/*
#   staging-backup:    read/write  backups/staging/*, read-only backups/production/*
#                      (so a production dump can be restored into staging)
# Neither environment can touch the other's backups or delete outside its prefix.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
: "${STAGING_S3_SECRET:?}" "${PRODUCTION_S3_SECRET:?}"

mc() {
  docker compose -p offsite --env-file "$here/.env" -f "$here/compose.yml" exec -T \
    -e STAGING_S3_SECRET -e PRODUCTION_S3_SECRET minio sh -c \
    'mc alias set local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && '"$1"
}

mc 'mc mb --ignore-existing local/backups'

mc 'cat > /tmp/production-backup.json <<EOF
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["s3:ListBucket"],"Resource":["arn:aws:s3:::backups"],"Condition":{"StringLike":{"s3:prefix":["production/*"]}}},
 {"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:DeleteObject"],"Resource":["arn:aws:s3:::backups/production/*"]}]}
EOF
cat > /tmp/staging-backup.json <<EOF
{"Version":"2012-10-17","Statement":[
 {"Effect":"Allow","Action":["s3:ListBucket"],"Resource":["arn:aws:s3:::backups"],"Condition":{"StringLike":{"s3:prefix":["staging/*","production/*"]}}},
 {"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:DeleteObject"],"Resource":["arn:aws:s3:::backups/staging/*"]},
 {"Effect":"Allow","Action":["s3:GetObject"],"Resource":["arn:aws:s3:::backups/production/*"]}]}
EOF
mc admin policy create local production-backup /tmp/production-backup.json >/dev/null 2>&1 || true
mc admin policy create local staging-backup /tmp/staging-backup.json >/dev/null 2>&1 || true
mc admin user add local production-backup "$PRODUCTION_S3_SECRET"
mc admin user add local staging-backup "$STAGING_S3_SECRET"
mc admin policy attach local production-backup --user production-backup >/dev/null 2>&1 || true
mc admin policy attach local staging-backup --user staging-backup >/dev/null 2>&1 || true
mc admin user info local production-backup
mc admin user info local staging-backup' | grep -E "AccessKey|PolicyName"
