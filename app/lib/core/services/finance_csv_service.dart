import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';

class ParsedBankMutationItem {
  final DateTime date;
  final String merchant;
  final String note;
  final double amount;
  final String type; // 'income' | 'expense'
  final String rawLine;

  const ParsedBankMutationItem({
    required this.date,
    required this.merchant,
    required this.note,
    required this.amount,
    required this.type,
    required this.rawLine,
  });
}

class ProjectFinancialReportRow {
  final String projectId;
  final String projectName;
  final String kind;
  final String status;
  final String? clientName;
  final double contractValue;
  final double paidAmount;
  final double remainingReceivable;
  final double totalExpenses;

  const ProjectFinancialReportRow({
    required this.projectId,
    required this.projectName,
    required this.kind,
    required this.status,
    this.clientName,
    required this.contractValue,
    required this.paidAmount,
    required this.remainingReceivable,
    required this.totalExpenses,
  });

  double get netMargin => paidAmount - totalExpenses;

  double get projectedMargin =>
      (contractValue > 0 ? contractValue : paidAmount) - totalExpenses;
}

class FinanceCsvService {
  const FinanceCsvService._();

  static const String sampleBankMutationCsv =
      'Tanggal;Keterangan;Debit;Kredit\n'
      '15/11/2026;"QRIS Kopi Kenangan Jakarta";28.500;0\n'
      '15/11/2026;"Transfer Masuk Termin UI Dashboard";0;3.500.000\n'
      '16/11/2026;"Langganan Cloud Hosting Bulanan";185.000,00;0\n'
      '16/11/2026;"Stipend Riset Laboratorium";0;1.200.000\n';

  /// Mem-parse CSV mutasi bank Indonesia (mendukung koma `,` atau titik koma `;`,
  /// tanda kutip, kolom `Debit`/`Kredit` terpisah maupun kolom `Nominal` bertanda).
  static List<ParsedBankMutationItem> parseBankMutationCsv(String rawCsv) {
    final cleaned = rawCsv.replaceFirst('\uFEFF', '').trim();
    if (cleaned.isEmpty) return const [];

    final delimiter = _detectDelimiter(cleaned);
    final rows = _parseCsvTable(cleaned, delimiter);
    if (rows.isEmpty) return const [];

    final headers = rows.first.map(_normalizeHeader).toList();
    final hasKnownHeader = headers.any(
      (h) =>
          h.contains('tanggal') ||
          h.contains('tgl') ||
          h.contains('date') ||
          h.contains('keterangan') ||
          h.contains('uraian') ||
          h.contains('deskripsi') ||
          h.contains('nominal') ||
          h.contains('debit') ||
          h.contains('debet') ||
          h.contains('kredit') ||
          h.contains('credit') ||
          h.contains('amount') ||
          h.contains('jumlah'),
    );

    final colMap = _ColumnMap.fromHeaders(headers);
    final startRow = hasKnownHeader ? 1 : 0;
    final items = <ParsedBankMutationItem>[];

    for (var i = startRow; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;

      final rawDate = hasKnownHeader
          ? _cellAt(row, colMap.dateIdx)
          : _cellAt(row, 0);
      final parsedDate = _parseDate(rawDate);
      if (parsedDate == null) continue;

      final rawDesc = hasKnownHeader
          ? _cellAt(row, colMap.descIdx)
          : _cellAt(row, 1);
      final descLower = rawDesc.toLowerCase();
      if (descLower.contains('saldo awal') ||
          descLower.contains('saldo akhir') ||
          descLower.contains('opening balance') ||
          descLower.contains('closing balance')) {
        continue;
      }

      double amount = 0;
      String? type;

      if (hasKnownHeader &&
          (colMap.debitIdx >= 0 || colMap.creditIdx >= 0)) {
        final debitVal = colMap.debitIdx >= 0
            ? _parseMoney(_cellAt(row, colMap.debitIdx)).amount
            : 0.0;
        final creditVal = colMap.creditIdx >= 0
            ? _parseMoney(_cellAt(row, colMap.creditIdx)).amount
            : 0.0;

        if (creditVal > 0 && debitVal == 0) {
          amount = creditVal;
          type = 'income';
        } else if (debitVal > 0 && creditVal == 0) {
          amount = debitVal;
          type = 'expense';
        } else if (creditVal > 0) {
          amount = creditVal;
          type = 'income';
        } else if (debitVal > 0) {
          amount = debitVal;
          type = 'expense';
        }
      }

      if (amount == 0) {
        final amountIdx = hasKnownHeader
            ? (colMap.amountIdx >= 0 ? colMap.amountIdx : (row.length > 2 ? 2 : -1))
            : (row.length > 2 ? 2 : -1);
        if (amountIdx >= 0) {
          final parsedMoney = _parseMoney(_cellAt(row, amountIdx));
          if (parsedMoney.amount > 0) {
            amount = parsedMoney.amount;
            final typeCell = hasKnownHeader && colMap.typeIdx >= 0
                ? _cellAt(row, colMap.typeIdx).toLowerCase()
                : '';
            if (parsedMoney.hintType != null) {
              type = parsedMoney.hintType;
            } else if (_isIncomeKeyword(typeCell)) {
              type = 'income';
            } else if (_isExpenseKeyword(typeCell)) {
              type = 'expense';
            } else {
              type = parsedMoney.isNegative ? 'expense' : 'income';
            }
          }
        }
      }

      if (amount <= 0 || type == null) continue;

      final cleanNote = rawDesc.trim().isEmpty
          ? 'Mutasi CSV'
          : rawDesc.trim().replaceAll(RegExp(r'\s+'), ' ');
      final merchant = _extractMerchantName(cleanNote);

      items.add(
        ParsedBankMutationItem(
          date: parsedDate,
          merchant: merchant,
          note: cleanNote,
          amount: amount,
          type: type,
          rawLine: row.join(delimiter),
        ),
      );
    }

    return items;
  }

