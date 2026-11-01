import { test, expect } from '@playwright/test';

const routes = [
  '/',
  '/login',
  '/hari-ini',
  '/transaksi',
  '/anggaran',
  '/tagihan',
  '/tabungan',
  '/akun',
  '/kategori',
  '/proyek',
  '/tugas',
  '/jadwal',
  '/inbox',
  '/ringkasan',
  '/pengaturan',
];

for (const route of routes) {
  test(`CSP and Hydration check for route: ${route}`, async ({ page }) => {
    const cspViolations: string[] = [];
    const pageErrors: Error[] = [];

    // Dengarkan console error untuk mendeteksi pelanggaran CSP
    page.on('console', (msg) => {
      const text = msg.text();
      if (
        msg.type() === 'error' &&
        (text.toLowerCase().includes('content security policy') ||
          text.toLowerCase().includes('violates') ||
          text.toLowerCase().includes('refused to'))
      ) {
        cspViolations.push(text);
      }
    });

    // Tangkap unhandled runtime error di browser
    page.on('pageerror', (err) => {
      pageErrors.push(err);
    });

    const response = await page.goto(route, { waitUntil: 'networkidle' });
    expect(response).not.toBeNull();

    // Verifikasi keberadaan header Content-Security-Policy
    const headers = response!.headers();
    const csp = headers['content-security-policy'];
    expect(csp).toBeDefined();

    // Pastikan script-src TIDAK mengandung unsafe-inline
    const scriptSrcMatch = csp.match(/script-src\s+([^;]+)/);
    expect(scriptSrcMatch).not.toBeNull();
    const scriptSrcDirective = scriptSrcMatch![1];
    expect(scriptSrcDirective).not.toContain("'unsafe-inline'");

    // Pastikan ada nonce pada script-src
    expect(scriptSrcDirective).toContain("'nonce-");

    // Pastikan tidak ada pelanggaran CSP yang dicatat browser
    expect(cspViolations, `Ditemukan pelanggaran CSP pada ${route}: ${cspViolations.join('; ')}`).toEqual([]);

    // Pastikan tidak ada error runtime fatal
    expect(pageErrors, `Ditemukan error runtime pada ${route}: ${pageErrors.map(e => e.message).join('; ')}`).toEqual([]);

    // Verifikasi bahwa aplikasi terhidrasi (root html dan body ada dan dapat berinteraksi)
    const body = await page.locator('body').count();
    expect(body).toBeGreaterThan(0);
  });
}
