# Rollback

There are two cases:

- **The release changed only code.** This is the normal case. Redeploy the previous image. It takes seconds, and the database is not touched.
- **The release also changed the database.** For example, a migration altered or dropped columns. Redeploying old code may not be enough. See [part 2](#2-the-release-also-changed-the-database).

Every production deploy is preceded by an automatic backup (`deploy/predeploy-backup.sh`, the "Pre-deploy backup" step of the production job). So there is always a restore point taken seconds before the release.

## 1. Code-only rollback (redeploy an earlier image)

Images are immutable and kept in GHCR under two tags:

- `sha-<commit>` for every build.
- `v<version>` for each release. Release tags are never overwritten; the build job refuses to re-push an existing one.

A rollback deploys an existing tag. Nothing is rebuilt, and no migration or database command runs.

**Steps**

1. **Pick the tag to go back to.** It's usually the previous release, for example `v1.0.0`. The deploy history on the server lists every tag that went live:
   `cat ~/.deploy-pipeline-demo/production.history`
2. **Start the rollback.** In GitHub, open **Actions**, then **Rollback production**, then **Run workflow**, and enter the tag. From a terminal:
   ```
   gh workflow run rollback.yml -f tag=v1.0.0
   ```
3. **The first job checks the tag.** It confirms the api, web and backup images exist for that tag. A typo fails here, before anything changes.
4. **Approve the production job.** It uses the same `production` environment as a normal release, so it waits for the same reviewer: open the run, then **Review deployments**, tick **production**, then **Approve and deploy**.
5. **The job redeploys the tag.** It runs `deploy/deploy.sh production <tag>`, which pulls the tag, runs `docker compose up -d`, and waits for `/health` to report that image's version. If that doesn't happen within 60 s, the job fails.
6. **Confirm the result:**
   ```
   curl https://<domain>/health
   ```
   Check that the reported version is the old one, and check the page footer.
7. **Record it.** Add the reason and the times to the incident log, then fix forward on `main`. The next release goes through staging and approval as usual.

**Measured in this demo:** v1.1.0 back to v1.0.0. The time from approval to `/health` reporting 1.0.0 is in `evidence/` (see `verification.md`, rollback rows).

**Without GitHub**, for example during an outage, on the server as the deploy user:

```
cd /srv/appointments && deploy/deploy.sh production v1.0.0
```

## 2. The release also changed the database

Redeploying old code on a newer schema can fail or misbehave. Decide which situation applies:

| Situation | Action |
|---|---|
| Migration was additive only (new table or nullable column) and old code ignores it | Code-only rollback (part 1). Leave the schema; clean up later. |
| Migration changed or removed things the old code needs, and **no important data has been written since** | Code-only rollback, then restore the pre-deploy backup (below). |
| Migration changed things **and** users have written data since the release | Do not restore blindly: that would lose those writes. Prefer a fix-forward, or restore the pre-deploy backup to staging, export the new rows, restore production, re-import. Agree this with the client first. |

### Restore the pre-deploy backup into production

1. **Announce a short maintenance window.** Stop writes by stopping the api:
   ```
   scripts/compose.sh production stop api
   ```
2. **Find the backup taken right before the bad release.** Its name ends in `_before-<tag>`:
   ```
   scripts/compose.sh production exec backup sh -c 'mc ls offsite/backups/production/predeploy/'
   ```
3. **Rehearse in staging first.** It takes seconds and proves the file is good:
   ```
   scripts/restore-to-staging.sh production_predeploy_<timestamp>_before-<tag>.dump
   ```
4. **Take one more backup of the current production state**, so nothing is lost even if the decision is reversed:
   ```
   scripts/compose.sh production exec backup /backup.sh manual before-restore
   ```
5. **Restore into production.**
   - `/restore.sh` refuses to run outside staging on purpose. This step is deliberately manual and needs two people.
   - Run it from the production backup container:
     ```
     dropdb --force appointments && createdb appointments && pg_restore --no-owner -d appointments <file>
     ```
   - The dump needs to be inside that container first: copy it from the bucket with `mc cp`.
6. **Roll the code back** to the matching tag (part 1). Then start the api and check `/health` and the row counts.
7. **Tell users which time window**, if any, needs re-entering.
