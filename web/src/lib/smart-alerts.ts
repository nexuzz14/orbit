import { formatCurrency } from './format';

export type SmartAlertType =
  | 'schedule_conflict'
  | 'task_stagnant'
  | 'task_overdue'
  | 'task_due_soon'
  | 'budget_warning'
  | 'budget_exceeded'
  | 'bill_due';

export type SmartAlertSeverity = 'danger' | 'warning' | 'info';

export interface SmartAlert {
  id: string;
  type: SmartAlertType;
  severity: SmartAlertSeverity;
  title: string;
  description: string;
  href: string;
  actionLabel: string;
  amount?: number;
}

export interface AlertEventInput {
  id: string;
  title: string;
  starts_at: string;
  ends_at: string;
  all_day?: boolean;
}

export interface AlertTaskInput {
  id: string;
  title: string;
  status: string;
  priority?: string | null;
  due_at?: string | null;
  updated_at?: string | null;
  created_at?: string | null;
  project_id?: string | null;
}

export interface AlertBudgetInput {
  budget_id?: string | null;
  category_id?: string | null;
  category_name?: string | null;
  effective_budget_amount?: number | null;
  spent_amount?: number | null;
  percentage_spent?: number | null;
  is_over_budget?: boolean | null;
  is_warning?: boolean | null;
  notify_at_percent?: number | null;
}

export interface AlertBillInput {
  id: string;
  name: string;
  amount: number;
  currency?: string;
  active?: boolean;
  schedule_type?: string;
  schedule_value?: number;
}

export interface DetectSmartAlertsInput {
  events?: AlertEventInput[];
  tasks?: AlertTaskInput[];
  budgets?: AlertBudgetInput[];
  bills?: AlertBillInput[];
  now?: Date;
  timezone?: string;
}

const MS_PER_HOUR = 60 * 60 * 1000;
const MS_PER_DAY = 24 * MS_PER_HOUR;

function formatTimeWib(isoOrDate: Date | string, timezone = 'Asia/Jakarta'): string {
  const date = typeof isoOrDate === 'string' ? new Date(isoOrDate) : isoOrDate;
  if (Number.isNaN(date.getTime())) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: timezone,
  }).format(date);
}

function getZonedDateParts(
  date: Date,
  timezone = 'Asia/Jakarta'
): { year: number; month: number; day: number; isoWeekday: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
  }).formatToParts(date);

  const map = new Map<string, string>();
  for (const part of parts) {
    map.set(part.type, part.value);
  }

  const year = Number(map.get('year') || date.getUTCFullYear());
  const month = Number(map.get('month') || date.getUTCMonth() + 1);
  const day = Number(map.get('day') || date.getUTCDate());

  const weekdayName = (map.get('weekday') || 'Mon').toLowerCase();
  const weekdayMap: Record<string, number> = {
    mon: 1,
    tue: 2,
    wed: 3,
    thu: 4,
    fri: 5,
    sat: 6,
    sun: 7,
  };

  return {
    year,
    month,
    day,
    isoWeekday: weekdayMap[weekdayName.slice(0, 3)] || 1,
  };
}

export function getDaysUntilBillDue(
  bill: Pick<AlertBillInput, 'schedule_type' | 'schedule_value'>,
  now: Date = new Date(),
  timezone = 'Asia/Jakarta'
): number | null {
  const scheduleValue = Number(bill.schedule_value ?? 0);
  if (!Number.isFinite(scheduleValue) || scheduleValue < 1) {
    return null;
  }

  const { year, month, day, isoWeekday } = getZonedDateParts(now, timezone);
  const todayMidnightUtc = Date.UTC(year, month - 1, day);

  if (bill.schedule_type === 'weekly') {
    const targetWeekday = ((scheduleValue - 1) % 7) + 1;
    let diff = targetWeekday - isoWeekday;
    if (diff < 0) diff += 7;
    return diff;
  }

  if (bill.schedule_type === 'yearly') {
    const daysInMonthThisYear = new Date(Date.UTC(year, month, 0)).getUTCDate();
    const clampedDayThis = Math.min(scheduleValue, daysInMonthThisYear);
    let candidate = Date.UTC(year, month - 1, clampedDayThis);
    if (candidate < todayMidnightUtc) {
      const daysInMonthNextYear = new Date(Date.UTC(year + 1, month, 0)).getUTCDate();
      candidate = Date.UTC(year + 1, month - 1, Math.min(scheduleValue, daysInMonthNextYear));
    }
    return Math.round((candidate - todayMidnightUtc) / MS_PER_DAY);
  }

  // Default monthly
  const daysInThisMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const clampedThis = Math.min(scheduleValue, daysInThisMonth);
  let candidateUtc = Date.UTC(year, month - 1, clampedThis);

  if (candidateUtc < todayMidnightUtc) {
    const nextMonthYear = month === 12 ? year + 1 : year;
    const nextMonth = month === 12 ? 1 : month + 1;
    const daysInNextMonth = new Date(Date.UTC(nextMonthYear, nextMonth, 0)).getUTCDate();
    candidateUtc = Date.UTC(
      nextMonthYear,
      nextMonth - 1,
      Math.min(scheduleValue, daysInNextMonth)
    );
  }

  return Math.round((candidateUtc - todayMidnightUtc) / MS_PER_DAY);
}

