# Environment variables

Every variable the stacks use, where it is set, and whether it is a secret.

**Where values live**

- **Not secret:** in the committed templates `deploy/.env.staging.example` and `deploy/.env.production.example`.
- **Secret:**
  - **Deploy jobs:** GitHub *environment* secrets (`staging` and `production` each have their own).
  - **Locally:** gitignored env files.
- **Runtime env file:** `deploy/write-env.sh` combines the template, the secrets and `IMAGE_PREFIX` into `~/.deploy-pipeline-demo/<env>.env`, outside the repository, with mode 600. On a real server, the same script writes it on that server.
- **Image tag:** `IMAGE_TAG` is never in an env file. `deploy/deploy.sh` writes it to `<env>.release` when it deploys.

## App stacks (`deploy/compose.yml`)

| Variable | What it does | Example value | Secret? |
|---|---|---|---|
| `APP_ENV` | Environment name; shown by `/health` and on the page, used to name backups | `staging` / `production` | No |
| `SITE_DOMAIN` | Hostname Caddy serves and gets a certificate for | `staging.localhost`, `app.localhost` (real: `app.example.com`) | No |
| `CADDY_TLS` | Extra TLS directive. `tls internal` = Caddy's own CA (demo). Empty = automatic Let's Encrypt (real servers) | `tls internal` | No |
| `BIND_ADDRESS` | Host address the HTTP/HTTPS ports bind to | `127.0.0.1` (real: `0.0.0.0`) | No |
| `HTTP_PORT` | HTTP port (redirects to HTTPS) | `8080` / `80` | No |
| `HTTPS_PORT` | HTTPS port | `8443` / `443` | No |
| `IMAGE_PREFIX` | Registry path of the images; the workflow sets it from the repository name | `ghcr.io/<owner>/deploy-pipeline-demo` | No |
| `IMAGE_TAG` | Image tag to run; written by `deploy/deploy.sh`, never edited by hand | `sha-d383577`, `v1.0.0` | No |
| `POSTGRES_DB` | Database name | `appointments` | No |
| `POSTGRES_USER` | Database owner role used by the api and backups | `appointments` | No |
| `POSTGRES_PASSWORD` | Password for that role | `openssl rand -hex 24` | **Yes** |
| `SEED_ON_START` | Insert the 25 demo rows if the table is empty | `true` (real: `false`) | No |
| `BACKUP_SCHEDULE` | Cron expression for the daily backup (UTC) | `0 2 * * *` | No |
| `RETAIN_DAILY` | Daily backups kept by pruning | `7` | No |
| `RETAIN_WEEKLY` | Weekly backups kept by pruning | `4` | No |
| `S3_ENDPOINT` | Object storage endpoint for backups | `http://host.docker.internal:9000` (real: the provider's S3 URL) | No |
| `S3_BUCKET` | Bucket name | `backups` | No |
| `S3_ACCESS_KEY` | Access key of this environment's backup user | `staging-backup` | No (an identifier) |
| `S3_SECRET_KEY` | Secret key of that user | `openssl rand -hex 24` | **Yes** |

Set by the image, not by env files: `APP_VERSION` (from the `APP_VERSION` build arg, shown by `/health` and in the footer), `PORT` (`3000`).

## Offsite storage (`deploy/offsite/compose.yml`, demo only)

| Variable | What it does | Example value | Secret? |
|---|---|---|---|
| `MINIO_ROOT_USER` | MinIO admin user, only used by `deploy/offsite/setup.sh` | `offsite-admin` | No |
| `MINIO_ROOT_PASSWORD` | MinIO admin password | `openssl rand -hex 24` | **Yes** |
| `STAGING_S3_SECRET`, `PRODUCTION_S3_SECRET` | Passed to `setup.sh` to create the two backup users | generated | **Yes** |

In the real setup the bucket is at the cloud provider and these become two IAM users or keys with the same policies.

## Monitoring (`monitoring/.env`, see `monitoring/.env.example`)

| Variable | What it does | Example value | Secret? |
|---|---|---|---|
| `KUMA_URL` | Uptime Kuma address for the setup script | `http://127.0.0.1:3001` | No |
| `KUMA_ADMIN_USER` | Kuma admin login | `admin` | No |
| `KUMA_ADMIN_PASSWORD` | Kuma admin password | `openssl rand -hex 16` | **Yes** |
| `ALERT_SMTP_URL` | SMTP server for disk alerts | `smtp://127.0.0.1:1025` (Mailpit) | No (real: may include credentials, then **Yes**) |
| `ALERT_FROM` | Sender address of alerts | an address on your domain | No |
| `ALERT_TO` | Who receives alerts | the on-call mailbox | No (personal data: keep out of git) |
| `ALERT_HOST_LABEL` | Name shown in disk alerts | `prod-1` | No |
| `DISK_ALERT_THRESHOLD` | Percent used that triggers a disk alert | `80` | No |

## GitHub

| Name | Kind | Where | Purpose |
|---|---|---|---|
| `POSTGRES_PASSWORD` | Environment secret | `staging`, `production` (different values) | written into the runtime env file |
| `S3_SECRET_KEY` | Environment secret | `staging`, `production` (different values) | written into the runtime env file |
| `GITHUB_TOKEN` | Automatic | every job | push images to GHCR (build job), pull them (deploy jobs) |
| `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS` | Environment secrets | real servers only | used by `deploy/remote-deploy.sh` (not used in this demo) |
