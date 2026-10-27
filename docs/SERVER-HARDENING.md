# Server hardening and access control

Applies to both real servers, staging and production. Ubuntu 24.04 LTS is assumed; other distributions differ only in package names.

> **Every command on this page is documented, not run in this demo.** The demo runs on one Mac with Docker Desktop, which has no SSH daemon, ufw or fail2ban to configure. Each step below is marked the same way.

## 1. A separate deploy user with only what it needs

*Documented, not run in this demo.*

```bash
# As root (or via sudo) on a fresh server, once.
adduser --disabled-password --gecos "" deploy
usermod -aG docker deploy                 # may run docker compose; nothing else
install -d -o deploy -g deploy -m 750 /srv/appointments
install -d -o deploy -g deploy -m 700 /home/deploy/.ssh
# Public key of the GitHub deploy key pair (private half is a GitHub environment secret):
echo "ssh-ed25519 AAAA... github-actions-deploy" > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys && chmod 600 /home/deploy/.ssh/authorized_keys
```

- **The deploy user** has no password and no sudo. It can only:
  - write to `/srv/appointments`;
  - run Docker.
- **The docker group is close to root,** so the server should run nothing else that matters.
- **For a stricter split,** use a forced command in `authorized_keys`. With it, the GitHub key can run only the deploy script:
  ```
  command="/srv/appointments/deploy/deploy.sh $SSH_ORIGINAL_COMMAND",no-port-forwarding,no-agent-forwarding,no-pty ssh-ed25519 AAAA...
  ```
- **Human admins get their own named accounts** with sudo and their own keys. Nobody shares the deploy key.

## 2. SSH: keys only, no root login

*Documented, not run in this demo.*

```bash
cat > /etc/ssh/sshd_config.d/10-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
LoginGraceTime 20
X11Forwarding no
AllowUsers deploy admin-alice admin-bob
EOF
sshd -t && systemctl reload ssh
```

Keep a second SSH session open while reloading. Test a new login before closing it.

## 3. Firewall: only 22, 80, 443

*Documented, not run in this demo.*

```bash
ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp          # SSH, with rate limiting
ufw allow 80/tcp          # HTTP (Caddy redirects to HTTPS, and serves ACME challenges)
ufw allow 443/tcp         # HTTPS
ufw enable
ufw status verbose
```

**Docker and ufw:** ports published by Docker bypass ufw's INPUT rules. That's why the compose file publishes only Caddy's 80 and 443. PostgreSQL, the api and the web container have **no published ports**: they are reachable only on the Compose network. Check with:

```bash
ss -tlnp
docker ps --format '{{.Names}} {{.Ports}}'
```

Only Caddy should show `0.0.0.0` bindings. Better still, restrict SSH at the cloud provider's firewall or security group to the admins' IPs.

## 4. fail2ban for SSH

*Documented, not run in this demo.*

```bash
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
maxretry = 5
findtime = 10m
bantime  = 1h
EOF
systemctl enable --now fail2ban
fail2ban-client status sshd
```

## 5. Automatic security updates

*Documented, not run in this demo.*

```bash
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades
# /etc/apt/apt.conf.d/52unattended-upgrades-local
cat > /etc/apt/apt.conf.d/52unattended-upgrades-local <<'EOF'
Unattended-Upgrade::Origins-Pattern { "origin=Ubuntu,archive=${distro_codename}-security"; };
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:30";
EOF
unattended-upgrade --dry-run --debug | tail
```

**Reboots and timing:**

- **Restarts:** `restart: unless-stopped` brings every container back after a reboot.
- **Uptime Kuma** alerts if anything does not come back.
- **Container images** are updated by releases: rebuilding picks up patched base images.
- **The reboot window** of 04:30 is chosen to avoid the 02:00 backup.

## 6. Which secrets live where

| Secret | Lives in | Who/what can read it | Never in |
|---|---|---|---|
| `POSTGRES_PASSWORD` (per env) | GitHub environment secret, then the env file on that server (mode 600, owner `deploy`) | deploy jobs for that environment; containers of that stack | git, images, logs |
| `S3_SECRET_KEY` (per env) | same as above | the backup container of that stack | git, images, logs |
| Deploy SSH private key (per env) | GitHub environment secret `DEPLOY_SSH_KEY` | only jobs that passed that environment's protection (production: after approval) | servers, laptops |
| Server host key fingerprint | GitHub environment secret `DEPLOY_KNOWN_HOSTS` | deploy jobs (prevents man-in-the-middle) | n/a (not secret, but pinned) |
| Bucket admin / root credentials | the client's password manager | named admins only | servers, GitHub |
| Uptime Kuma admin password | password manager | admins | git |
| `GITHUB_TOKEN` | issued per job by GitHub, expires with the job | that job | anywhere persistent |

**Rules:**

- **Separate per environment:** staging secrets are not production secrets.
- **Backup users are least-privilege.** Staging can read production backups, for restore tests, but can't write or delete them. Production can't see staging. This is tested in this demo; see `evidence/10-bucket-access-controls.txt`.
- **Rotation:** change the value in GitHub, then redeploy. The env file is rewritten on every deploy.

## 7. GitHub side

These were set up and checked in this demo; see `evidence/03-github-environments-and-runner.txt`.

- The `production` environment requires a named reviewer, and only `main` may deploy to it.
- Workflows from forks need approval (`all_external_contributors`). With real servers, deploys use GitHub-hosted runners plus SSH, so no self-hosted runner is exposed to a public repository.
- **Recommended for the client repository:**
  - branch protection on `main`, with the CI checks required;
  - signed commits, optionally;
  - 2FA for everyone with write access.
