export type ParsedMutationType = 'income' | 'expense';

export interface ParsedBankMutationRow {
  rowNumber: number;
  occurredDate: string; // YYYY-MM-DD
  occurredAt: string; // ISO string (+07:00)
  description: string;
  merchant: string;
  type: ParsedMutationType;
  amount: number;
  balance: number | null;
  rawTypeHint: string | null;
}

export interface ParsedCsvMutationResult {
  delimiter: ',' | ';' | '\t';
  rows: ParsedBankMutationRow[];
  skippedRows: Array<{ rowNumber: number; reason: string }>;
}

export interface CsvTransactionExportRow {
  occurred_at: string;
  type: string;
  category_name: string | null;
  account_name: string | null;
  source: string;
  project_name?: string | null;
  merchant: string | null;
  note: string | null;
  status: string;
  currency: string;
  amount: number;
  amount_base: number;
}

export interface ProjectReportCsvRow {
  project_name: string;
  kind: string;
  client_name: string | null;
  status: string;
  currency: string;
  contract_value: number;
  total_invoiced: number;
  total_paid: number;
  remaining_invoiced: number;
  total_expense: number;
  net_profit: number;
  margin_percent: number | null;
}

export interface MonthlySummaryInput {
  month_start: string;
  income: number;
  expense: number;
  net: number;
}

export interface MonthlyCashflowPoint {
  monthKey: string; // YYYY-MM
  label: string;
  income: number;
  expense: number;
  net: number;
}

export interface CategorySummaryInput {
  category_id: string | null;
  category_name: string | null;
  type: string;
  total: number;
  txn_count: number;
}

export interface CategoryBreakdownItem {
  key: string;
  name: string;
  total: number;
  txnCount: number;
  sharePercent: number;
}

const FORMULA_INJECTION_RE = /^[=+\-@\t\r]/;

/**
 * Mengamankan sel CSV dari formula injection (=, +, -, @, tab, CR) serta escaping kutip ganda RFC 4180.
 */
export function escapeCsvCell(value: string | number | boolean | null | undefined): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') {
    return Number.isFinite(value) ? String(value) : '';
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false';
  }

  let text = String(value).replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  if (FORMULA_INJECTION_RE.test(text)) {
    text = `'${text}`;
  }

  if (text.includes('"') || text.includes(',') || text.includes(';') || text.includes('\n')) {
    return `"${text.replace(/"/g, '""')}"`;
  }

  return text;
}

function buildCsvDocument(headers: string[], rows: Array<Array<string | number | boolean | null | undefined>>): string {
  const headerLine = headers.map((h) => escapeCsvCell(h)).join(',');
  const dataLines = rows.map((row) => row.map((cell) => escapeCsvCell(cell)).join(','));
  // BOM UTF-8 agar Excel Windows membaca karakter & angka dengan benar
  return `\uFEFF${[headerLine, ...dataLines].join('\r\n')}\r\n`;
}

export function exportTransactionsToCsv(rows: CsvTransactionExportRow[]): string {
  return buildCsvDocument(
    [
      'Tanggal',
      'Tipe',
      'Kategori',
      'Akun',
      'Sumber',
      'Proyek',
      'Merchant',
      'Catatan',
      'Status',
      'Mata Uang',
      'Nominal',
      'Nominal Dasar (IDR)',
    ],
    rows.map((r) => [
      r.occurred_at.slice(0, 10),
      r.type,
      r.category_name || 'Tanpa Kategori',
      r.account_name || '-',
      r.source,
      r.project_name || '-',
      r.merchant || '',
      r.note || '',
      r.status,
      r.currency,
      r.amount,
      r.amount_base,
    ])
  );
}

export function exportProjectReportToCsv(rows: ProjectReportCsvRow[]): string {
  return buildCsvDocument(
    [
      'Proyek',
      'Kategori',
      'Klien',
      'Status',
      'Mata Uang',
      'Nilai Kontrak',
      'Total Ditagihkan',
      'Pembayaran Masuk',
      'Sisa Tagihan',
      'Total Pengeluaran',
      'Margin Bersih',
      'Margin (%)',
    ],
    rows.map((r) => [
      r.project_name,
      r.kind,
      r.client_name || '-',
      r.status,
      r.currency,
      r.contract_value,
      r.total_invoiced,
      r.total_paid,
      r.remaining_invoiced,
      r.total_expense,
      r.net_profit,
      r.margin_percent ?? 0,
    ])
  );
}

