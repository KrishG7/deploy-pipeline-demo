#!/usr/bin/env bash
# Usage: scripts/disk-alert.sh [threshold-percent] [path]
#
# Emails an alert when disk use on <path> (default /) is above the threshold
# (default DISK_ALERT_THRESHOLD or 80). Meant to run from cron every 10 minutes:
#   */10 * * * * /srv/appointments/scripts/disk-alert.sh >> /var/log/disk-alert.log 2>&1
#
# Mail goes out over plain SMTP with curl, so no local mail server is needed.
# Settings (environment or monitoring/.env):
#   ALERT_SMTP_URL   smtp://host:port        (demo: smtp://127.0.0.1:1025, Mailpit)
#   ALERT_FROM       sender address
#   ALERT_TO         recipient address
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$root/monitoring/.env" ] && set -a && . "$root/monitoring/.env" && set +a

threshold=${1:-${DISK_ALERT_THRESHOLD:-80}}
path=${2:-/}
: "${ALERT_SMTP_URL:?}" "${ALERT_FROM:?}" "${ALERT_TO:?}"
host=$(hostname -s)
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

read -r size used avail pct mount < <(df -Ph "$path" | awk 'NR==2 {print $2, $3, $4, $5, $6}')
usage=${pct%\%}

echo "$now disk check on $host: $mount at ${usage}% used ($used of $size, $avail free), threshold ${threshold}%"
if [ "$usage" -le "$threshold" ]; then
  echo "$now OK: ${usage}% <= ${threshold}%, no alert sent"
  exit 0
fi

subject="[ALERT] Disk ${usage}% used on $host:$mount (threshold ${threshold}%)"
msg=$(mktemp)
trap 'rm -f "$msg"' EXIT
cat > "$msg" <<EOF
From: Disk monitor <$ALERT_FROM>
To: <$ALERT_TO>
Subject: $subject
Date: $(date -R 2>/dev/null || date)
Content-Type: text/plain; charset=utf-8

Disk usage on $host is above the alert threshold.

  Mount:      $mount
  Used:       $used of $size (${usage}%)
  Free:       $avail
  Threshold:  ${threshold}%
  Checked at: $now

Suggested first steps: docker system df; prune old images
(docker image prune -a --filter "until=168h"); check database and log sizes.
EOF

curl -fsS --url "$ALERT_SMTP_URL" --mail-from "$ALERT_FROM" --mail-rcpt "$ALERT_TO" --upload-file "$msg"
echo "$now ALERT SENT: \"$subject\" via $ALERT_SMTP_URL"
