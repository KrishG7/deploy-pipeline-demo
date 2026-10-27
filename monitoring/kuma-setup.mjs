// Configures Uptime Kuma from code instead of by clicking: creates the admin
// account (first run only), an SMTP notification to the alert mailbox, and one
// HTTP monitor per environment on /health. Safe to re-run: existing items with
// the same name are left alone.
//
//   cd monitoring && npm ci && node kuma-setup.mjs
//
// Settings come from monitoring/.env (see .env.example).
import { readFileSync } from 'node:fs';
import { io } from 'socket.io-client';

const env = Object.fromEntries(
  readFileSync(new URL('.env', import.meta.url), 'utf8')
    .split('\n')
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
);
const smtp = new URL(env.ALERT_SMTP_URL);

const monitors = [
  // Inside the Kuma container these names resolve to the Mac (extra_hosts).
  { name: 'production /health', url: 'https://app.localhost/health' },
  { name: 'staging /health', url: 'https://staging.localhost:8443/health' },
];

const socket = io(env.KUMA_URL, { transports: ['websocket'], reconnection: false });
const call = (event, ...args) =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`${event}: no answer`)), 15_000);
    socket.emit(event, ...args, (res) => {
      clearTimeout(timer);
      resolve(res);
    });
  });
const once = (event) => new Promise((resolve) => socket.once(event, resolve));

async function main() {
  // The server registers its handlers asynchronously after connecting and
  // then announces either "setup" (first run) or "loginRequired".
  const first = await Promise.race([
    once('setup').then(() => 'setup'),
    once('loginRequired').then(() => 'loginRequired'),
  ]);
  if (first === 'setup') {
    const res = await call('setup', env.KUMA_ADMIN_USER, env.KUMA_ADMIN_PASSWORD);
    console.log('admin account created:', res.ok);
  }
  const monitorList = once('monitorList');
  const notificationList = once('notificationList');
  const login = await call('login', { username: env.KUMA_ADMIN_USER, password: env.KUMA_ADMIN_PASSWORD, token: '' });
  if (!login.ok) throw new Error(`login failed: ${login.msg}`);
  console.log('logged in');

  const existingNotifications = await notificationList;
  // Created on the first run, updated in place (same id) on later runs.
  const current = existingNotifications.find((n) => n.name === 'Alert mailbox (SMTP)');
  let notification;
  {
    const res = await call(
      'addNotification',
      {
        name: 'Alert mailbox (SMTP)',
        type: 'smtp',
        isDefault: true,
        applyExisting: true,
        // The Kuma container reaches Mailpit by its service name.
        smtpHost: 'mailpit',
        smtpPort: 1025,
        smtpSecure: false,
        smtpIgnoreTLSError: true,
        smtpFrom: `Uptime Kuma <${env.ALERT_FROM}>`,
        smtpTo: env.ALERT_TO,
        // Plain-text subject (Kuma's default status text contains emoji).
        customSubject: '[{% if heartbeatJSON.status == 1 %}UP{% else %}DOWN{% endif %}] {{NAME}} ({{HOSTNAME_OR_URL}})',
        customBody:
          '{{NAME}} is {% if heartbeatJSON.status == 1 %}UP{% else %}DOWN{% endif %}.\n\nURL: {{HOSTNAME_OR_URL}}\nDetail: {{heartbeatJSON.msg}}\nTime (UTC): {{heartbeatJSON.time}}',
      },
      current ? current.id : null,
    );
    if (!res.ok) throw new Error(`addNotification: ${res.msg}`);
    console.log(current ? 'notification updated:' : 'notification created:', res.id);
    notification = { id: res.id };
  }

  const existing = Object.values(await monitorList).map((m) => m.name);
  for (const m of monitors) {
    if (existing.includes(m.name)) {
      console.log('monitor exists:', m.name);
      continue;
    }
    const res = await call('add', {
      type: 'http',
      name: m.name,
      url: m.url,
      method: 'GET',
      interval: 20,
      retryInterval: 20,
      resendInterval: 0,
      maxretries: 0,
      timeout: 10,
      // The demo uses Caddy's internal CA; real servers have Let's Encrypt
      // certificates and this stays false.
      ignoreTls: true,
      upsideDown: false,
      expiryNotification: false,
      maxredirects: 3,
      accepted_statuscodes: ['200-299'],
      notificationIDList: { [notification.id]: true },
      active: true,
      httpBodyEncoding: 'json',
      kafkaProducerBrokers: [],
      kafkaProducerSaslOptions: { mechanism: 'None' },
      conditions: [],
      rabbitmqNodes: [],
    });
    if (!res.ok) throw new Error(`add ${m.name}: ${res.msg}`);
    console.log('monitor created:', m.name, '->', m.url, `(id ${res.monitorID})`);
  }
  socket.close();
}

main().catch((err) => {
  console.error(err.message);
  socket.close();
  process.exit(1);
});
