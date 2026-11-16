import { createHash } from 'node:crypto';
import { readFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');
const outDir = resolve(repoRoot, 'docs/design/mockup-v2');
const templateUrl = pathToFileURL(resolve(outDir, 'mockup-templates.html')).href;

const TARGETS = [
  {
    file: 'web-tugas-kanban-light-opsi-a.png',
    screen: 'web-kanban',
    theme: 'light',
    accent: 'a',
    viewport: { width: 1440, height: 900 },
  },
  {
    file: 'web-tugas-kanban-light-opsi-b.png',
    screen: 'web-kanban',
    theme: 'light',
    accent: 'b',
    viewport: { width: 1440, height: 900 },
  },
  {
    file: 'web-tugas-kanban-dark-opsi-a.png',
    screen: 'web-kanban',
    theme: 'dark',
    accent: 'a',
    viewport: { width: 1440, height: 900 },
  },
  {
    file: 'web-tugas-kanban-dark-opsi-b.png',
    screen: 'web-kanban',
    theme: 'dark',
    accent: 'b',
    viewport: { width: 1440, height: 900 },
  },
  {
    file: 'web-hari-ini-light-opsi-a.png',
    screen: 'web-hari-ini',
    theme: 'light',
    accent: 'a',
    viewport: { width: 1440, height: 900 },
  },
  {
    file: 'web-uang-light-opsi-a.png',
    screen: 'web-uang',
    theme: 'light',
    accent: 'a',
    viewport: { width: 1440, height: 900 },
  },
  {
    file: 'mobile-hari-ini-light-opsi-a.png',
    screen: 'mobile-hari-ini',
    theme: 'light',
    accent: 'a',
    viewport: { width: 390, height: 844 },
  },
  {
    file: 'mobile-hari-ini-dark-opsi-b.png',
    screen: 'mobile-hari-ini',
    theme: 'dark',
    accent: 'b',
    viewport: { width: 390, height: 844 },
  },
  {
    file: 'mobile-kanban-light-opsi-a.png',
    screen: 'mobile-kanban',
    theme: 'light',
    accent: 'a',
    viewport: { width: 390, height: 844 },
  },
  {
    file: 'mobile-detail-dark-opsi-a.png',
    screen: 'mobile-detail',
    theme: 'dark',
    accent: 'a',
    viewport: { width: 390, height: 844 },
  },
  {
    file: 'mobile-uang-light-opsi-a.png',
    screen: 'mobile-uang',
    theme: 'light',
    accent: 'a',
    viewport: { width: 390, height: 844 },
  },
  {
    file: 'mobile-widgets-dark.png',
    screen: 'mobile-widgets',
    theme: 'dark',
    accent: 'a',
    viewport: { width: 920, height: 660 },
  },
];

mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const hashes = new Map();

try {
  const context = await browser.newContext({ deviceScaleFactor: 1 });
  await context.route('https://fonts.googleapis.com/**', (route) => route.abort());
  await context.route('https://fonts.gstatic.com/**', (route) => route.abort());

  const page = await context.newPage();

  for (const target of TARGETS) {
    await page.setViewportSize(target.viewport);
    const url = `${templateUrl}?screen=${target.screen}&theme=${target.theme}&accent=${target.accent}`;
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(150);

    const dims = await page.evaluate(() => {
      const mount = document.getElementById('mount');
      return {
        hasContent: Boolean(mount && mount.innerHTML.trim().length > 0),
        scrollWidth: document.documentElement.scrollWidth,
        scrollHeight: document.documentElement.scrollHeight,
      };
    });

    if (!dims.hasContent) {
      throw new Error(`Empty #mount rendered for ${target.file}`);
    }

    const outPath = resolve(outDir, target.file);
    await page.screenshot({ path: outPath, fullPage: false });

    const md5 = createHash('md5').update(readFileSync(outPath)).digest('hex');
    if (hashes.has(md5)) {
      throw new Error(`Duplicate MD5 (${md5}) between ${target.file} and ${hashes.get(md5)}`);
    }
    hashes.set(md5, target.file);

    const overflowX = dims.scrollWidth > target.viewport.width;
    const overflowY = dims.scrollHeight > target.viewport.height;
    console.log(
      `${target.file} | ${target.viewport.width}x${target.viewport.height} | scroll=${dims.scrollWidth}x${dims.scrollHeight}${overflowX || overflowY ? ' [OVERFLOW]' : ''} | md5=${md5}`,
    );
  }
} finally {
  await browser.close();
}
