# Verification log

Filled in as each check was run on the demo Mac. "Observed" is what the command actually printed; the evidence file holds the full output.

| # | Check | Command or action | Expected | Observed | PASS/FAIL/NOT RUN | Evidence file |
|---|-------|-------------------|----------|----------|-------------------|---------------|
| 1 | API lint and tests pass locally | `npx eslint . && npm test` against a postgres:16-alpine container | 0 lint problems, all tests pass | eslint: no problems; 6 tests, 6 pass, 0 fail | PASS | evidence/01-api-lint-and-tests-local.txt |
| 2 | Offsite bucket with one least-privilege user per environment | `deploy/offsite/setup.sh` against the MinIO container | bucket created, users production-backup and staging-backup with their own policies | bucket `backups` created; both users listed with matching PolicyName | PASS | evidence/02-offsite-bucket-and-users.txt |
| 3 | GitHub environments, required reviewer on production, secrets, runner | `gh api` calls (repo environments, branch policy, secrets, runners) | production has required_reviewers + main-only branch policy; staging and production each have 2 secrets; runner `demo-mac` online with label `demo-deployer` | as expected; fork PR workflows need approval (`all_external_contributors`) | PASS | evidence/03-github-environments-and-runner.txt |
