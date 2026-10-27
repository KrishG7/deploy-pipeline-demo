// Renders pdf/sample.html to deploy-proposal-sample.pdf (A4) with Playwright.
//   cd pdf && node build-pdf.mjs
import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(here, '..', 'deploy-proposal-sample.pdf');

const footer = `
  <div style="width:100%;padding:0 14mm;font:7.5pt 'IBM Plex Sans',Helvetica,sans-serif;color:#5a636d;display:flex;justify-content:space-between">
    <span>Demo environment: servers simulated locally; your setup uses separate cloud servers.</span>
    <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
  </div>`;

const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto(`file://${path.join(here, 'sample.html')}`, { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts.ready);
await page.pdf({
  path: out,
  format: 'A4',
  printBackground: true,
  preferCSSPageSize: true,
  displayHeaderFooter: true,
  headerTemplate: '<span></span>',
  footerTemplate: footer,
});
await browser.close();
console.log(`wrote ${out}`);
