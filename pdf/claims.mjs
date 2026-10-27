// Every factual claim in the PDF, with the evidence that backs it.
//
//   node claims.mjs          writes ../CLAIMS.md and checks the PDF:
//     1. each claim's evidence text is really in the evidence file (line found)
//     2. each claim's wording is really in the PDF (pdftotext)
//     3. every number in the PDF text belongs to some claim (or is layout:
//        page numbers, list numbers)
//     4. the PDF text has no internal paths, usernames, emails or tokens
// Exits non-zero if any check fails.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');

// pdf: text as it appears in the PDF; file + find: where it is proven.
const claims = [
  // Page 1
  { p: 1, pdf: 'Node.js 20, PostgreSQL 16', file: 'api/Dockerfile', find: 'FROM node:20-alpine AS runtime' },
  { p: 1, pdf: 'Node.js 20, PostgreSQL 16', file: 'deploy/compose.yml', find: 'image: postgres:16' },
  { p: 1, pdf: 'One Compose file run as two projects', file: 'evidence/07-deploy-v1.0.0-full-run.txt', find: '[deploy:staging] HEALTHY after 18s' },
  { p: 1, pdf: 'One Compose file run as two projects', file: 'evidence/07-deploy-v1.0.0-full-run.txt', find: '[deploy:production] HEALTHY after 12s' },
  { p: 1, pdf: 'deploys the identical image (same', file: 'evidence/07-deploy-v1.0.0-full-run.txt', find: '[deploy:production] api image ghcr.io/<repo-owner>/deploy-pipeline-demo-api:sha-6b743c0 is version 1.0.0 (ghcr.io/<repo-owner>/deploy-pipeline-demo-api@sha256:4af6a5e4' },
  { p: 1, pdf: 'A backup runs automatically right before each production deploy', file: 'evidence/22-deploy-v1.1.0-full-run.txt', find: 'starting predeploy backup' },
  { p: 1, pdf: 'verify the certificate against the issuing CA', file: 'deploy/deploy.sh', find: 'curl_args+=(--cacert "$ca")' },
  { p: 1, pdf: 'answered 200 again in under 1', file: 'evidence/16-app-crash-docker-restart.txt', find: '06:44:33.576Z kill -9 the node process' },
  { p: 1, pdf: 'answered 200 again in under 1', file: 'evidence/16-app-crash-docker-restart.txt', find: '06:44:34.302Z /health=200 state=running health=starting restarts=1' },
  { p: 1, pdf: '3 allowed and 4 denied actions', file: 'evidence/10-bucket-access-controls.txt', find: 'staging user | delete a production backup | DENIED' },
  { p: 1, pdf: 'firewall 22/80/443', file: 'docs/SERVER-HARDENING.md', find: 'ufw allow 443/tcp' },
  { p: 1, pdf: '60 daily backups in, 9 kept (7 daily plus 4 weekly), 51 removed', file: 'evidence/12-retention-prune-log.txt', find: 'kept 9, deleted 51' },
  { p: 1, pdf: 'row count (28 of', file: 'evidence/14-restore-to-staging.log', find: 'appointments rows after restore: 28 (expected 28)' },
  { p: 1, pdf: 'Total time 3.5 s', file: 'evidence/14-restore-to-staging.log', find: 'total time 3.5 s (3501 ms)' },
  { p: 1, pdf: 'emailed DOWN when production went down and UP when it came back', file: 'evidence/18-app-outage-kuma-alerts.txt', find: '[UP] production /health' },
  { p: 1, pdf: 'emailed when usage passed its threshold and stayed quiet below it', file: 'evidence/20-disk-alert-normal-threshold.txt', find: 'no alert sent' },
  { p: 1, pdf: 'Released v1.0.0, then v1.1.0', file: 'evidence/24-rollback-run.txt', find: 'sha-d383577 1.1.0' },
  { p: 1, pdf: '64.4 s from approval to healthy', file: 'evidence/23-rollback-before-during-after-health.txt', find: 'HEALTHY on 1.0.0; approval to healthy: 64.4 s' },
  { p: 1, pdf: '37', file: 'verification.md', find: '| 37 |' },
  { p: 1, pdf: '19.1 s', file: 'evidence/21-production-v1.1.0-approval-to-healthy.txt', find: 'HEALTHY on 1.1.0; approval to healthy: 19.1 s' },
  { p: 1, pdf: '32 PASS, 1 FAIL and 4 NOT RUN', file: 'verification.md', find: '| FAIL |' },
  { p: 1, pdf: '32 PASS, 1 FAIL and 4 NOT RUN', file: 'verification.md', find: '| NOT RUN |', count: { pattern: '| NOT RUN |', equals: 4 } },
  // Page 2
  { p: 2, pdf: 'sha-d383577', file: 'evidence/22-deploy-v1.1.0-full-run.txt', find: 'deploying tag sha-d383577' },
  { p: 2, pdf: 'within 60 seconds', file: 'deploy/deploy.sh', find: 'timeout=${HEALTH_TIMEOUT:-60}' },
  { p: 2, pdf: 'the API image digest was identical in both environments', file: 'evidence/22-deploy-v1.1.0-full-run.txt', find: '[deploy:production] api image ghcr.io/<repo-owner>/deploy-pipeline-demo-api:sha-d383577 is version 1.1.0 (ghcr.io/<repo-owner>/deploy-pipeline-demo-api@sha256:59d7de61' },
  { p: 2, pdf: '{"state":"approved","environments":', file: 'evidence/22-deploy-v1.1.0-full-run.txt', find: '"environments":["production"],"state":"approved"' },
  { p: 2, pdf: '06:53:35 WAITING FOR REVIEW', file: 'evidence/21-production-v1.1.0-approval-to-healthy.txt', find: '06:53:35.441Z WAITING FOR REVIEW' },
  { p: 2, pdf: '06:54:42 APPROVED', file: 'evidence/21-production-v1.1.0-approval-to-healthy.txt', find: '06:54:42.673Z APPROVED' },
  { p: 2, pdf: '06:55:01 HEALTHY on 1.1.0', file: 'evidence/21-production-v1.1.0-approval-to-healthy.txt', find: '06:55:01.764Z HEALTHY on 1.1.0' },
  { p: 2, pdf: 'the pre-deploy backup (28 rows) ran first', file: 'evidence/22-deploy-v1.1.0-full-run.txt', find: 'appointments rows=28' },
  { p: 2, pdf: 'About 47 s of this was the runner', file: 'evidence/24-rollback-run.txt', find: 'Roll back production to v1.0.0: started=2026-10-27T06:57:45Z' },
  { p: 2, pdf: 'About 47 s of this was the runner', file: 'evidence/24-rollback-run.txt', find: "2026-10-27T06:58:32Z Current runner version" },
  { p: 2, pdf: '12 s (06:58:40 to 06:58:52 UTC)', file: 'evidence/24-rollback-run.txt', find: '06:58:40Z [deploy:production] deploying tag v1.0.0' },
  { p: 2, pdf: '12 s (06:58:40 to 06:58:52 UTC)', file: 'evidence/24-rollback-run.txt', find: '06:58:52Z [deploy:production] HEALTHY after 10s' },
  { p: 2, pdf: '58 requests, all answered: 57 on 1.1.0, then 1.0.0', file: 'evidence/23-rollback-before-during-after-health.txt', find: 'DURING: {"status":"ok","version":"1.0.0"', count: { pattern: 'DURING: {"status":"ok"', equals: 58 } },
  { p: 2, pdf: 'sha256:4af6a5e4', file: 'evidence/24-rollback-run.txt', find: '"sha256:4af6a5e49b2dd137eb24ec461afecdd91ef6cd5dae978847ce847f25bf8d7bfa"' },
  { p: 2, pdf: 'rows (28) and', file: 'evidence/24-rollback-run.txt', find: 'production rows after rollback: 28' },
  { p: 2, pdf: 'Production page footer after the v1.1.0 release', file: 'verification.md', find: 'footer "v1.1.0. New in 1.1: bookings open 7 days a week." then "v1.0.0"' },
  { p: 2, pdf: 'The same footer after the rollback to v1.0.0', file: 'verification.md', find: 'evidence/screenshots/07c-app-production-v1.0.0-after-rollback.png' },
  // Page 3
  { p: 3, pdf: 'every day at 02:00 UTC', file: 'evidence/08-production-manual-backup.txt', find: '0 2 * * * /backup.sh daily' },
  { p: 3, pdf: 'production_daily_20261027T062642Z.dump', file: 'evidence/08-production-manual-backup.txt', find: 'uploaded production_daily_20261027T062642Z.dump' },
  { p: 3, pdf: 'backups started at 06:27:00 and 06:28:00', file: 'evidence/09-cron-schedule-fires.txt', find: '2026-10-27T06:28:00Z [backup:staging] starting daily backup' },
  { p: 3, pdf: 'from 29 August to 27 October 2026', file: 'evidence/11-retention-before.txt', find: 'production_daily_20260829T020000Z.dump' },
  { p: 3, pdf: 'production_daily_20260829T020000Z.dump production_daily_20260830T020000Z.dump production_daily_20260831T020000Z.dump', file: 'evidence/11-retention-before.txt', find: 'production_daily_20260831T020000Z.dump' },
  { p: 3, pdf: 'production_daily_20261025T020000Z.dump production_daily_20261026T020000Z.dump production_daily_20261027T020000Z.dump', file: 'evidence/11-retention-before.txt', find: 'production_daily_20261027T020000Z.dump' },
  { p: 3, pdf: '... 54 more, one per day ...', file: 'evidence/11-retention-before.txt', find: 'BEFORE pruning: 60 dummy backups' },
  { p: 3, pdf: 'production_daily_20261021 Wed week 43 production_daily_20261022 Thu week 43 production_daily_20261023 Fri week 43 production_daily_20261024 Sat week 43 production_daily_20261025 Sun week 43 production_daily_20261026 Mon week 44 production_daily_20261027 Tue week 44', file: 'evidence/13-retention-after.txt', find: 'production_daily_20261027T020000Z.dump  Tue 2026-10-27 ISO-week 2026-W44' },
  { p: 3, pdf: 'restoring production/manual/production_manual_20261027T063003Z.dump into staging', file: 'evidence/14-restore-to-staging.log', find: 'restoring production/manual/production_manual_20261027T063003Z.dump into staging' },
  { p: 3, pdf: 'total time 3.5 s (3501 ms)', file: 'evidence/14-restore-to-staging.log', find: 'total time 3.5 s (3501 ms)' },
  { p: 3, pdf: '60 before, 9 after, 51 deleted', file: 'evidence/12-retention-prune-log.txt', find: '60 backups found' },
  { p: 3, pdf: '# AFTER pruning (7 daily + 4 weekly): 9 left', file: 'evidence/13-retention-after.txt', find: 'AFTER pruning (7 daily + 4 weekly): 9 backups left' },
  { p: 3, pdf: 'production_daily_20261011 Sun week 41', file: 'evidence/13-retention-after.txt', find: 'production_daily_20261011T020000Z.dump  Sun 2026-10-11 ISO-week 2026-W41' },
  { p: 3, pdf: 'production_daily_20261018 Sun week 42', file: 'evidence/13-retention-after.txt', find: 'production_daily_20261018T020000Z.dump  Sun 2026-10-18 ISO-week 2026-W42' },
  { p: 3, pdf: 'Staging had 25 rows', file: 'evidence/14-restore-to-staging.log', find: 'staging rows before: 25' },
  { p: 3, pdf: 'including three entered through the live API', file: 'evidence/08-production-manual-backup.txt', find: 'production rows now: 28' },
  { p: 3, pdf: 'rows at backup time: 28', file: 'evidence/14-restore-to-staging.log', find: 'rows at backup time: 28' },
  { p: 3, pdf: 'API returns 28 appointments, database has 28', file: 'evidence/14-restore-to-staging.log', find: 'API returns 28 appointments, database has 28' },
  { p: 3, pdf: 'list own backups', file: 'evidence/10-bucket-access-controls.txt', find: 'production user | list own prefix production/daily | ALLOWED' },
  { p: 3, pdf: 'list or write staging backups', file: 'evidence/10-bucket-access-controls.txt', find: 'production user | write into staging prefix | DENIED' },
  { p: 3, pdf: 'list and read production backups', file: 'evidence/10-bucket-access-controls.txt', find: 'staging user | read a production backup (needed for restore) | ALLOWED' },
  { p: 3, pdf: 'write or delete production backups', file: 'evidence/10-bucket-access-controls.txt', find: 'staging user | write into production prefix | DENIED' },
  // Page 4
  { p: 4, pdf: 'every 20 seconds', file: 'monitoring/kuma-setup.mjs', find: 'interval: 20,' },
  { p: 4, pdf: 'Stopped 06:48:55 UTC, DOWN email 06:49:01', file: 'evidence/18-app-outage-kuma-alerts.txt', find: '2026-10-27T06:49:01.863Z | [DOWN] production /health' },
  { p: 4, pdf: 'Started again 06:49:02, UP email 06:49:21', file: 'evidence/18-app-outage-kuma-alerts.txt', find: '2026-10-27T06:49:21.862Z | [UP] production /health' },
  { p: 4, pdf: 'System disk at 36%: alert sent', file: 'evidence/19-disk-alert-low-threshold.txt', find: 'ALERT SENT: "[ALERT] Disk 36% used on demo-mac:/ (threshold 30%)"' },
  { p: 4, pdf: 'System disk at 36%: no alert', file: 'evidence/20-disk-alert-normal-threshold.txt', find: 'OK: 36% <= 80%, no alert sent' },
  { p: 4, pdf: 'data disk really was at 89%', file: 'evidence/20-disk-alert-normal-threshold.txt', find: 'ALERT SENT: "[ALERT] Disk 89% used on demo-mac:/System/Volumes/Data (threshold 80%)"' },
  { p: 4, pdf: 'plan for about 30 to 40', file: 'docs/MIGRATION-PLAN.md', find: '**about 30 to 40 min**' },
  { p: 4, pdf: 'Keep the old server for 7 days', file: 'docs/MIGRATION-PLAN.md', find: "Don't delete or change the old server for 7 days" },
  { p: 4, pdf: 'backup kept for 30 days', file: 'docs/MIGRATION-PLAN.md', find: 'Keep the final dump from the window for at least 30 days' },
  { p: 4, pdf: 'lowered two days before', file: 'docs/MIGRATION-PLAN.md', find: 'at least 48 hours before the window' },
];