function detectCsvDelimiter(firstLine: string): ',' | ';' | '\t' {
  let commaCount = 0;
  let semiCount = 0;
  let tabCount = 0;
  let inQuotes = false;

  for (let i = 0; i < firstLine.length; i++) {
    const ch = firstLine[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes) {
      if (ch === ',') commaCount += 1;
      else if (ch === ';') semiCount += 1;
      else if (ch === '\t') tabCount += 1;
    }
  }

  if (semiCount > commaCount && semiCount >= tabCount) return ';';
  if (tabCount > commaCount && tabCount > semiCount) return '\t';
  return ',';
}

function splitCsvLinesAndCells(rawText: string, delimiter: ',' | ';' | '\t'): string[][] {
  const cleaned = rawText.replace(/^\uFEFF/, '');
  const records: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let inQuotes = false;

  for (let i = 0; i < cleaned.length; i++) {
    const ch = cleaned[i];
    if (inQuotes) {
      if (ch === '"') {
        if (cleaned[i + 1] === '"') {
          cell += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        cell += ch;
      }
      continue;
    }

    if (ch === '"') {
      inQuotes = true;
    } else if (ch === delimiter) {
      row.push(cell.trim());
      cell = '';
    } else if (ch === '\r') {
      if (cleaned[i + 1] === '\n') i += 1;
      row.push(cell.trim());
      if (row.some((c) => c.length > 0)) {
        records.push(row);
      }
      row = [];
      cell = '';
    } else if (ch === '\n') {
      row.push(cell.trim());
      if (row.some((c) => c.length > 0)) {
        records.push(row);
      }
      row = [];
      cell = '';
    } else {
      cell += ch;
    }
  }

  row.push(cell.trim());
  if (row.some((c) => c.length > 0)) {
    records.push(row);
  }

  return records;
}

function normalizeHeader(h: string): string {
  return h
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function parseMutationDate(raw: string): string | null {
  const text = raw.trim();
  if (!text) return null;

  // YYYY-MM-DD atau YYYY/MM/DD
  let m = /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T\s].*)?$/.exec(text);
  if (m) {
    const yr = Number(m[1]);
    const mo = Number(m[2]);
    const dy = Number(m[3]);
    if (mo >= 1 && mo <= 12 && dy >= 1 && dy <= 31) {
      return `${yr}-${String(mo).padStart(2, '0')}-${String(dy).padStart(2, '0')}`;
    }
  }

  // DD/MM/YYYY atau DD-MM-YYYY atau DD/MM/YY
  m = /^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})(?:\s.*)?$/.exec(text);
  if (m) {
    const dy = Number(m[1]);
    const mo = Number(m[2]);
    let yr = Number(m[3]);
    if (yr < 100) yr += 2000;
    if (mo >= 1 && mo <= 12 && dy >= 1 && dy <= 31) {
      return `${yr}-${String(mo).padStart(2, '0')}-${String(dy).padStart(2, '0')}`;
    }
  }

  return null;
}

function parseLocalizedNumber(raw: string): {
  value: number | null;
  trailingHint: ParsedMutationType | null;
} {
  let text = raw.trim();
  if (!text || text === '-') return { value: null, trailingHint: null };

  let trailingHint: ParsedMutationType | null = null;
  if (/\b(DB|DR|DEBIT|KELUAR)\b$/i.test(text)) {
    trailingHint = 'expense';
    text = text.replace(/\b(DB|DR|DEBIT|KELUAR)\b$/i, '').trim();
  } else if (/\b(CR|KREDIT|MASUK)\b$/i.test(text)) {
    trailingHint = 'income';
    text = text.replace(/\b(CR|KREDIT|MASUK)\b$/i, '').trim();
  }

  const isParenNegative = /^\(.*\)$/.test(text);
  text = text.replace(/[()RpIDR\s]/gi, '');
  const hasLeadingMinus = text.startsWith('-');
  text = text.replace(/^[+-]/, '');

  if (!text || !/\d/.test(text)) return { value: null, trailingHint };

  const lastComma = text.lastIndexOf(',');
  const lastDot = text.lastIndexOf('.');

  let normalized = text;
  if (lastComma > -1 && lastDot > -1) {
    // Pemisah terakhir adalah desimal
    if (lastComma > lastDot) {
      normalized = text.replace(/\./g, '').replace(',', '.');
    } else {
      normalized = text.replace(/,/g, '');
    }
  } else if (lastComma > -1) {
    const decimals = text.length - lastComma - 1;
    // Jika persis 3 digit di belakang koma (150,000), anggap pemisah ribuan
    normalized = decimals === 3 ? text.replace(/,/g, '') : text.replace(',', '.');
  } else if (lastDot > -1) {
    const decimals = text.length - lastDot - 1;
    // Pada format mutasi Indonesia, 150.000 berarti pemisah ribuan
    normalized = decimals === 3 ? text.replace(/\./g, '') : text;
  }

  const num = Number(normalized);
  if (!Number.isFinite(num)) return { value: null, trailingHint };
  const signed = isParenNegative || hasLeadingMinus ? -Math.abs(num) : num;
  return { value: signed, trailingHint };
}

