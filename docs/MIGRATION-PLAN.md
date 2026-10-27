# Migration plan template: moving the live app to the new servers

Approach: **build the new production alongside the old one, copy the database in an agreed maintenance window, switch DNS, and keep the old server for 7 days.** At no point is the old server changed or switched off before the new one is proven.

Fill in the blanks (`____`) with the client before scheduling.

## Phase 0: Facts to collect

| Question | Answer |
|---|---|
| Cloud provider and region for the new servers | ____ |
| Current hosting and how we get access (SSH, panel) | ____ |
| PostgreSQL version on the old server | ____ |
| Database size (`SELECT pg_size_pretty(pg_database_size(current_database()));`) | ____ |
| DNS provider, and who can change records | ____ |
| Current DNS TTL of the app's record | ____ |
| Quietest time of the week for a short write freeze | ____ |
| Who approves go/no-go on the night | ____ |
| Anything else on the old server (cron jobs, file uploads, email sending) | ____ |

## Phase 1: Build alongside (no impact on users)

1. **Provision the servers.** Create the staging and production servers and harden them (`docs/SERVER-HARDENING.md`).
2. **Point the pipeline at them.** Set up the GitHub environments, secrets and pipeline, then deploy the current release to new staging, then new production, using a temporary hostname such as `new.app.example.com`.
3. **Rehearse the database copy.** Dump the old database, restore it into the new staging, and time it. This rehearsal sets the window length.
4. **Test on the new servers.** Run the client's acceptance tests against new staging. Check backups, alerts and a rollback there.
5. **Lower the DNS TTL.** Reduce the app record's TTL to 300 s at least 48 hours before the window, so the switch spreads quickly.

## Phase 2: Maintenance window (writes paused)

**Time estimate.** This depends on the database size from phase 0.

| Step | Rough time |
|---|---|
| Announce and enable maintenance page / stop writes on old app | 5 min |
| Final `pg_dump -Fc` on old server | about 1 min per GB (measure in rehearsal) |
| Copy dump to new production (same region, compressed) | about 1 min per GB |
| `pg_restore` on new production | about 1 to 3 min per GB (measure in rehearsal) |
| Checks (below) | 10 min |
| DNS switch and propagation (TTL 300 s) | 5 to 10 min |
| **Total for a small (under 1 GB) database** | **about 30 to 40 min** |

For reference, in this demo a tiny database (28 rows) restored in 3.5 s end to end. Real timings come from the rehearsal in phase 1.

**Checklist**

- [ ] Go/no-go confirmed with ____ at ____
- [ ] Users notified of the window (start ____, expected end ____)
- [ ] Old app writes stopped (maintenance page on, or app stopped); old database still running
- [ ] Final backup of the old database taken **and kept** (this is also the rollback point)
- [ ] Dump copied to new production; checksum matches (`sha256sum` on both ends)
- [ ] Restored into new production
- [ ] Row counts of key tables match between old and new (record them here: ____)
- [ ] New production `/health` OK; log in and read a few real records
- [ ] Automatic backup on new production run once by hand and visible in the bucket
- [ ] DNS record switched to the new server
- [ ] Caddy obtained the Let's Encrypt certificate for the real domain (check the Caddy log)
- [ ] Uptime monitor on the real domain is UP; test alert received
- [ ] Window closed; users notified

## Phase 3: Keep the old server for 7 days

- **Don't delete or change the old server for 7 days.** Leave it with writes stopped, so nobody can write to it by mistake.
- **Keep the final dump from the window for at least 30 days.**
- **After 7 calm days**, and with the client's agreement:
  1. take a last snapshot of the old server;
  2. cancel the old server;
  3. raise the DNS TTL back to normal.

## Rollback

**Trigger.** Roll back to the old server if, within the window or the following hours:

- new production fails the checks above and the fault can't be fixed within ____ minutes; or
- data is missing or wrong; or
- error rates or alerts show the new setup is unhealthy and the cause isn't clear.

**Steps (about 10 min):**

1. **Point DNS back** to the old server. The TTL is still 300 s.
2. **Restart the old app's writes** (turn off the maintenance page).
3. **Recover any writes made on the new server** if the new one took them before the rollback: export them with a query by `created_at` > switch time, and re-enter them on the old one.
4. **Tell the users,** then hold a short review before trying again.

The old database was never modified, so rolling back never needs a restore.
