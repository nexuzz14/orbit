import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildCategoryBreakdown,
  buildMonthlyCashflowSeries,
  escapeCsvCell,
  exportProjectReportToCsv,
  exportTransactionsToCsv,
  parseBankMutationCsv,
} from './finance-v2';

test('escapeCsvCell menetralisir CSV formula injection (=, +, -, @, tab)', () => {
  assert.equal(escapeCsvCell('=CMD("calc")'), '"\'=CMD(""calc"")"');
  assert.equal(escapeCsvCell('+1+1'), "'+1+1");
  assert.equal(escapeCsvCell('-2+5'), "'-2+5");
  assert.equal(escapeCsvCell('@SUM(A1:A2)'), "'@SUM(A1:A2)");
  assert.equal(escapeCsvCell('Normal, Text'), '"Normal, Text"');
  assert.equal(escapeCsvCell(-150000), '-150000');
});

test('Ekspor CSV transaksi dan laporan proyek menyertakan BOM UTF-8 dan formula safety', () => {
  const txCsv = exportTransactionsToCsv([
    {
      occurred_at: '2026-11-15T10:00:00Z',
      type: 'expense',
      category_name: 'Makan',
      account_name: 'BCA',
      source: 'personal',
      project_name: null,
      merchant: '=HYPERLINK("http://evil")',
      note: 'Makan siang; kantin',
      status: 'confirmed',
      currency: 'IDR',
      amount: 45000,
      amount_base: 45000,
    },
  ]);

  assert.ok(txCsv.startsWith('\uFEFF'));
  assert.ok(txCsv.includes('"\'=HYPERLINK(""http://evil"")"'));
  assert.ok(txCsv.includes('"Makan siang; kantin"'));

  const projCsv = exportProjectReportToCsv([
    {
      project_name: 'Portal UMKM',
      kind: 'freelance',
      client_name: 'PT Maju',
      status: 'active',
      currency: 'IDR',
      contract_value: 15000000,
      total_invoiced: 10000000,
      total_paid: 7500000,
      remaining_invoiced: 2500000,
      total_expense: 1200000,
      net_profit: 6300000,
      margin_percent: 84,
    },
  ]);

  assert.ok(projCsv.startsWith('\uFEFF'));
  assert.ok(projCsv.includes('Portal UMKM'));
  assert.ok(projCsv.includes('6300000'));
});

test('parseBankMutationCsv mendukung delimiter titik koma (;), format angka ID, dan kolom Debit/Kredit', () => {
  const sampleBankCsv = [
    'Tanggal;Keterangan;Debit;Kredit;Saldo',
    '15/11/2026;"TRSF E-BANKING DB WARUNG KOPI";55.000,00;0;1.945.000,00',
    '16/11/2026;"PEMBAYARAN INVOICE KLIEN";0;2.500.000;4.445.000',
    '17/11/2026;BIAYA ADMIN;;6.500;4.438.500',
  ].join('\n');

  const res = parseBankMutationCsv(sampleBankCsv);
  assert.equal(res.delimiter, ';');
  assert.equal(res.rows.length, 3);

  assert.equal(res.rows[0].occurredDate, '2026-11-15');
  assert.equal(res.rows[0].type, 'expense');
  assert.equal(res.rows[0].amount, 55000);
  assert.equal(res.rows[0].balance, 1945000);

  assert.equal(res.rows[1].occurredDate, '2026-11-16');
  assert.equal(res.rows[1].type, 'income');
  assert.equal(res.rows[1].amount, 2500000);

  assert.equal(res.rows[2].type, 'income');
  assert.equal(res.rows[2].amount, 6500);
});

test('parseBankMutationCsv mendukung kolom nominal tunggal dengan penanda DB/CR atau tanda negatif', () => {
  const csvComma = [
    'Date,Description,Amount,Type',
    '2026-11-10,"Grab Ride, Jakarta","-32,500",DB',
    '2026-11-11,"Transfer Honor",1200000,CR',
    '2026-11-12,"Tagihan Internet",450000 DB,',
  ].join('\n');

  const res = parseBankMutationCsv(csvComma);
  assert.equal(res.delimiter, ',');
  assert.equal(res.rows.length, 3);
  assert.equal(res.rows[0].type, 'expense');
  assert.equal(res.rows[0].amount, 32500);
  assert.equal(res.rows[1].type, 'income');
  assert.equal(res.rows[1].amount, 1200000);
  assert.equal(res.rows[2].type, 'expense');
  assert.equal(res.rows[2].amount, 450000);
});

test('Builder grafik bulanan dan breakdown kategori menghasilkan seri terurut dan persentase 100%', () => {
  const series = buildMonthlyCashflowSeries(
    [
      { month_start: '2026-11-01', income: 8000000, expense: 3200000, net: 4800000 },
      { month_start: '2026-09-01', income: 5000000, expense: 2500000, net: 2500000 },
      { month_start: '2026-10-01', income: 6000000, expense: 4000000, net: 2000000 },
    ],
    6
  );

  assert.equal(series.length, 3);
  assert.equal(series[0].monthKey, '2026-09');
  assert.equal(series[2].monthKey, '2026-11');
  assert.equal(series[2].net, 4800000);

  const cats = buildCategoryBreakdown(
    [
      { category_id: 'c1', category_name: 'Konsumsi', type: 'expense', total: 1500000, txn_count: 10 },
      { category_id: 'c2', category_name: 'Transport', type: 'expense', total: 500000, txn_count: 5 },
      { category_id: 'c3', category_name: 'Gaji', type: 'income', total: 5000000, txn_count: 1 },
    ],
    'expense',
    5
  );

  assert.equal(cats.length, 2);
  assert.equal(cats[0].name, 'Konsumsi');
  assert.equal(cats[0].sharePercent, 75);
  assert.equal(cats[1].sharePercent, 25);
});