// Numbers that are layout, not claims.
const layoutNumbers = new Set(['1', '2', '3', '4', '5', '6', '7', '8', '9']);

const norm = (s) => s.replace(/\s+/g, ' ').trim();
const pdfText = norm(execFileSync('pdftotext', [path.join(root, 'deploy-proposal-sample.pdf'), '-']).toString());
let failures = 0;
const fail = (msg) => { failures++; console.log(`FAIL ${msg}`); };

const rows = claims.map((c) => {
  const lines = readFileSync(path.join(root, c.file), 'utf8').split('\n');
  const idx = lines.findIndex((l) => l.includes(c.find));
  if (idx < 0) fail(`evidence not found: ${c.file}: ${c.find}`);
  if (c.count) {
    const n = lines.filter((l) => l.includes(c.count.pattern)).length;
    if (n !== c.count.equals) fail(`count ${c.count.pattern} in ${c.file}: ${n} != ${c.count.equals}`);
  }
  if (!pdfText.includes(norm(c.pdf))) fail(`claim text not in PDF (page ${c.p}): ${c.pdf}`);
  return { ...c, line: idx + 1 };
});

// Every number in the PDF must be covered by a claim's PDF wording.
const claimText = claims.map((c) => norm(c.pdf)).join(' | ');
const footerAndLayout = pdfText.replace(/Page \d of \d/g, '');
const numbers = [...new Set(footerAndLayout.match(/\d+(?:[.:]\d+)*/g) || [])];
const unbacked = numbers.filter((n) => !layoutNumbers.has(n) && !claimText.includes(n));
if (unbacked.length) fail(`numbers in the PDF without a claim: ${unbacked.join(', ')}`);

