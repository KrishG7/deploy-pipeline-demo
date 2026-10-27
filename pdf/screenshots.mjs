// Evidence screenshots with Playwright (real pages, nothing mocked).
//
//   node screenshots.mjs app <out.png> [url]          app page (default https://app.localhost)
//   node screenshots.mjs kuma <out.png>                Uptime Kuma dashboard (logs in)
//   node screenshots.mjs mailpit <out.png>             Mailpit inbox
//   node screenshots.mjs page <out.png> <url>          any public page (GitHub run pages)
//   node screenshots.mjs terminal <out.png> <log> [title]  a saved log, shown as a terminal
//
// Kuma credentials come from monitoring/.env.
import { readFileSync } from 'node:fs';
import { chromium } from 'playwright';

const [mode, out, arg, title] = process.argv.slice(2);
if (!mode || !out) {
  console.error('usage: node screenshots.mjs <app|kuma|mailpit|page|terminal> <out.png> [arg]');
  process.exit(2);
}

const env = () =>
  Object.fromEntries(
    readFileSync(new URL('../monitoring/.env', import.meta.url), 'utf8')
      .split('\n')
      .filter((l) => l.includes('=') && !l.startsWith('#'))
      .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
  );

const escapeHtml = (s) => s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[c]);

const browser = await chromium.launch();
// The demo's HTTPS uses Caddy's local CA, which this browser does not trust.
const context = await browser.newContext({
  viewport: { width: 1280, height: 800 },
  deviceScaleFactor: 2,
  ignoreHTTPSErrors: true,
});
const page = await context.newPage();

try {
  if (mode === 'app') {
    await page.goto(arg || 'https://app.localhost', { waitUntil: 'networkidle' });
    await page.waitForSelector('table');
    // Full page, so the footer with the version is in the picture.
    await page.screenshot({ path: out, fullPage: true });
  } else if (mode === 'kuma') {
    const { KUMA_URL, KUMA_ADMIN_USER, KUMA_ADMIN_PASSWORD } = env();
    await page.goto(`${KUMA_URL}/dashboard`);
    await page.fill('#floatingInput', KUMA_ADMIN_USER);
    await page.fill('#floatingPassword', KUMA_ADMIN_PASSWORD);
    await page.click('button[type=submit]');
    await page.waitForSelector('.monitor-list .item', { timeout: 20_000 });
    await page.waitForTimeout(2500);
    await page.screenshot({ path: out });
  } else if (mode === 'mailpit') {
    await page.goto('http://127.0.0.1:8025/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);
    await page.screenshot({ path: out });
  } else if (mode === 'page') {
    await page.goto(arg, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1500);
    await page.screenshot({ path: out });
  } else if (mode === 'terminal') {
    const log = readFileSync(arg, 'utf8');
    await page.setViewportSize({ width: 1280, height: 400 });
    await page.setContent(`<!doctype html><html><body style="margin:0;background:#1e1f22">
      <div style="font:12px/1.0 -apple-system,sans-serif;color:#9a9ca3;padding:8px 14px;background:#2b2d31">${escapeHtml(title || arg)}</div>
      <pre style="margin:0;padding:14px;font:12.5px/1.45 Menlo,Monaco,monospace;color:#e6e6e6;white-space:pre-wrap;word-break:break-all">${escapeHtml(log)}</pre>
      </body></html>`);
    await page.screenshot({ path: out, fullPage: true });
  } else {
    throw new Error(`unknown mode ${mode}`);
  }
  console.log(`saved ${out}`);
} finally {
  await browser.close();
}
