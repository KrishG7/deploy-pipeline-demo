# syntax=docker/dockerfile:1
# Backup sidecar: pg_dump/pg_restore 16 + the S3 client "mc" + busybox crond.

# The upstream minio/minio and minio/mc images are no longer published on
# Docker Hub. pgsty/minio is a maintained community build of MinIO that ships
# the mc client; we copy only the static mc binary out of it.
FROM pgsty/minio:RELEASE.2026-08-04T00-00-00Z AS mc

FROM postgres:16-alpine
COPY --from=mc /usr/bin/mc /usr/local/bin/mc
COPY backup.sh prune.sh restore.sh entrypoint.sh /
RUN chmod 0755 /backup.sh /prune.sh /restore.sh /entrypoint.sh
# crond must start as root to run the job; the job itself only talks to the
# database and the bucket over the network and has no published ports.
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep crond >/dev/null && pg_isready -q -h "${PGHOST:-db}" || exit 1
ENTRYPOINT ["/entrypoint.sh"]