// Nothing internal in the PDF text.
const forbidden = [
  [/\/Users\/|\/home\/|~\//, 'internal path'],
  [/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}/, 'email address'],
  [/krish/i, 'personal name or username'],
  [/gh[pousr]_[A-Za-z0-9]{20,}|[0-9a-f]{40,}/, 'token or secret-looking string'],
];
for (const [re, label] of forbidden) {
  const m = pdfText.match(re);
  if (m) fail(`${label} in PDF text: ${m[0]}`);
}

const md = [
  '# Claims in deploy-proposal-sample.pdf',
  '',
  'Every factual statement and number in the PDF, with the file and line that backs it. Generated and checked by `pdf/claims.mjs`, which also confirms that every number in the PDF text is covered by a row here, and that the PDF text contains no internal paths, usernames, emails or tokens.',
  '',
  '| Page | Claim (as worded in the PDF) | Evidence | Line | Evidence text |',
  '|---|---|---|---|---|',
  ...rows.map((r) => `| ${r.p} | ${r.pdf.replace(/\|/g, '\\|')} | \`${r.file}\` | ${r.line} | \`${r.find.replace(/\|/g, '\\|').replace(/`/g, "'")}\` |`),
  '',
  `Check result: ${failures === 0 ? `all ${rows.length} claims found in the PDF and in their evidence; ${numbers.length} distinct numbers in the PDF text, none without a claim; no internal paths, usernames, emails or tokens.` : `${failures} problem(s), see the script output.`}`,
  '',
].join('\n');
writeFileSync(path.join(root, 'CLAIMS.md'), md);
console.log(`${rows.length} claims, ${numbers.length} distinct numbers checked, ${failures} failures`);
process.exit(failures ? 1 : 0);
