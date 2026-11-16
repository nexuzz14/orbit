import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildWeeklyDigestSummary,
  detectSmartAlerts,
  getDaysUntilBillDue,
  parseReceiptOrNotificationText,
} from './smart-alerts';

describe('Smart Alerts & Weekly Digest', () => {
  test('detects overlapping WIB events, stagnant >5d tasks, overdue & H-24h tasks, budgets >=80%/>=100%, and bills H-3..H-0', () => {
    const now = new Date('2026-11-15T10:00:00+07:00');
    const alerts = detectSmartAlerts({
      now,
      events: [
        {
          id: 'e1',
          title: 'Standup Produk',
          starts_at: '2026-11-15T14:00:00+07:00',
          ends_at: '2026-11-15T15:00:00+07:00',
        },
        {
          id: 'e2',
          title: 'Review Desain',
          starts_at: '2026-11-15T14:30:00+07:00',
          ends_at: '2026-11-15T15:30:00+07:00',
        },
      ],
      tasks: [
        {
          id: 't-overdue',
          title: 'Kirim Laporan Pajak',
          status: 'doing',
          due_at: '2026-11-14T18:00:00+07:00',
          updated_at: '2026-11-14T10:00:00+07:00',
        },
        {
          id: 't-soon',
          title: 'Presentasi Klien',
          status: 'todo',
          due_at: '2026-11-16T08:00:00+07:00',
          updated_at: '2026-11-15T08:00:00+07:00',
        },
        {
          id: 't-stagnant',
          title: 'Rapikan Arsip Kontrak',
          status: 'doing',
          due_at: null,
          updated_at: '2026-11-08T09:00:00+07:00',
        },
      ],
      budgets: [
        {
          budget_id: 'b1',
          category_name: 'Makan & Minum',
          effective_budget_amount: 1000000,
          spent_amount: 850000,
          percentage_spent: 85,
        },
        {
          budget_id: 'b2',
          category_name: 'Transportasi',
          effective_budget_amount: 500000,
          spent_amount: 550000,
          percentage_spent: 110,
          is_over_budget: true,
        },
      ],
      bills: [
        {
          id: 'bill1',
          name: 'Internet Fiber',
          amount: 350000,
          active: true,
          schedule_type: 'monthly',
          schedule_value: 17, // H-2 dari 15 Nov
        },
      ],
    });

    const types = new Set(alerts.map((a) => a.type));
    assert.ok(types.has('schedule_conflict'), 'Must detect overlapping WIB schedule');
    assert.ok(types.has('task_overdue'), 'Must detect overdue task');
    assert.ok(types.has('task_due_soon'), 'Must detect H-24h due task');
    assert.ok(types.has('task_stagnant'), 'Must detect stagnant >5d task');
    assert.ok(types.has('budget_warning'), 'Must detect >=80% budget');
    assert.ok(types.has('budget_exceeded'), 'Must detect >=100% budget');
    assert.ok(types.has('bill_due'), 'Must detect bill H-3..H-0');
  });

  test('computes bill days-until across month boundary cleanly', () => {
    const now = new Date('2026-11-29T10:00:00+07:00');
    const diff = getDaysUntilBillDue(
      { schedule_type: 'monthly', schedule_value: 1 },
      now
    );
    assert.equal(diff, 2);
  });

  test('builds weekly digest summary with cashflow, savings rate, and mailto link', () => {
    const now = new Date('2026-11-15T12:00:00+07:00');
    const digest = buildWeeklyDigestSummary({
      now,
      workspaceName: 'Personal',
      tasks: [
        {
          id: 't1',
          title: 'Selesai',
          status: 'done',
          updated_at: '2026-11-13T10:00:00+07:00',
        },
        {
          id: 't2',
          title: 'Aktif Terlambat',
          status: 'todo',
          due_at: '2026-11-14T10:00:00+07:00',
        },
        {
          id: 't3',
          title: 'Aktif Minggu Depan',
          status: 'doing',
          due_at: '2026-11-18T10:00:00+07:00',
        },
      ],
      transactions: [
        {
          id: 'tx1',
          type: 'income',
          amount: 2000000,
          occurred_at: '2026-11-12T10:00:00+07:00',
          status: 'confirmed',
        },
        {
          id: 'tx2',
          type: 'expense',
          amount: 500000,
          occurred_at: '2026-11-14T10:00:00+07:00',
          status: 'confirmed',
        },
      ],
      events: [
        {
          id: 'ev1',
          title: 'Rapat Mingguan',
          starts_at: '2026-11-17T09:00:00+07:00',
          ends_at: '2026-11-17T10:00:00+07:00',
        },
      ],
      bills: [
        {
          id: 'b1',
          name: 'Listrik',
          amount: 250000,
          active: true,
          schedule_type: 'monthly',
          schedule_value: 20,
        },
      ],
    });

    assert.equal(digest.past7Days.completedTasksCount, 1);
    assert.equal(digest.past7Days.incomeTotal, 2000000);
    assert.equal(digest.past7Days.expenseTotal, 500000);
    assert.equal(digest.past7Days.netCashflow, 1500000);
    assert.equal(digest.past7Days.savingsRatePercent, 75);
    assert.equal(digest.next7Days.activeTasksCount, 2);
    assert.equal(digest.next7Days.overdueTasksCount, 1);
    assert.equal(digest.next7Days.upcomingDueTasksCount, 1);
    assert.equal(digest.next7Days.upcomingEventsCount, 1);
    assert.equal(digest.next7Days.upcomingBillsCount, 1);
    assert.ok(digest.mailtoHref.startsWith('mailto:?subject='));
    assert.ok(digest.htmlBody.includes('75%'));
  });
});

