# Claims in deploy-proposal-sample.pdf

Every factual statement and number in the PDF, with the file and line that backs it. Generated and checked by `pdf/claims.mjs`, which also confirms that every number in the PDF text is covered by a row here, and that the PDF text contains no internal paths, usernames, emails or tokens.

| Page | Claim (as worded in the PDF) | Evidence | Line | Evidence text |
|---|---|---|---|---|
| 1 | Node.js 20, PostgreSQL 16 | `api/Dockerfile` | 10 | `FROM node:20-alpine AS runtime` |
| 1 | Node.js 20, PostgreSQL 16 | `deploy/compose.yml` | 60 | `image: postgres:16` |
| 1 | One Compose file run as two projects | `evidence/07-deploy-v1.0.0-full-run.txt` | 29 | `[deploy:staging] HEALTHY after 18s` |
| 1 | One Compose file run as two projects | `evidence/07-deploy-v1.0.0-full-run.txt` | 38 | `[deploy:production] HEALTHY after 12s` |
| 1 | deploys the identical image (same | `evidence/07-deploy-v1.0.0-full-run.txt` | 36 | `[deploy:production] api image ghcr.io/<repo-owner>/deploy-pipeline-demo-api:sha-6b743c0 is version 1.0.0 (ghcr.io/<repo-owner>/deploy-pipeline-demo-api@sha256:4af6a5e4` |
| 1 | A backup runs automatically right before each production deploy | `evidence/22-deploy-v1.1.0-full-run.txt` | 27 | `starting predeploy backup` |
| 1 | verify the certificate against the issuing CA | `deploy/deploy.sh` | 60 | `curl_args+=(--cacert "$ca")` |
| 1 | answered 200 again in under 1 | `evidence/16-app-crash-docker-restart.txt` | 9 | `06:44:33.576Z kill -9 the node process` |
| 1 | answered 200 again in under 1 | `evidence/16-app-crash-docker-restart.txt` | 11 | `06:44:34.302Z /health=200 state=running health=starting restarts=1` |
| 1 | 3 allowed and 4 denied actions | `evidence/10-bucket-access-controls.txt` | 9 | `staging user \| delete a production backup \| DENIED` |
| 1 | firewall 22/80/443 | `docs/SERVER-HARDENING.md` | 62 | `ufw allow 443/tcp` |
| 1 | 60 daily backups in, 9 kept (7 daily plus 4 weekly), 51 removed | `evidence/12-retention-prune-log.txt` | 62 | `kept 9, deleted 51` |
| 1 | row count (28 of | `evidence/14-restore-to-staging.log` | 20 | `appointments rows after restore: 28 (expected 28)` |
| 1 | Total time 3.5 s | `evidence/14-restore-to-staging.log` | 30 | `total time 3.5 s (3501 ms)` |
| 1 | emailed DOWN when production went down and UP when it came back | `evidence/18-app-outage-kuma-alerts.txt` | 15 | `[UP] production /health` |
| 1 | emailed when usage passed its threshold and stayed quiet below it | `evidence/20-disk-alert-normal-threshold.txt` | 4 | `no alert sent` |
| 1 | Released v1.0.0, then v1.1.0 | `evidence/24-rollback-run.txt` | 29 | `sha-d383577 1.1.0` |
| 1 | 64.4 s from approval to healthy | `evidence/23-rollback-before-during-after-health.txt` | 68 | `HEALTHY on 1.0.0; approval to healthy: 64.4 s` |
| 1 | 37 | `verification.md` | 43 | `\| 37 \|` |
| 1 | 19.1 s | `evidence/21-production-v1.1.0-approval-to-healthy.txt` | 25 | `HEALTHY on 1.1.0; approval to healthy: 19.1 s` |
| 1 | 32 PASS, 1 FAIL and 4 NOT RUN | `verification.md` | 36 | `\| FAIL \|` |
| 1 | 32 PASS, 1 FAIL and 4 NOT RUN | `verification.md` | 7 | `\| PASS \|` |
| 1 | 32 PASS, 1 FAIL and 4 NOT RUN | `verification.md` | 37 | `\| NOT RUN \|` |
| 2 | sha-d383577 | `evidence/22-deploy-v1.1.0-full-run.txt` | 18 | `deploying tag sha-d383577` |
| 2 | within 60 seconds | `deploy/deploy.sh` | 16 | `timeout=${HEALTH_TIMEOUT:-60}` |
| 2 | the API image digest was identical in both environments | `evidence/22-deploy-v1.1.0-full-run.txt` | 31 | `[deploy:production] api image ghcr.io/<repo-owner>/deploy-pipeline-demo-api:sha-d383577 is version 1.1.0 (ghcr.io/<repo-owner>/deploy-pipeline-demo-api@sha256:59d7de61` |
| 2 | {"state":"approved","environments": | `evidence/22-deploy-v1.1.0-full-run.txt` | 8 | `"environments":["production"],"state":"approved"` |
| 2 | 06:53:35 WAITING FOR REVIEW | `evidence/21-production-v1.1.0-approval-to-healthy.txt` | 3 | `06:53:35.441Z WAITING FOR REVIEW` |
| 2 | 06:54:42 APPROVED | `evidence/21-production-v1.1.0-approval-to-healthy.txt` | 5 | `06:54:42.673Z APPROVED` |
| 2 | 06:55:01 HEALTHY on 1.1.0 | `evidence/21-production-v1.1.0-approval-to-healthy.txt` | 25 | `06:55:01.764Z HEALTHY on 1.1.0` |
| 2 | the pre-deploy backup (28 rows) ran first | `evidence/22-deploy-v1.1.0-full-run.txt` | 28 | `appointments rows=28` |
| 2 | About 47 s of this was the runner | `evidence/24-rollback-run.txt` | 4 | `Roll back production to v1.0.0: started=2026-10-27T06:57:45Z` |
| 2 | About 47 s of this was the runner | `evidence/24-rollback-run.txt` | 13 | `2026-10-27T06:58:32Z Current runner version` |
| 2 | 12 s (06:58:40 to 06:58:52 UTC) | `evidence/24-rollback-run.txt` | 17 | `06:58:40Z [deploy:production] deploying tag v1.0.0` |
| 2 | 12 s (06:58:40 to 06:58:52 UTC) | `evidence/24-rollback-run.txt` | 21 | `06:58:52Z [deploy:production] HEALTHY after 10s` |
| 2 | 58 requests, all answered: 57 on 1.1.0, then 1.0.0 | `evidence/23-rollback-before-during-after-health.txt` | 67 | `DURING: {"status":"ok","version":"1.0.0"` |
| 2 | sha256:4af6a5e4 | `evidence/24-rollback-run.txt` | 10 | `"sha256:4af6a5e49b2dd137eb24ec461afecdd91ef6cd5dae978847ce847f25bf8d7bfa"` |
| 2 | rows (28) and | `evidence/24-rollback-run.txt` | 25 | `production rows after rollback: 28` |
| 2 | Production page footer after the v1.1.0 release | `verification.md` | 35 | `footer "v1.1.0. New in 1.1: bookings open 7 days a week." then "v1.0.0"` |
| 2 | The same footer after the rollback to v1.0.0 | `verification.md` | 35 | `evidence/screenshots/07c-app-production-v1.0.0-after-rollback.png` |
| 3 | every day at 02:00 UTC | `evidence/08-production-manual-backup.txt` | 15 | `0 2 * * * /backup.sh daily` |
| 3 | production_daily_20261027T062642Z.dump | `evidence/08-production-manual-backup.txt` | 9 | `uploaded production_daily_20261027T062642Z.dump` |
| 3 | backups started at 06:27:00 and 06:28:00 | `evidence/09-cron-schedule-fires.txt` | 10 | `2026-10-27T06:28:00Z [backup:staging] starting daily backup` |
| 3 | from 29 August to 27 October 2026 | `evidence/11-retention-before.txt` | 2 | `production_daily_20260829T020000Z.dump` |
| 3 | production_daily_20260829T020000Z.dump production_daily_20260830T020000Z.dump production_daily_20260831T020000Z.dump | `evidence/11-retention-before.txt` | 4 | `production_daily_20260831T020000Z.dump` |
| 3 | production_daily_20261025T020000Z.dump production_daily_20261026T020000Z.dump production_daily_20261027T020000Z.dump | `evidence/11-retention-before.txt` | 61 | `production_daily_20261027T020000Z.dump` |
| 3 | ... 54 more, one per day ... | `evidence/11-retention-before.txt` | 1 | `BEFORE pruning: 60 dummy backups` |
| 3 | production_daily_20261021 Wed week 43 production_daily_20261022 Thu week 43 production_daily_20261023 Fri week 43 production_daily_20261024 Sat week 43 production_daily_20261025 Sun week 43 production_daily_20261026 Mon week 44 production_daily_20261027 Tue week 44 | `evidence/13-retention-after.txt` | 10 | `production_daily_20261027T020000Z.dump  Tue 2026-10-27 ISO-week 2026-W44` |
| 3 | restoring production/manual/production_manual_20261027T063003Z.dump into staging | `evidence/14-restore-to-staging.log` | 9 | `restoring production/manual/production_manual_20261027T063003Z.dump into staging` |
| 3 | total time 3.5 s (3501 ms) | `evidence/14-restore-to-staging.log` | 30 | `total time 3.5 s (3501 ms)` |
| 3 | 60 before, 9 after, 51 deleted | `evidence/12-retention-prune-log.txt` | 1 | `60 backups found` |
| 3 | # AFTER pruning (7 daily + 4 weekly): 9 left | `evidence/13-retention-after.txt` | 1 | `AFTER pruning (7 daily + 4 weekly): 9 backups left` |
| 3 | production_daily_20261011 Sun week 41 | `evidence/13-retention-after.txt` | 2 | `production_daily_20261011T020000Z.dump  Sun 2026-10-11 ISO-week 2026-W41` |
| 3 | production_daily_20261018 Sun week 42 | `evidence/13-retention-after.txt` | 3 | `production_daily_20261018T020000Z.dump  Sun 2026-10-18 ISO-week 2026-W42` |
| 3 | Staging had 25 rows | `evidence/14-restore-to-staging.log` | 2 | `staging rows before: 25` |
| 3 | including three entered through the live API | `evidence/08-production-manual-backup.txt` | 5 | `production rows now: 28` |
| 3 | rows at backup time: 28 | `evidence/14-restore-to-staging.log` | 17 | `rows at backup time: 28` |
| 3 | API returns 28 appointments, database has 28 | `evidence/14-restore-to-staging.log` | 29 | `API returns 28 appointments, database has 28` |
| 3 | list own backups | `evidence/10-bucket-access-controls.txt` | 3 | `production user \| list own prefix production/daily \| ALLOWED` |
| 3 | list or write staging backups | `evidence/10-bucket-access-controls.txt` | 5 | `production user \| write into staging prefix \| DENIED` |
| 3 | list and read production backups | `evidence/10-bucket-access-controls.txt` | 7 | `staging user \| read a production backup (needed for restore) \| ALLOWED` |
| 3 | write or delete production backups | `evidence/10-bucket-access-controls.txt` | 8 | `staging user \| write into production prefix \| DENIED` |
| 4 | every 20 seconds | `monitoring/kuma-setup.mjs` | 96 | `interval: 20,` |
| 4 | Stopped 06:48:55 UTC, DOWN email 06:49:01 | `evidence/18-app-outage-kuma-alerts.txt` | 8 | `2026-10-27T06:49:01.863Z \| [DOWN] production /health` |
| 4 | Started again 06:49:02, UP email 06:49:21 | `evidence/18-app-outage-kuma-alerts.txt` | 15 | `2026-10-27T06:49:21.862Z \| [UP] production /health` |
| 4 | System disk at 36%: alert sent | `evidence/19-disk-alert-low-threshold.txt` | 4 | `ALERT SENT: "[ALERT] Disk 36% used on demo-mac:/ (threshold 30%)"` |
| 4 | System disk at 36%: no alert | `evidence/20-disk-alert-normal-threshold.txt` | 4 | `OK: 36% <= 80%, no alert sent` |
| 4 | data disk really was at 89% | `evidence/20-disk-alert-normal-threshold.txt` | 10 | `ALERT SENT: "[ALERT] Disk 89% used on demo-mac:/System/Volumes/Data (threshold 80%)"` |
| 4 | plan for about 30 to 40 | `docs/MIGRATION-PLAN.md` | 41 | `**about 30 to 40 min**` |
| 4 | Keep the old server for 7 days | `docs/MIGRATION-PLAN.md` | 63 | `Don't delete or change the old server for 7 days` |
| 4 | backup kept for 30 days | `docs/MIGRATION-PLAN.md` | 64 | `Keep the final dump from the window for at least 30 days` |
| 4 | lowered two days before | `docs/MIGRATION-PLAN.md` | 27 | `at least 48 hours before the window` |

Check result: all 72 claims found in the PDF and in their evidence; 72 distinct numbers in the PDF text, none without a claim; no internal paths, usernames, emails or tokens.
