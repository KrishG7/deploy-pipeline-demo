#!/bin/sh
# Installs the cron schedule and runs busybox crond in the foreground.
set -eu

: "${BACKUP_ENV:?BACKUP_ENV must be set (staging or production)}"
: "${BACKUP_SCHEDULE:=0 2 * * *}"

# busybox crond starts jobs with an empty environment, so hand the job the
# container's settings through a root-only file.
env | grep -E '^(PG|S3_|BACKUP_|RETAIN_|TZ=)' | sed 's/^/export /; s/=/="/; s/$/"/' > /etc/backup.env
chmod 600 /etc/backup.env

echo "$BACKUP_SCHEDULE /backup.sh daily > /proc/1/fd/1 2>&1" > /etc/crontabs/root
echo "backup sidecar for $BACKUP_ENV: schedule '$BACKUP_SCHEDULE' (UTC), retention ${RETAIN_DAILY:-7} daily / ${RETAIN_WEEKLY:-4} weekly"
exec crond -f -l 6