/**
 * Mem-parse CSV mutasi rekening bank (separator `,`, `;`, atau tab) menjadi baris transaksi bersih.
 */
export function parseBankMutationCsv(csvText: string): ParsedCsvMutationResult {
  const firstLine = csvText.replace(/^\uFEFF/, '').split(/\r?\n/)[0] ?? '';
  const delimiter = detectCsvDelimiter(firstLine);
  const records = splitCsvLinesAndCells(csvText, delimiter);

  if (records.length < 2) {
    return {
      delimiter,
      rows: [],
      skippedRows: records.length === 1 ? [{ rowNumber: 1, reason: 'Hanya header tanpa baris transaksi' }] : [],
    };
  }

  const headers = records[0].map(normalizeHeader);
  const findCol = (aliases: string[]): number =>
    headers.findIndex((h) => aliases.some((a) => h === a || h.includes(a)));

  const dateCol = findCol(['tanggal', 'tgl', 'date', 'posted', 'waktu']);
  const descCol = findCol(['keterangan', 'deskripsi', 'uraian', 'description', 'merchant', 'berita', 'catatan']);
  const debitCol = findCol(['debit', 'debet', 'keluar', 'pengeluaran', 'withdrawal']);
  const creditCol = findCol(['kredit', 'credit', 'masuk', 'pemasukan', 'deposit']);
  const amountCol = findCol(['nominal', 'jumlah', 'amount', 'nilai', 'mutasi']);
  const typeCol = findCol(['tipe', 'type', 'jenis', 'd k', 'dk', 'mutasi type']);
  const balanceCol = findCol(['saldo', 'balance']);

  const rows: ParsedBankMutationRow[] = [];
  const skippedRows: Array<{ rowNumber: number; reason: string }> = [];

  for (let idx = 1; idx < records.length; idx++) {
    const rec = records[idx];
    const rowNumber = idx + 1;

    const rawDate = dateCol >= 0 ? rec[dateCol] ?? '' : rec[0] ?? '';
    const occurredDate = parseMutationDate(rawDate);
    if (!occurredDate) {
      skippedRows.push({ rowNumber, reason: `Tanggal tidak dikenali (${rawDate || 'kosong'})` });
      continue;
    }

    const rawDesc =
      descCol >= 0
        ? rec[descCol] ?? ''
        : rec.find((_, colIdx) => colIdx !== dateCol) ?? '';
    const cleanDesc = rawDesc.replace(/\s+/g, ' ').trim();

    let resolvedType: ParsedMutationType | null = null;
    let resolvedAmount = 0;

    if (debitCol >= 0 || creditCol >= 0) {
      const deb = debitCol >= 0 ? parseLocalizedNumber(rec[debitCol] ?? '') : { value: null, trailingHint: null };
      const cr = creditCol >= 0 ? parseLocalizedNumber(rec[creditCol] ?? '') : { value: null, trailingHint: null };
      const debAbs = deb.value !== null ? Math.abs(deb.value) : 0;
      const crAbs = cr.value !== null ? Math.abs(cr.value) : 0;

      if (crAbs > 0 && debAbs === 0) {
        resolvedType = 'income';
        resolvedAmount = crAbs;
      } else if (debAbs > 0 && crAbs === 0) {
        resolvedType = 'expense';
        resolvedAmount = debAbs;
      } else if (crAbs > 0 || debAbs > 0) {
        resolvedType = crAbs >= debAbs ? 'income' : 'expense';
        resolvedAmount = Math.max(crAbs, debAbs);
      }
    }

    if (resolvedAmount <= 0 && amountCol >= 0) {
      const parsedAmt = parseLocalizedNumber(rec[amountCol] ?? '');
      if (parsedAmt.value !== null && Math.abs(parsedAmt.value) > 0) {
        resolvedAmount = Math.abs(parsedAmt.value);
        if (parsedAmt.trailingHint) {
          resolvedType = parsedAmt.trailingHint;
        } else if (parsedAmt.value < 0) {
          resolvedType = 'expense';
        } else {
          resolvedType = 'income';
        }
      }
    }

    const rawTypeHint = typeCol >= 0 ? (rec[typeCol] ?? '').trim() : null;
    if (rawTypeHint) {
      const upperHint = rawTypeHint.toUpperCase();
      if (/^(DB|DR|D|DEBIT|DEBET|EXPENSE|KELUAR|PENGELUARAN)$/.test(upperHint)) {
        resolvedType = 'expense';
      } else if (/^(CR|K|C|KREDIT|CREDIT|INCOME|MASUK|PEMASUKAN)$/.test(upperHint)) {
        resolvedType = 'income';
      }
    }

    if (!resolvedType || resolvedAmount <= 0) {
      skippedRows.push({ rowNumber, reason: 'Nominal kosong atau nol' });
      continue;
    }

    const parsedBal = balanceCol >= 0 ? parseLocalizedNumber(rec[balanceCol] ?? '') : { value: null };
    const merchant = cleanDesc.slice(0, 80) || 'Mutasi Rekening';

    rows.push({
      rowNumber,
      occurredDate,
      occurredAt: new Date(`${occurredDate}T12:00:00+07:00`).toISOString(),
      description: cleanDesc || merchant,
      merchant,
      type: resolvedType,
      amount: Math.round(resolvedAmount * 100) / 100,
      balance: parsedBal.value,
      rawTypeHint: rawTypeHint || null,
    });
  }

  return { delimiter, rows, skippedRows };
}