export function detectSmartAlerts(input: DetectSmartAlertsInput): SmartAlert[] {
  const now = input.now ?? new Date();
  const nowMs = now.getTime();
  const timezone = input.timezone || 'Asia/Jakarta';
  const alerts: SmartAlert[] = [];

  // 1. Deteksi jadwal bentrok (overlap WIB, abaikan all-day event)
  const timedEvents = (input.events ?? [])
    .filter((ev) => !ev.all_day)
    .map((ev) => ({
      ...ev,
      startMs: new Date(ev.starts_at).getTime(),
      endMs: new Date(ev.ends_at).getTime(),
    }))
    .filter(
      (ev) =>
        Number.isFinite(ev.startMs) &&
        Number.isFinite(ev.endMs) &&
        ev.endMs > ev.startMs &&
        ev.endMs >= nowMs - MS_PER_HOUR
    )
    .sort((a, b) => a.startMs - b.startMs);

  const conflictPairs = new Set<string>();
  for (let i = 0; i < timedEvents.length; i += 1) {
    for (let j = i + 1; j < timedEvents.length; j += 1) {
      const a = timedEvents[i];
      const b = timedEvents[j];
      if (b.startMs >= a.endMs) {
        break;
      }
      const pairKey = [a.id, b.id].sort().join('::');
      if (conflictPairs.has(pairKey)) continue;
      conflictPairs.add(pairKey);

      alerts.push({
        id: `conflict-${pairKey}`,
        type: 'schedule_conflict',
        severity: 'warning',
        title: `Jadwal bentrok: ${a.title} & ${b.title}`,
        description: `Tumpang tindih pukul ${formatTimeWib(a.starts_at, timezone)}-${formatTimeWib(a.ends_at, timezone)} WIB dengan ${formatTimeWib(b.starts_at, timezone)}-${formatTimeWib(b.ends_at, timezone)} WIB.`,
        href: '/jadwal',
        actionLabel: 'Tinjau Jadwal',
      });
    }
  }

  // 2. Deteksi tugas terlambat, H-24 jam, dan tugas macet > 5 hari
  for (const task of input.tasks ?? []) {
    if (task.status === 'done') continue;

    if (task.due_at) {
      const dueMs = new Date(task.due_at).getTime();
      if (Number.isFinite(dueMs)) {
        const diffMs = dueMs - nowMs;
        if (diffMs < 0) {
          const overdueHours = Math.max(1, Math.round(Math.abs(diffMs) / MS_PER_HOUR));
          alerts.push({
            id: `task-overdue-${task.id}`,
            type: 'task_overdue',
            severity: 'danger',
            title: `Tugas terlambat: ${task.title}`,
            description:
              overdueHours >= 24
                ? `Lewat tenggat sekitar ${Math.floor(overdueHours / 24)} hari.`
                : `Lewat tenggat sekitar ${overdueHours} jam.`,
            href: `/tugas?task=${encodeURIComponent(task.id)}`,
            actionLabel: 'Buka Tugas',
          });
        } else if (diffMs <= 24 * MS_PER_HOUR) {
          const remainHours = Math.max(1, Math.ceil(diffMs / MS_PER_HOUR));
          alerts.push({
            id: `task-due-${task.id}`,
            type: 'task_due_soon',
            severity: 'warning',
            title: `Tenggat H-24 jam: ${task.title}`,
            description: `Jatuh tempo dalam ${remainHours} jam ke depan (${formatTimeWib(task.due_at, timezone)} WIB).`,
            href: `/tugas?task=${encodeURIComponent(task.id)}`,
            actionLabel: 'Kerjakan',
          });
        }
      }
    }

    const touchIso = task.updated_at || task.created_at;
    if (touchIso) {
      const touchMs = new Date(touchIso).getTime();
      if (Number.isFinite(touchMs)) {
        const stagnantDays = Math.floor((nowMs - touchMs) / MS_PER_DAY);
        if (stagnantDays > 5) {
          alerts.push({
            id: `task-stagnant-${task.id}`,
            type: 'task_stagnant',
            severity: 'warning',
            title: `Tugas macet ${stagnantDays} hari: ${task.title}`,
            description: `Belum ada pembaruan status (${task.status}) selama lebih dari 5 hari.`,
            href: `/tugas?task=${encodeURIComponent(task.id)}`,
            actionLabel: 'Tindak Lanjuti',
          });
        }
      }
    }
  }

  // 3. Deteksi anggaran >= 80% dan >= 100%
  for (const budget of input.budgets ?? []) {
    const effective = Number(budget.effective_budget_amount ?? 0);
    const spent = Number(budget.spent_amount ?? 0);
    const computedPct =
      budget.percentage_spent != null
        ? Number(budget.percentage_spent)
        : effective > 0
          ? (spent / effective) * 100
          : 0;
    const roundedPct = Math.round(computedPct);
    const catName = budget.category_name?.trim() || 'Kategori Anggaran';
    const key = budget.budget_id || budget.category_id || catName;

    if (computedPct >= 100 || budget.is_over_budget) {
      alerts.push({
        id: `budget-over-${key}`,
        type: 'budget_exceeded',
        severity: 'danger',
        title: `Anggaran terlampaui (${roundedPct}%): ${catName}`,
        description: `Pengeluaran ${formatCurrency(spent)} telah melewati batas ${formatCurrency(effective)}.`,
        href: '/anggaran',
        actionLabel: 'Cek Anggaran',
        amount: spent,
      });
    } else if (computedPct >= 80) {
      alerts.push({
        id: `budget-warn-${key}`,
        type: 'budget_warning',
        severity: 'warning',
        title: `Anggaran mendekati batas (${roundedPct}%): ${catName}`,
        description: `Terpakai ${formatCurrency(spent)} dari alokasi ${formatCurrency(effective)}.`,
        href: '/anggaran',
        actionLabel: 'Pantau Anggaran',
        amount: spent,
      });
    }
  }

  // 4. Deteksi tagihan rutin H-3 .. H-0
  for (const bill of input.bills ?? []) {
    if (bill.active === false) continue;
    const daysUntil = getDaysUntilBillDue(bill, now, timezone);
    if (daysUntil === null || daysUntil < 0 || daysUntil > 3) continue;

    const hLabel = daysUntil === 0 ? 'Jatuh tempo hari ini (H-0)' : `Jatuh tempo H-${daysUntil}`;
    alerts.push({
      id: `bill-due-${bill.id}`,
      type: 'bill_due',
      severity: daysUntil === 0 ? 'danger' : 'warning',
      title: `Tagihan ${bill.name}: ${hLabel}`,
      description: `Nominal tagihan rutin ${formatCurrency(bill.amount, bill.currency || 'IDR')}.`,
      href: '/tagihan',
      actionLabel: 'Lihat Tagihan',
      amount: bill.amount,
    });
  }

  const severityRank: Record<SmartAlertSeverity, number> = {
    danger: 0,
    warning: 1,
    info: 2,
  };
  return alerts.sort((a, b) => severityRank[a.severity] - severityRank[b.severity]);
}