  /// Mengamankan sel CSV dari pemecahan kolom dan injeksi formula spreadsheet.
  static String escapeCsvCell(String value) {
    var safe = value;
    var formulaSanitized = false;
    if (safe.isNotEmpty) {
      final first = safe[0];
      if (first == '=' ||
          first == '+' ||
          first == '-' ||
          first == '@' ||
          first == '\t' ||
          first == '\r') {
        safe = "'$safe";
        formulaSanitized = true;
      }
    }
    final needsQuotes =
        formulaSanitized ||
        safe.contains(',') ||
        safe.contains(';') ||
        safe.contains('"') ||
        safe.contains('\n') ||
        safe.contains('\r');
    if (!needsQuotes) return safe;
    return '"${safe.replaceAll('"', '""')}"';
  }

  /// Mengekspor daftar transaksi lokal ke format CSV dengan escaping aman.
  static String exportTransactionsCsv(
    List<LocalTransaction> transactions,
    Map<String, String> accountNames,
    Map<String, String> categoryNames, {
    Map<String, String> projectNames = const {},
  }) {
    final active = transactions.where((t) => t.deletedAt == null).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final buffer = StringBuffer();
    buffer.writeln(
      'ID,Tanggal,Tipe,Status,Nominal,Mata Uang,Akun,Kategori,Sumber,Proyek,Merchant,Catatan',
    );
    for (final tx in active) {
      final wib = tx.occurredAt.toUtc().add(const Duration(hours: 7));
      final dateStr =
          '${wib.year.toString().padLeft(4, '0')}-'
          '${wib.month.toString().padLeft(2, '0')}-'
          '${wib.day.toString().padLeft(2, '0')} '
          '${wib.hour.toString().padLeft(2, '0')}:'
          '${wib.minute.toString().padLeft(2, '0')}';
      final row = <String>[
        tx.id,
        dateStr,
        tx.type,
        tx.status,
        tx.amount.toStringAsFixed(0),
        tx.currency,
        accountNames[tx.accountId] ?? tx.accountId,
        tx.categoryId == null
            ? '-'
            : (categoryNames[tx.categoryId] ?? tx.categoryId!),
        tx.source ?? '-',
        tx.projectId == null
            ? '-'
            : (projectNames[tx.projectId] ?? tx.projectId!),
        tx.merchant ?? '-',
        tx.note ?? '-',
      ];
      buffer.writeln(row.map(escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  /// Mengekspor laporan kontrak, piutang, pengeluaran, dan margin proyek ke CSV.
  static String exportProjectReportCsv(List<ProjectFinancialReportRow> rows) {
    final buffer = StringBuffer();
    buffer.writeln(
      'ID Proyek,Nama Proyek,Jenis,Status,Klien,Nilai Kontrak,Terbayar,Sisa Tagihan,Pengeluaran Proyek,Margin Bersih',
    );
    for (final row in rows) {
      final cells = <String>[
        row.projectId,
        row.projectName,
        row.kind,
        row.status,
        row.clientName ?? '-',
        row.contractValue.toStringAsFixed(0),
        row.paidAmount.toStringAsFixed(0),
        row.remainingReceivable.toStringAsFixed(0),
        row.totalExpenses.toStringAsFixed(0),
        row.netMargin.toStringAsFixed(0),
      ];
      buffer.writeln(cells.map(escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  /// Menyusun ringkasan teks siap cetak/PDF untuk disalin pengguna.
  static String buildTextSummaryReport({
    required List<LocalTransaction> transactions,
    required Map<String, String> accountNames,
    required Map<String, String> categoryNames,
  }) {
    final active = transactions.where((t) => t.deletedAt == null).toList();
    double totalIncome = 0;
    double totalExpense = 0;
    final categoryTotals = <String, double>{};

    for (final tx in active) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
        final catName = tx.categoryId == null
            ? 'Tanpa Kategori'
            : (categoryNames[tx.categoryId] ?? 'Lainnya');
        categoryTotals[catName] = (categoryTotals[catName] ?? 0) + tx.amount;
      }
    }

    final topCats = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buf = StringBuffer();
    buf.writeln('LAPORAN RINGKAS KEUANGAN ORBIT');
    buf.writeln('Jumlah Transaksi : ${active.length}');
    buf.writeln('Total Pemasukan  : ${formatRupiah(totalIncome)}');
    buf.writeln('Total Pengeluaran: ${formatRupiah(totalExpense)}');
    buf.writeln('Arus Kas Bersih  : ${formatRupiah(totalIncome - totalExpense)}');
    buf.writeln('');
    buf.writeln('Top Kategori Pengeluaran:');
    if (topCats.isEmpty) {
      buf.writeln('- Belum ada pengeluaran tercatat.');
    } else {
      for (final entry in topCats.take(5)) {
        buf.writeln('- ${entry.key}: ${formatRupiah(entry.value)}');
      }
    }
    buf.writeln('');
    buf.writeln('Daftar Akun Terlibat (${accountNames.length}):');
    for (final name in accountNames.values) {
      buf.writeln('- $name');
    }
    return buf.toString();
  }

  static String _detectDelimiter(String csv) {
    final sampleLines = csv.split(RegExp(r'\r?\n')).take(5).join('\n');
    final semiCount = _countDelimiterOutsideQuotes(sampleLines, ';');
    final commaCount = _countDelimiterOutsideQuotes(sampleLines, ',');
    return semiCount >= commaCount && semiCount > 0 ? ';' : ',';
  }

  static int _countDelimiterOutsideQuotes(String text, String delim) {
    var count = 0;
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (!inQuotes && ch == delim) {
        count++;
      }
    }
    return count;
  }

  static List<List<String>> _parseCsvTable(String text, String delimiter) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          currentCell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && ch == delimiter) {
        currentRow.add(currentCell.toString());
        currentCell.clear();
      } else if (!inQuotes && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentCell.toString());
        currentCell.clear();
        rows.add(currentRow);
        currentRow = <String>[];
      } else {
        currentCell.write(ch);
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      rows.add(currentRow);
    }
    return rows;
  }

  static String _normalizeHeader(String header) {
    return header
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static String _cellAt(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  static DateTime? _parseDate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;

    // dd/MM/yyyy atau dd-MM-yyyy (optional HH:mm(:ss))
    final idMatch = RegExp(
      r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(v);
    if (idMatch != null) {
      final day = int.parse(idMatch.group(1)!);
      final month = int.parse(idMatch.group(2)!);
      var year = int.parse(idMatch.group(3)!);
      if (year < 100) year += 2000;
      final hour = int.tryParse(idMatch.group(4) ?? '') ?? 12;
      final minute = int.tryParse(idMatch.group(5) ?? '') ?? 0;
      final second = int.tryParse(idMatch.group(6) ?? '') ?? 0;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    // yyyy-MM-dd or ISO8601
    final isoMatch = RegExp(
      r'^(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})(?:[T\s](\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(v);
    if (isoMatch != null) {
      final year = int.parse(isoMatch.group(1)!);
      final month = int.parse(isoMatch.group(2)!);
      final day = int.parse(isoMatch.group(3)!);
      final hour = int.tryParse(isoMatch.group(4) ?? '') ?? 12;
      final minute = int.tryParse(isoMatch.group(5) ?? '') ?? 0;
      final second = int.tryParse(isoMatch.group(6) ?? '') ?? 0;
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    return DateTime.tryParse(v);
  }

  static _ParsedMoney _parseMoney(String raw) {
    var v = raw.trim();
    if (v.isEmpty || v == '-' || v == '0') {
      return const _ParsedMoney(amount: 0);
    }

    String? hintType;
    final upper = v.toUpperCase();
    if (upper.endsWith('DB') || upper.endsWith('DR')) {
      hintType = 'expense';
      v = v.substring(0, v.length - 2).trim();
    } else if (upper.endsWith('CR')) {
      hintType = 'income';
      v = v.substring(0, v.length - 2).trim();
    }

    var isNegative = false;
    if (v.startsWith('(') && v.endsWith(')')) {
      isNegative = true;
      v = v.substring(1, v.length - 1).trim();
    }
    if (v.startsWith('-')) {
      isNegative = true;
      v = v.substring(1).trim();
    } else if (v.startsWith('+')) {
      v = v.substring(1).trim();
    }

    v = v.replaceAll(RegExp(r'idr|rp|\s', caseSensitive: false), '');
    v = v.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (v.isEmpty) return const _ParsedMoney(amount: 0);

    // Deteksi pemisah ribuan vs desimal Indonesia & internasional.
    String normalized;
    final hasComma = v.contains(',');
    final hasDot = v.contains('.');

    if (hasComma && hasDot) {
      if (v.lastIndexOf(',') > v.lastIndexOf('.')) {
        // Format Indonesia: 1.500.000,50
        normalized = v.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Format US: 1,500,000.50
        normalized = v.replaceAll(',', '');
      }
    } else if (hasDot) {
      final dotParts = v.split('.');
      if (dotParts.length > 2 ||
          (dotParts.length == 2 && dotParts.last.length == 3)) {
        normalized = v.replaceAll('.', '');
      } else {
        normalized = v;
      }
    } else if (hasComma) {
      final commaParts = v.split(',');
      if (commaParts.length > 2 ||
          (commaParts.length == 2 && commaParts.last.length == 3)) {
        normalized = v.replaceAll(',', '');
      } else {
        normalized = v.replaceAll(',', '.');
      }
    } else {
      normalized = v;
    }

    final parsed = double.tryParse(normalized) ?? 0;
    return _ParsedMoney(
      amount: parsed.abs(),
      isNegative: isNegative || parsed < 0,
      hintType: hintType,
    );
  }

  static bool _isIncomeKeyword(String v) {
    return v == 'cr' ||
        v == 'k' ||
        v.contains('kredit') ||
        v.contains('credit') ||
        v.contains('masuk') ||
        v.contains('income');
  }

  static bool _isExpenseKeyword(String v) {
    return v == 'db' ||
        v == 'd' ||
        v.contains('debit') ||
        v.contains('debet') ||
        v.contains('keluar') ||
        v.contains('expense');
  }

  static String _extractMerchantName(String desc) {
    final stripped = desc
        .replaceFirst(RegExp(r'^(QRIS|TRF|TRSF|BI-FAST|TRANSFER|PEMBAYARAN)\s+', caseSensitive: false), '')
        .trim();
    final source = stripped.isEmpty ? desc : stripped;
    if (source.length <= 42) return source;
    return source.substring(0, 42).trim();
  }
}

class _ColumnMap {
  final int dateIdx;
  final int descIdx;
  final int amountIdx;
  final int debitIdx;
  final int creditIdx;
  final int typeIdx;

  const _ColumnMap({
    required this.dateIdx,
    required this.descIdx,
    required this.amountIdx,
    required this.debitIdx,
    required this.creditIdx,
    required this.typeIdx,
  });

  factory _ColumnMap.fromHeaders(List<String> headers) {
    int find(List<String> keywords) {
      for (var i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (keywords.any((k) => h == k || h.contains(k))) return i;
      }
      return -1;
    }

    return _ColumnMap(
      dateIdx: find(['tanggal', 'tgl', 'date', 'waktu']),
      descIdx: find(['keterangan', 'deskripsi', 'uraian', 'merchant', 'description', 'memo', 'berita']),
      amountIdx: find(['nominal', 'jumlah', 'amount', 'nilai', 'mutasi']),
      debitIdx: find(['debit', 'debet', 'keluar', 'pengeluaran', 'withdrawal']),
      creditIdx: find(['kredit', 'credit', 'masuk', 'pemasukan', 'deposit']),
      typeIdx: find(['tipe', 'jenis', 'type', 'dk', 'd k', 'cr db']),
    );
  }
}

class _ParsedMoney {
  final double amount;
  final bool isNegative;
  final String? hintType;

  const _ParsedMoney({
    required this.amount,
    this.isNegative = false,
    this.hintType,
  });
}