describe('Indonesian Receipt & Bank Notification Parser', () => {
  test('parses BCA QRIS debit notification accurately', () => {
    const res = parseReceiptOrNotificationText(
      'BCA Mobile: Pembayaran QRIS di Kopi Kenangan sebesar Rp 45.000,00 pada 15/11/2026 09:30 WIB berhasil.'
    );
    assert.equal(res.ok, true);
    if (res.ok) {
      assert.equal(res.parsed.amount, 45000);
      assert.equal(res.parsed.type, 'expense');
      assert.equal(res.parsed.provider, 'BCA');
      assert.ok(res.parsed.merchant.toLowerCase().includes('kopi kenangan'));
      assert.equal(res.parsed.occurredAt, '2026-11-15T09:30:00+07:00');
      assert.equal(res.parsed.needsReview, false);
    }
  });

  test('parses Mandiri credit incoming transfer notification accurately', () => {
    const res = parseReceiptOrNotificationText(
      'Livin Mandiri: Dana masuk Rp 1.500.000 dari PT Nusantara pada 14 Nov 2026 16:15 WIB.'
    );
    assert.equal(res.ok, true);
    if (res.ok) {
      assert.equal(res.parsed.amount, 1500000);
      assert.equal(res.parsed.type, 'income');
      assert.equal(res.parsed.provider, 'Mandiri');
      assert.equal(res.parsed.occurredAt, '2026-11-14T16:15:00+07:00');
    }
  });

  test('parses Indomaret / Alfamart receipt text prioritizing TOTAL over cash/change', () => {
    const receipt = [
      'INDOMARET SUDIRMAN JAKARTA',
      'ROTI TAWAR         18.500',
      'SUSU UHT           22.000',
      'TOTAL BAYAR     Rp 40.500',
      'TUNAI              50.000',
      'KEMBALIAN           9.500',
      '15-11-2026 11:20',
    ].join('\n');

    const res = parseReceiptOrNotificationText(receipt);
    assert.equal(res.ok, true);
    if (res.ok) {
      assert.equal(res.parsed.amount, 40500);
      assert.equal(res.parsed.type, 'expense');
      assert.equal(res.parsed.origin, 'receipt');
      assert.ok(res.parsed.merchant.toUpperCase().includes('INDOMARET'));
      assert.equal(res.parsed.occurredAt, '2026-11-15T11:20:00+07:00');
    }
  });

  test('marks ambiguous or low-confidence text as needsReview (Perlu dicek)', () => {
    const res = parseReceiptOrNotificationText('catatan 75000 kemarin');
    assert.equal(res.ok, true);
    if (res.ok) {
      assert.equal(res.parsed.amount, 75000);
      assert.equal(res.parsed.needsReview, true);
      assert.equal(res.parsed.draftState, 'perlu_dicek');
      assert.equal(res.parsed.confidence, 'low');
    }
  });

  test('rejects text with zero or missing valid amount', () => {
    const emptyRes = parseReceiptOrNotificationText('');
    assert.equal(emptyRes.ok, false);

    const zeroRes = parseReceiptOrNotificationText('BCA: saldo Rp 0 berhasil dicek');
    assert.equal(zeroRes.ok, false);

    const noNumRes = parseReceiptOrNotificationText('Notifikasi tanpa angka apa pun');
    assert.equal(noNumRes.ok, false);
  });
});