export interface DigestTransactionInput {
  id: string;
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  occurred_at: string;
  status?: string;
  deleted_at?: string | null;
}

export interface WeeklyDigestInput {
  tasks?: AlertTaskInput[];
  transactions?: DigestTransactionInput[];
  events?: AlertEventInput[];
  bills?: AlertBillInput[];
  now?: Date;
  timezone?: string;
  maskAmounts?: boolean;
  workspaceName?: string;
}

export interface WeeklyDigestSummary {
  periodLabel: string;
  past7Days: {
    completedTasksCount: number;
    incomeTotal: number;
    expenseTotal: number;
    netCashflow: number;
    savingsRatePercent: number | null;
  };
  next7Days: {
    activeTasksCount: number;
    overdueTasksCount: number;
    upcomingDueTasksCount: number;
    upcomingEventsCount: number;
    upcomingBillsCount: number;
    upcomingBillsTotal: number;
  };
  highlights: string[];
  plainText: string;
  htmlBody: string;
  mailtoHref: string;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function buildWeeklyDigestSummary(
  input: WeeklyDigestInput
): WeeklyDigestSummary {
  const now = input.now ?? new Date();
  const nowMs = now.getTime();
  const timezone = input.timezone || 'Asia/Jakarta';
  const pastStartMs = nowMs - 7 * MS_PER_DAY;
  const nextEndMs = nowMs + 7 * MS_PER_DAY;
  const maskAmounts = Boolean(input.maskAmounts);
  const fmtMoney = (val: number) => (maskAmounts ? 'Rp ••••••' : formatCurrency(val));

  const dateFmt = new Intl.DateTimeFormat('id-ID', {
    day: 'numeric',
    month: 'short',
    timeZone: timezone,
  });
  const periodLabel = `${dateFmt.format(new Date(pastStartMs))} - ${dateFmt.format(new Date(nextEndMs))}`;

  let completedTasksCount = 0;
  let activeTasksCount = 0;
  let overdueTasksCount = 0;
  let upcomingDueTasksCount = 0;

  for (const task of input.tasks ?? []) {
    if (task.status === 'done') {
      const doneMs = task.updated_at ? new Date(task.updated_at).getTime() : NaN;
      if (Number.isFinite(doneMs) && doneMs >= pastStartMs && doneMs <= nowMs) {
        completedTasksCount += 1;
      }
      continue;
    }

    activeTasksCount += 1;
    if (task.due_at) {
      const dueMs = new Date(task.due_at).getTime();
      if (Number.isFinite(dueMs)) {
        if (dueMs < nowMs) {
          overdueTasksCount += 1;
        } else if (dueMs <= nextEndMs) {
          upcomingDueTasksCount += 1;
        }
      }
    }
  }

  let incomeTotal = 0;
  let expenseTotal = 0;

  for (const tx of input.transactions ?? []) {
    if (tx.deleted_at) continue;
    if (tx.status && tx.status !== 'confirmed') continue;
    const txMs = new Date(tx.occurred_at).getTime();
    if (!Number.isFinite(txMs) || txMs < pastStartMs || txMs > nowMs) continue;

    const amt = Number(tx.amount ?? 0);
    if (!Number.isFinite(amt) || amt <= 0) continue;
    if (tx.type === 'income') incomeTotal += amt;
    if (tx.type === 'expense') expenseTotal += amt;
  }

  const netCashflow = incomeTotal - expenseTotal;
  const savingsRatePercent =
    incomeTotal > 0 ? Math.round((netCashflow / incomeTotal) * 100) : null;

  let upcomingEventsCount = 0;
  for (const ev of input.events ?? []) {
    const startMs = new Date(ev.starts_at).getTime();
    if (Number.isFinite(startMs) && startMs >= nowMs && startMs <= nextEndMs) {
      upcomingEventsCount += 1;
    }
  }

  let upcomingBillsCount = 0;
  let upcomingBillsTotal = 0;
  for (const bill of input.bills ?? []) {
    if (bill.active === false) continue;
    const daysUntil = getDaysUntilBillDue(bill, now, timezone);
    if (daysUntil !== null && daysUntil >= 0 && daysUntil <= 7) {
      upcomingBillsCount += 1;
      upcomingBillsTotal += Number(bill.amount ?? 0);
    }
  }

  const highlights: string[] = [
    `${completedTasksCount} tugas tuntas dalam 7 hari terakhir; ${activeTasksCount} tugas aktif (${overdueTasksCount} terlambat).`,
    `Arus kas 7 hari: masuk ${fmtMoney(incomeTotal)} vs keluar ${fmtMoney(expenseTotal)} (rasio tabungan ${
      savingsRatePercent !== null ? `${savingsRatePercent}%` : 'belum tersedia'
    }).`,
    `7 hari ke depan: ${upcomingDueTasksCount} tenggat tugas, ${upcomingEventsCount} agenda terjadwal, dan ${upcomingBillsCount} tagihan rutin (${fmtMoney(upcomingBillsTotal)}).`,
  ];

  const wsLabel = input.workspaceName?.trim() || 'Ruang Kerja Orbit';
  const plainText = [
    `Ringkasan Mingguan Orbit (${wsLabel})`,
    `Periode: ${periodLabel}`,
    '',
    '[7 Hari Terakhir]',
    `- Tugas selesai: ${completedTasksCount}`,
    `- Pemasukan: ${fmtMoney(incomeTotal)}`,
    `- Pengeluaran: ${fmtMoney(expenseTotal)}`,
    `- Arus kas bersih: ${fmtMoney(netCashflow)}`,
    `- Rasio tabungan: ${savingsRatePercent !== null ? `${savingsRatePercent}%` : '-'}`,
    '',
    '[7 Hari Ke Depan]',
    `- Tugas aktif: ${activeTasksCount} (terlambat: ${overdueTasksCount}, tenggat <= 7 hari: ${upcomingDueTasksCount})`,
    `- Agenda terjadwal: ${upcomingEventsCount}`,
    `- Tagihan rutin jatuh tempo: ${upcomingBillsCount} (${fmtMoney(upcomingBillsTotal)})`,
  ].join('\n');

  const htmlBody = [
    `<div style="font-family:Inter,Arial,sans-serif;color:#1F1F1D;max-width:560px">`,
    `<h2 style="margin:0 0 8px 0;color:#0284C7">Ringkasan Mingguan Orbit (${escapeHtml(wsLabel)})</h2>`,
    `<p style="margin:0 0 16px 0;color:#666661;font-size:13px">Periode ${escapeHtml(periodLabel)}</p>`,
    `<h3 style="margin:12px 0 6px 0;font-size:14px">7 Hari Terakhir</h3>`,
    `<ul style="margin:0;padding-left:18px;font-size:13px;line-height:1.6">`,
    `<li>Tugas selesai: <strong>${completedTasksCount}</strong></li>`,
    `<li>Pemasukan: <strong>${escapeHtml(fmtMoney(incomeTotal))}</strong></li>`,
    `<li>Pengeluaran: <strong>${escapeHtml(fmtMoney(expenseTotal))}</strong></li>`,
    `<li>Arus kas bersih: <strong>${escapeHtml(fmtMoney(netCashflow))}</strong> (rasio tabungan ${
      savingsRatePercent !== null ? `${savingsRatePercent}%` : '-'
    })</li>`,
    `</ul>`,
    `<h3 style="margin:14px 0 6px 0;font-size:14px">7 Hari Ke Depan</h3>`,
    `<ul style="margin:0;padding-left:18px;font-size:13px;line-height:1.6">`,
    `<li>Tugas aktif: <strong>${activeTasksCount}</strong> (terlambat: ${overdueTasksCount}, tenggat <= 7 hari: ${upcomingDueTasksCount})</li>`,
    `<li>Agenda terjadwal: <strong>${upcomingEventsCount}</strong></li>`,
    `<li>Tagihan rutin jatuh tempo: <strong>${upcomingBillsCount}</strong> (${escapeHtml(fmtMoney(upcomingBillsTotal))})</li>`,
    `</ul>`,
    `</div>`,
  ].join('');

  const subject = encodeURIComponent(`Ringkasan Mingguan Orbit (${periodLabel})`);
  const body = encodeURIComponent(plainText);
  const mailtoHref = `mailto:?subject=${subject}&body=${body}`;

  return {
    periodLabel,
    past7Days: {
      completedTasksCount,
      incomeTotal,
      expenseTotal,
      netCashflow,
      savingsRatePercent,
    },
    next7Days: {
      activeTasksCount,
      overdueTasksCount,
      upcomingDueTasksCount,
      upcomingEventsCount,
      upcomingBillsCount,
      upcomingBillsTotal,
    },
    highlights,
    plainText,
    htmlBody,
    mailtoHref,
  };
}

export interface ParsedReceiptDraft {
  amount: number;
  type: 'income' | 'expense';
  merchant: string;
  provider: string | null;
  occurredAt: string;
  hasExplicitDate: boolean;
  confidence: 'high' | 'medium' | 'low';
  needsReview: boolean;
  draftState: 'perlu_dicek' | 'perlu_dilengkapi';
  origin: 'notification' | 'receipt';
  reviewReasons: string[];
  note: string;
}

export type ParseReceiptResult =
  | {
      ok: true;
      parsed: ParsedReceiptDraft;
    }
  | {
      ok: false;
      error: string;
      parsed: null;
    };

const PROVIDER_PATTERNS: Array<{ name: string; regex: RegExp; origin: 'notification' | 'receipt' }> = [
  { name: 'BCA', regex: /\b(bca|mybca|bca mobile|klikbca)\b/i, origin: 'notification' },
  { name: 'Mandiri', regex: /\b(mandiri|livin)\b/i, origin: 'notification' },
  { name: 'BNI', regex: /\b(bni|wondr)\b/i, origin: 'notification' },
  { name: 'BRI', regex: /\b(bri|brimo)\b/i, origin: 'notification' },
  { name: 'GoPay', regex: /\b(gopay|go-pay|gojek)\b/i, origin: 'notification' },
  { name: 'OVO', regex: /\bovo\b/i, origin: 'notification' },
  { name: 'DANA', regex: /\bdana\b/i, origin: 'notification' },
  { name: 'ShopeePay', regex: /\b(shopeepay|shopee pay)\b/i, origin: 'notification' },
  { name: 'Alfamart', regex: /\b(alfamart|alfamidi)\b/i, origin: 'receipt' },
  { name: 'Indomaret', regex: /\b(indomaret|klikindomaret)\b/i, origin: 'receipt' },
  { name: 'QRIS', regex: /\bqris\b/i, origin: 'notification' },
];

const MONTHS_ID: Record<string, number> = {
  jan: 1,
  januari: 1,
  feb: 2,
  februari: 2,
  mar: 3,
  maret: 3,
  apr: 4,
  april: 4,
  mei: 5,
  may: 5,
  jun: 6,
  juni: 6,
  jul: 7,
  juli: 7,
  agu: 8,
  agt: 8,
  agustus: 8,
  aug: 8,
  sep: 9,
  sept: 9,
  september: 9,
  okt: 10,
  oktober: 10,
  oct: 10,
  nov: 11,
  november: 11,
  des: 12,
  desember: 12,
  dec: 12,
};

function normalizeIndonesianAmount(rawNumberToken: string): number {
  let cleaned = rawNumberToken.trim().replace(/\s+/g, '');
  if (!cleaned) return NaN;

  // Hapus sen desimal seperti ,00 atau .00 di akhir
  if (/,\d{1,2}$/.test(cleaned)) {
    cleaned = cleaned.replace(/,\d{1,2}$/, '');
  } else if (/\.\d{2}$/.test(cleaned) && !/\.\d{3}$/.test(cleaned)) {
    // Contoh 150000.00 atau 1,250.00
    cleaned = cleaned.replace(/\.\d{2}$/, '');
  }

  // Hapus pemisah ribuan titik atau koma
  const digitsOnly = cleaned.replace(/[.,]/g, '');
  if (!/^\d+$/.test(digitsOnly)) return NaN;

  const val = Number.parseInt(digitsOnly, 10);
  if (!Number.isFinite(val) || val <= 0 || val > 100_000_000_000) {
    return NaN;
  }
  return val;
}

function extractCandidateAmounts(text: string): Array<{
  amount: number;
  priority: number;
}> {
  const candidates: Array<{ amount: number; priority: number }> = [];
  const lines = text.split(/\r?\n/);

  for (const line of lines) {
    const isTotalLine = /\b(grand\s*total|total\s*bayar|total\s*belanja|total\s*pembayaran|total|jumlah|nominal|sebesar)\b/i.test(
      line
    );
    const isNoiseLine = /\b(kembali|kembalian|tunai|cash|poin|diskon|hemat|ppn|tax|pajak|saldo)\b/i.test(
      line
    );

    const regex = /(?:rp\.?|idr)?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{4,12}(?:[.,]\d{1,2})?)/gi;
    let match: RegExpExecArray | null;
    while ((match = regex.exec(line)) !== null) {
      const full = match[0];
      const token = match[1];
      // Abaikan tanggal atau tahun seperti 2026 atau nomor kartu/referensi > 12 digit
      if (!/[.,]/.test(token) && !/(?:rp|idr)/i.test(full) && !isTotalLine) {
        if (/^(19|20)\d{2}$/.test(token)) continue;
      }
      const parsedAmount = normalizeIndonesianAmount(token);
      if (Number.isNaN(parsedAmount)) continue;

      let priority = 1;
      if (/(?:rp|idr)/i.test(full)) priority += 2;
      if (isTotalLine) priority += 4;
      if (isNoiseLine && !isTotalLine) priority -= 2;

      candidates.push({ amount: parsedAmount, priority });
    }
  }