/**
 * Menyusun deret waktu arus kas bulanan (diurutkan kronologis) untuk grafik ringkasan.
 */
export function buildMonthlyCashflowSeries(
  rows: MonthlySummaryInput[],
  maxMonths = 6
): MonthlyCashflowPoint[] {
  const byMonth = new Map<string, { income: number; expense: number; net: number }>();

  for (const row of rows) {
    if (!row.month_start) continue;
    const key = row.month_start.slice(0, 7);
    const prev = byMonth.get(key) ?? { income: 0, expense: 0, net: 0 };
    const income = prev.income + Number(row.income || 0);
    const expense = prev.expense + Number(row.expense || 0);
    byMonth.set(key, {
      income,
      expense,
      net: income - expense,
    });
  }

  const sortedKeys = Array.from(byMonth.keys()).sort();
  const slicedKeys = sortedKeys.slice(-Math.max(1, maxMonths));

  const formatter = new Intl.DateTimeFormat('id-ID', {
    month: 'short',
    year: '2-digit',
  });

  return slicedKeys.map((key) => {
    const val = byMonth.get(key)!;
    const dt = new Date(`${key}-01T12:00:00+07:00`);
    const label = Number.isNaN(dt.getTime()) ? key : formatter.format(dt);
    return {
      monthKey: key,
      label,
      income: val.income,
      expense: val.expense,
      net: val.net,
    };
  });
}

/**
 * Menyusun breakdown kategori teratas beserta persentase kontribusi untuk grafik horizontal.
 */
export function buildCategoryBreakdown(
  rows: CategorySummaryInput[],
  targetType: 'expense' | 'income' = 'expense',
  limit = 6
): CategoryBreakdownItem[] {
  const byCat = new Map<string, { name: string; total: number; txnCount: number }>();

  for (const row of rows) {
    if (row.type !== targetType) continue;
    const amount = Number(row.total || 0);
    if (amount <= 0) continue;
    const key = row.category_id || row.category_name || 'tanpa-kategori';
    const name = row.category_name?.trim() || 'Tanpa Kategori';
    const prev = byCat.get(key) ?? { name, total: 0, txnCount: 0 };
    byCat.set(key, {
      name,
      total: prev.total + amount,
      txnCount: prev.txnCount + Number(row.txn_count || 0),
    });
  }

  const sorted = Array.from(byCat.entries())
    .map(([key, val]) => ({ key, ...val }))
    .sort((a, b) => b.total - a.total);

  const grandTotal = sorted.reduce((acc, item) => acc + item.total, 0);
  if (grandTotal <= 0) return [];

  const capped = sorted.slice(0, limit);
  const tail = sorted.slice(limit);

  if (tail.length > 0) {
    const tailTotal = tail.reduce((acc, item) => acc + item.total, 0);
    const tailCount = tail.reduce((acc, item) => acc + item.txnCount, 0);
    capped.push({
      key: 'other-categories',
      name: `Lainnya (${tail.length} kategori)`,
      total: tailTotal,
      txnCount: tailCount,
    });
  }

  return capped.map((item) => ({
    ...item,
    sharePercent: Math.round((item.total / grandTotal) * 1000) / 10,
  }));
}
