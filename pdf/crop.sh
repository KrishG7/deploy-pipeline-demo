#!/usr/bin/env bash
# Crops the evidence screenshots for the PDF (macOS sips). Output: pdf/build/.
# Cropping only removes surrounding page chrome; nothing is edited.
set -euo pipefail
cd "$(dirname "$0")/.."
S=evidence/screenshots B=pdf/build
mkdir -p "$B"
for f in 01-actions-staging-deployed-production-waiting 03-actions-production-deploy-completed 04-actions-rollback-run; do
  sips -c 900 1830 --cropOffset 420 700 "$S/$f.png" --out "$B/$f.png" >/dev/null
done
sips -c 1320 2520 --cropOffset 150 20 "$S/05-uptime-kuma-dashboard.png" --out "$B/05.png" >/dev/null
sips -c 470 2150 --cropOffset 120 410 "$S/06-mailpit-inbox-alerts.png" --out "$B/06.png" >/dev/null
sips -c 180 1500 --cropOffset 1975 380 "$S/07b-app-production-v1.1.0.png" --out "$B/07b-app-production-v1.1.0-footer.png" >/dev/null
sips -c 180 1500 --cropOffset 1975 380 "$S/07c-app-production-v1.0.0-after-rollback.png" --out "$B/07c-app-production-v1.0.0-after-rollback-footer.png" >/dev/null
echo "cropped into $B"