  return candidates.sort((a, b) => b.priority - a.priority || b.amount - a.amount);
}

function extractOccurredAtWib(
  text: string,
  fallbackNow: Date
): { iso: string; hasExplicitDate: boolean } {
  let hour = 12;
  let minute = 0;

  const timeMatch = text.match(/\b([01]?\d|2[0-3])[:.]([0-5]\d)(?:\s*(?:wib|wita|wit))?\b/i);
  if (timeMatch) {
    hour = Number.parseInt(timeMatch[1], 10);
    minute = Number.parseInt(timeMatch[2], 10);
  }

  const pad = (n: number) => String(n).padStart(2, '0');
  const buildWibIso = (y: number, m: number, d: number) =>
    `${y}-${pad(m)}-${pad(d)}T${pad(hour)}:${pad(minute)}:00+07:00`;

  // 1. DD/MM/YYYY or DD-MM-YYYY
  const dmyMatch = text.match(/\b(0?[1-9]|[12]\d|3[01])[/.-](0?[1-9]|1[0-2])[/.-](20\d{2})\b/);
  if (dmyMatch) {
    const day = Number.parseInt(dmyMatch[1], 10);
    const month = Number.parseInt(dmyMatch[2], 10);
    const year = Number.parseInt(dmyMatch[3], 10);
    return { iso: buildWibIso(year, month, day), hasExplicitDate: true };
  }

  // 2. YYYY-MM-DD
  const ymdMatch = text.match(/\b(20\d{2})[/.-](0?[1-9]|1[0-2])[/.-](0?[1-9]|[12]\d|3[01])\b/);
  if (ymdMatch) {
    const year = Number.parseInt(ymdMatch[1], 10);
    const month = Number.parseInt(ymdMatch[2], 10);
    const day = Number.parseInt(ymdMatch[3], 10);
    return { iso: buildWibIso(year, month, day), hasExplicitDate: true };
  }

  // 3. DD MMM YYYY (Indonesia)
  const monthTextMatch = text.match(
    /\b(0?[1-9]|[12]\d|3[01])\s+([a-z]{3,10})\s+(20\d{2})\b/i
  );
  if (monthTextMatch) {
    const monthNum = MONTHS_ID[monthTextMatch[2].toLowerCase()];
    if (monthNum) {
      const day = Number.parseInt(monthTextMatch[1], 10);
      const year = Number.parseInt(monthTextMatch[3], 10);
      return { iso: buildWibIso(year, monthNum, day), hasExplicitDate: true };
    }
  }

  return { iso: fallbackNow.toISOString(), hasExplicitDate: false };
}

function extractMerchantName(text: string, provider: string | null): {
  merchant: string;
  explicitMerchant: boolean;
} {
  // Cek pola eksplisit "di MERCHANT" atau "ke MERCHANT" atau "dari PENGIRIM"
  const contextualMatch = text.match(
    /\b(?:di|ke|merchant|toko|outlet|dari)\s+([A-Za-z0-9][A-Za-z0-9 .&'-]{1,42})(?=\s+(?:sebesar|senilai|senilai|rp|idr|pada|tgl|tanggal|\d{1,2}[/:.-]|sukses|berhasil|$)|[,\n]|$)/i
  );
  if (contextualMatch) {
    const candidate = contextualMatch[1]
      .replace(/\s+(?:pada|tanggal|sebesar|senilai|wib).*$/i, '')
      .trim();
    if (candidate.length >= 2 && !/^(rp|idr|rekening|akun|saldo)$/i.test(candidate)) {
      return { merchant: candidate, explicitMerchant: true };
    }
  }

  // Cek header toko pada struk baris 1-2
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length >= 3);

  for (const line of lines.slice(0, 2)) {
    if (/\b(alfamart|indomaret|alfamidi|superindo|lawson|familymart)\b/i.test(line)) {
      return { merchant: line.slice(0, 60), explicitMerchant: true };
    }
  }

  if (provider) {
    return { merchant: provider, explicitMerchant: false };
  }

  return { merchant: 'Transaksi Teks Tidak Dikenal', explicitMerchant: false };
}

export function parseReceiptOrNotificationText(
  rawText: string,
  now: Date = new Date()
): ParseReceiptResult {
  const text = rawText.trim();
  if (!text) {
    return {
      ok: false,
      error: 'Tempel teks notifikasi bank/e-wallet atau isi struk terlebih dahulu.',
      parsed: null,
    };
  }

  const candidates = extractCandidateAmounts(text);
  const bestCandidate = candidates[0];
  if (!bestCandidate || bestCandidate.amount <= 0) {
    return {
      ok: false,
      error: 'Nominal transaksi valid (> 0) tidak ditemukan dalam teks.',
      parsed: null,
    };
  }

  const matchedProvider = PROVIDER_PATTERNS.find((p) => p.regex.test(text)) ?? null;
  const provider = matchedProvider?.name ?? null;
  const isReceiptText =
    matchedProvider?.origin === 'receipt' ||
    /\b(struk|kasir|subtotal|grand\s*total|kembalian|indomaret|alfamart)\b/i.test(text);
  const origin: 'notification' | 'receipt' = isReceiptText ? 'receipt' : 'notification';

  const hasIncomeKeyword =
    /\b(kredit|cr\b|dana\s+masuk|uang\s+masuk|transfer\s+masuk|diterima|pembayaran\s+masuk|top\s*up\s*berhasil|cashback|refund|masuk\s+ke\s+rekening)\b/i.test(
      text
    );
  const hasExpenseKeyword =
    /\b(debit|db\b|pembayaran|transaksi|bayar|belanja|transfer\s+ke|qris|tarik\s+tunai|total\s+bayar|total|keluar)\b/i.test(
      text
    );

  let type: 'income' | 'expense' = 'expense';
  let ambiguousType = false;
  if (hasIncomeKeyword && !hasExpenseKeyword) {
    type = 'income';
  } else if (hasExpenseKeyword && !hasIncomeKeyword) {
    type = 'expense';
  } else if (hasIncomeKeyword && hasExpenseKeyword) {
    type = 'income';
    ambiguousType = true;
  } else {
    type = 'expense';
    ambiguousType = true;
  }

  const { merchant, explicitMerchant } = extractMerchantName(text, provider);
  const { iso: occurredAt, hasExplicitDate } = extractOccurredAtWib(text, now);

  const reviewReasons: string[] = [];
  if (!provider && !explicitMerchant) {
    reviewReasons.push('Sumber bank/merchant tidak terdeteksi jelas');
  }
  if (ambiguousType) {
    reviewReasons.push('Arah debit/kredit ambigu dan perlu verifikasi');
  }
  if (bestCandidate.priority < 3) {
    reviewReasons.push('Nominal ditemukan tanpa penanda Rp/Total eksplisit');
  }
  if (!hasExplicitDate) {
    reviewReasons.push('Tanggal transaksi tidak eksplisit pada teks');
  }

  let confidence: 'high' | 'medium' | 'low' = 'high';
  if (!provider && !explicitMerchant) {
    confidence = 'low';
  } else if (reviewReasons.length >= 2 || ambiguousType || bestCandidate.priority < 3) {
    confidence = 'low';
  } else if (reviewReasons.length === 1) {
    confidence = 'medium';
  }

  const needsReview = confidence === 'low' || ambiguousType || !explicitMerchant;

  return {
    ok: true,
    parsed: {
      amount: bestCandidate.amount,
      type,
      merchant,
      provider,
      occurredAt,
      hasExplicitDate,
      confidence,
      needsReview,
      draftState: needsReview ? 'perlu_dicek' : 'perlu_dilengkapi',
      origin,
      reviewReasons,
      note: text.slice(0, 240),
    },
  };
}
