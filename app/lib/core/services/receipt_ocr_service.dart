import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/bank_notification_parser.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';

typedef ReceiptOcrRunner = Future<String> Function(String imagePath);

/// Hasil parsing teks struk belanja / POS.
class ReceiptParseResult {
  final bool accepted;
  final bool needsReview;
  final double amount;
  final String currency;
  final String? merchant;
  final DateTime occurredAt;
  final double confidence;
  final String? reviewReason;
  final String? rejectionReason;

  const ReceiptParseResult({
    required this.accepted,
    required this.needsReview,
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.occurredAt,
    required this.confidence,
    this.reviewReason,
    this.rejectionReason,
  });

  String? get draftState => needsReview ? 'needs_review' : null;

  String get sanitizedNote {
    final target = (merchant != null && merchant!.trim().isNotEmpty)
        ? merchant!.trim()
        : 'Struk Belanja';
    return 'Struk - $target';
  }
}

/// Hasil proses OCR gambar struk beserta status pembersihan file sementara.
class ReceiptImageOcrOutcome {
  final ReceiptParseResult result;
  final bool ocrEngineUnavailable;
  final bool tempFileDeleted;
  final String? errorMessage;

  const ReceiptImageOcrOutcome({
    required this.result,
    this.ocrEngineUnavailable = false,
    this.tempFileDeleted = false,
    this.errorMessage,
  });
}

/// Layanan OCR struk (ML Kit / kanal native + parser deterministik)
/// dan penulis draf transaksi aman ke Drift Inbox.
class ReceiptOcrService {
  ReceiptOcrService._();

  static const MethodChannel _ocrChannel = MethodChannel(
    'id.my.nabilcf.orbit/mlkit_ocr',
  );
  static const _uuid = Uuid();

  static ReceiptOcrRunner? _testOcrRunner;

  static void overrideOcrRunnerForTesting(ReceiptOcrRunner? runner) {
    _testOcrRunner = runner;
  }

  /// Jalankan OCR pada berkas gambar sementara dan SELALU hapus berkas setelah selesai.
  static Future<ReceiptImageOcrOutcome> extractAndParseFromImageFile(
    String imagePath, {
    bool deleteTempFile = true,
    DateTime? nowUtc,
  }) async {
    String? recognizedText;
    var unavailable = false;
    String? error;

    try {
      if (_testOcrRunner != null) {
        recognizedText = await _testOcrRunner!(imagePath);
      } else {
        recognizedText = await _ocrChannel.invokeMethod<String>(
          'recognizeText',
          {'path': imagePath},
        );
      }
    } on MissingPluginException {
      unavailable = true;
      error = 'Engine OCR perangkat tidak tersedia pada platform ini.';
    } on PlatformException catch (e) {
      unavailable = true;
      error = e.message ?? 'Gagal menjalankan OCR gambar struk.';
    } catch (e) {
      error = 'Gagal memproses gambar struk: $e';
    } finally {
      if (deleteTempFile) {
        await safeDeleteTempFile(imagePath);
      }
    }

    final deleted = !deleteTempFile || !(await File(imagePath).exists());

    if (recognizedText == null || recognizedText.trim().isEmpty) {
      return ReceiptImageOcrOutcome(
        result: ReceiptParseResult(
          accepted: false,
          needsReview: true,
          amount: 0,
          currency: 'IDR',
          merchant: null,
          occurredAt: (nowUtc ?? DateTime.now()).toUtc(),
          confidence: 0,
          reviewReason: error ?? 'Teks struk tidak terbaca',
          rejectionReason: error ?? 'Teks tidak terbaca dari gambar struk',
        ),
        ocrEngineUnavailable: unavailable,
        tempFileDeleted: deleted,
        errorMessage: error,
      );
    }

    final parsed = parseReceiptText(recognizedText, nowUtc: nowUtc);
    return ReceiptImageOcrOutcome(
      result: parsed,
      ocrEngineUnavailable: unavailable,
      tempFileDeleted: deleted,
      errorMessage: error,
    );
  }

  static Future<void> safeDeleteTempFile(String path) async {
    if (path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Abaikan kegagalan hapus agar tidak memecah alur utama.
    }
  }

  /// Parsing deterministik teks struk (Alfamart, Indomaret, minimarket, kafe, POS umum).
  static ReceiptParseResult parseReceiptText(
    String rawText, {
    DateTime? nowUtc,
  }) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return ReceiptParseResult(
        accepted: false,
        needsReview: true,
        amount: 0,
        currency: 'IDR',
        merchant: null,
        occurredAt: now,
        confidence: 0,
        rejectionReason: 'Teks struk kosong',
      );
    }

    final lines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines, trimmed);
    final extractedDate = _extractDate(trimmed);
    var occurredAt = extractedDate ?? now;
    var dateDoubtful = false;
    if (occurredAt.isAfter(now.add(const Duration(hours: 24))) ||
        occurredAt.isBefore(now.subtract(const Duration(days: 365)))) {
      dateDoubtful = true;
      occurredAt = now;
    }

    final totalCandidate = _extractTotalAmount(lines);
    if (totalCandidate == null) {
      return ReceiptParseResult(
        accepted: false,
        needsReview: true,
        amount: 0,
        currency: 'IDR',
        merchant: merchant,
        occurredAt: occurredAt,
        confidence: 0.1,
        reviewReason: 'Total bayar pada struk tidak ditemukan',
        rejectionReason: 'Nominal total struk tidak terbaca',
      );
    }

    if (totalCandidate.amount <= 0) {
      return ReceiptParseResult(
        accepted: false,
        needsReview: true,
        amount: 0,
        currency: 'IDR',
        merchant: merchant,
        occurredAt: occurredAt,
        confidence: 0,
        reviewReason: 'Nominal struk tidak valid (<= 0)',
        rejectionReason: 'Nominal total harus lebih besar dari nol',
      );
    }

    var confidence = 0.86;
    final reasons = <String>[];
    if (!totalCandidate.fromExplicitTotalLine) {
      confidence -= 0.25;
      reasons.add('Label TOTAL tidak ditemukan, memakai nominal terbesar');
    }
    if (merchant == null || merchant.isEmpty) {
      confidence -= 0.20;
      reasons.add('Nama toko belum teridentifikasi');
    }
    if (dateDoubtful) {
      confidence -= 0.12;
      reasons.add('Tanggal struk disesuaikan');
    }
    if (totalCandidate.amount < 500) {
      confidence -= 0.25;
      reasons.add('Nominal sangat kecil, perlu konfirmasi');
    }

    confidence = confidence.clamp(0.0, 1.0);
    final needsReview =
        confidence < 0.72 || !totalCandidate.fromExplicitTotalLine;

    return ReceiptParseResult(
      accepted: true,
      needsReview: needsReview,
      amount: totalCandidate.amount,
      currency: 'IDR',
      merchant: merchant,
      occurredAt: occurredAt,
      confidence: confidence,
      reviewReason: reasons.isEmpty ? null : reasons.join('; '),
    );
  }

  static String? _extractMerchant(List<String> lines, String fullText) {
    final lowerFull = fullText.toLowerCase();
    const knownBrands = [
      ('alfamart', 'Alfamart'),
      ('alfamidi', 'Alfamidi'),
      ('indomaret', 'Indomaret'),
      ('superindo', 'Superindo'),
      ('transmart', 'Transmart'),
      ('lawson', 'Lawson'),
      ('familymart', 'FamilyMart'),
      ('circle k', 'Circle K'),
      ('kopi kenangan', 'Kopi Kenangan'),
      ('fore coffee', 'Fore Coffee'),
      ('starbucks', 'Starbucks'),
      ('gramedia', 'Gramedia'),
      ('guardian', 'Guardian'),
      ('watsons', 'Watsons'),
      ('kimia farma', 'Kimia Farma'),
      ('apotek k-24', 'Apotek K-24'),
      ('uniqlo', 'Uniqlo'),
      ('solaria', 'Solaria'),
      ('hokben', 'HokBen'),
      ('pertamina', 'Pertamina'),
    ];
    for (final entry in knownBrands) {
      if (lowerFull.contains(entry.$1)) {
        return entry.$2;
      }
    }

    final ignoreHeader = RegExp(
      r'^(?:pt\.?\s|cv\.?\s|npwp|jl\.?\s|jalan\s|ruko|telp|hp:|kasir|no\.|bon|struk|receipt|tgl|tanggal|---+|===+|\*\*\*+|rp\b|\d)',
      caseSensitive: false,
    );

    for (final line in lines.take(5)) {
      if (line.length < 3) continue;
      if (ignoreHeader.hasMatch(line)) continue;
      if (RegExp(r'^[\d\s\-/:.]+$').hasMatch(line)) continue;
      final cleaned = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.length >= 3) {
        return cleaned.length > 48 ? cleaned.substring(0, 48) : cleaned;
      }
    }
    return null;
  }

  static ({double amount, bool fromExplicitTotalLine})? _extractTotalAmount(
    List<String> lines,
  ) {
    final skipLineRegex = RegExp(
      r'\b(kembali|kembalian|change|tunai|cash tendered|uang tunai|poin|point|hemat|ppn|tax)\b',
      caseSensitive: false,
    );
    final priorityTotalRegex = RegExp(
      r'\b(grand\s*total|total\s*bayar|total\s*belanja|total\s*tagihan|jml\s*bayar|harus\s*dibayar|total\s*harga|netto|total)\b',
      caseSensitive: false,
    );
    final subtotalRegex = RegExp(
      r'\b(sub\s*total|subtotal)\b',
      caseSensitive: false,
    );
    final amountTokenRegex = RegExp(
      r'(-?(?:Rp\.?|IDR)?\s*\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|-?(?:Rp\.?|IDR)\s*\d+(?:[.,]\d{1,2})?)',
      caseSensitive: false,
    );

    // 1. Cari baris total eksplisit (prioritas GRAND TOTAL / TOTAL BAYAR / TOTAL).
    double? matchedTotal;
    double? matchedSubtotal;
    double? fallbackLargestAmount;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (lower.contains('kembali') || lower.contains('change')) {
        continue;
      }

      final matches = amountTokenRegex.allMatches(line).toList();
      double? lineValue;
      if (matches.isNotEmpty) {
        final rawNum = matches.last
            .group(1)!
            .replaceAll(RegExp(r'(?:Rp\.?|IDR)', caseSensitive: false), '')
            .trim();
        final parsed = BankNotificationParser.parseIndonesianNumber(rawNum);
        lineValue = parsed?.value;
      } else if (priorityTotalRegex.hasMatch(line) && i + 1 < lines.length) {
        // Kadang nominal ada tepat di baris berikutnya setelah "TOTAL".
        final nextMatches = amountTokenRegex.allMatches(lines[i + 1]).toList();
        if (nextMatches.isNotEmpty) {
          final rawNum = nextMatches.last
              .group(1)!
              .replaceAll(RegExp(r'(?:Rp\.?|IDR)', caseSensitive: false), '')
              .trim();
          final parsed = BankNotificationParser.parseIndonesianNumber(rawNum);
          lineValue = parsed?.value;
        }
      }

      if (lineValue == null) continue;
      if (lineValue <= 0) {
        if (priorityTotalRegex.hasMatch(line)) {
          return (amount: lineValue, fromExplicitTotalLine: true);
        }
        continue;
      }

      if (priorityTotalRegex.hasMatch(line) && !subtotalRegex.hasMatch(line)) {
        // Jika ada baris "GRAND TOTAL" / "TOTAL BAYAR", pilih yang terakhir.
        matchedTotal = lineValue;
      } else if (subtotalRegex.hasMatch(line)) {
        matchedSubtotal = lineValue;
      } else if (!skipLineRegex.hasMatch(line)) {
        if (fallbackLargestAmount == null || lineValue > fallbackLargestAmount) {
          fallbackLargestAmount = lineValue;
        }
      }
    }

    if (matchedTotal != null) {
      return (amount: matchedTotal, fromExplicitTotalLine: true);
    }
    if (matchedSubtotal != null) {
      return (amount: matchedSubtotal, fromExplicitTotalLine: true);
    }
    if (fallbackLargestAmount != null) {
      return (amount: fallbackLargestAmount, fromExplicitTotalLine: false);
    }
    return null;
  }

  static DateTime? _extractDate(String text) {
    // DD/MM/YYYY atau DD-MM-YYYY atau DD/MM/YY
    final dmy = RegExp(
      r'\b(\d{2})[/-](\d{2})[/-](\d{2,4})(?:[\s,T]+(\d{2})[:.](\d{2}))?',
    ).firstMatch(text);
    if (dmy != null) {
      final day = int.tryParse(dmy.group(1) ?? '');
      final month = int.tryParse(dmy.group(2) ?? '');
      var year = int.tryParse(dmy.group(3) ?? '');
      final hour = int.tryParse(dmy.group(4) ?? '') ?? 12;
      final minute = int.tryParse(dmy.group(5) ?? '') ?? 0;
      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          try {
            return DateTime.utc(year, month, day, hour, minute)
                .subtract(const Duration(hours: 7));
          } catch (_) {}
        }
      }
    }

    // YYYY-MM-DD
    final ymd = RegExp(
      r'\b(\d{4})-(\d{2})-(\d{2})(?:[\sT]+(\d{2})[:.](\d{2}))?',
    ).firstMatch(text);
    if (ymd != null) {
      final year = int.tryParse(ymd.group(1) ?? '');
      final month = int.tryParse(ymd.group(2) ?? '');
      final day = int.tryParse(ymd.group(3) ?? '');
      final hour = int.tryParse(ymd.group(4) ?? '') ?? 12;
      final minute = int.tryParse(ymd.group(5) ?? '') ?? 0;
      if (day != null && month != null && year != null) {
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          try {
            return DateTime.utc(year, month, day, hour, minute)
                .subtract(const Duration(hours: 7));
          } catch (_) {}
        }
      }
    }
    return null;
  }

  /// Simpan hasil notifikasi bank yang tervalidasi sebagai draf Inbox di Drift.
  static Future<String?> saveBankNotificationDraftToInbox({
    required AppDatabase db,
    required BankParseResult parsed,
    String? workspaceId,
  }) async {
    if (!parsed.accepted || parsed.amount <= 0) return null;
    return _insertDraftTransaction(
      db: db,
      workspaceId: workspaceId,
      type: parsed.type,
      amount: parsed.amount,
      currency: parsed.currency,
      merchant: parsed.merchant ?? parsed.provider,
      note: parsed.sanitizedNote,
      occurredAt: parsed.occurredAt,
      source: 'notification',
      origin: 'bank_notification',
      draftState: parsed.draftState,
      providerHint: parsed.provider,
    );
  }

  /// Simpan hasil OCR/teks struk sebagai draf Inbox di Drift.
  static Future<String?> saveReceiptDraftToInbox({
    required AppDatabase db,
    required ReceiptParseResult parsed,
    String source = 'receipt',
    String origin = 'receipt',
    String? workspaceId,
  }) async {
    if (!parsed.accepted || parsed.amount <= 0) return null;
    return _insertDraftTransaction(
      db: db,
      workspaceId: workspaceId,
      type: 'expense',
      amount: parsed.amount,
      currency: parsed.currency,
      merchant: parsed.merchant,
      note: parsed.sanitizedNote,
      occurredAt: parsed.occurredAt,
      source: source,
      origin: origin,
      draftState: parsed.draftState,
      providerHint: null,
    );
  }

  static Future<String?> _insertDraftTransaction({
    required AppDatabase db,
    String? workspaceId,
    required String type,
    required double amount,
    required String currency,
    required String? merchant,
    required String note,
    required DateTime occurredAt,
    required String source,
    required String origin,
    required String? draftState,
    String? providerHint,
  }) async {
    if (amount <= 0) return null;

    var wsId = workspaceId;
    if (wsId == null || wsId.isEmpty) {
      try {
        wsId = await SyncService.instance.getWorkspaceId();
      } catch (_) {}
    }

    final accounts = await db.select(db.localAccounts).get();
    final activeAccounts = accounts.where((a) => !a.archived).toList();
    if (wsId == null || wsId.isEmpty) {
      wsId = activeAccounts.isNotEmpty ? activeAccounts.first.workspaceId : 'ws-local';
    }

    final workspaceAccounts = activeAccounts
        .where((a) => a.workspaceId == wsId)
        .toList();
    final pool = workspaceAccounts.isNotEmpty ? workspaceAccounts : activeAccounts;

    var accountId = 'acc-default';
    if (pool.isNotEmpty) {
      LocalAccount? matched;
      if (providerHint != null && providerHint.isNotEmpty) {
        final hintLower = providerHint.toLowerCase().split(' ').first;
        for (final acc in pool) {
          if (acc.name.toLowerCase().contains(hintLower)) {
            matched = acc;
            break;
          }
        }
      }
      matched ??= pool.where((a) => a.isLiquid).firstOrNull ?? pool.first;
      accountId = matched.id;
    }

    final categories = await db.select(db.localCategories).get();
    final matchedCategoryId = matchCategoryId(
      categories: categories.where((c) => c.workspaceId == wsId && !c.archived).toList(),
      type: type,
      merchant: merchant,
      note: note,
    );

    final id = _uuid.v4();
    await db.into(db.localTransactions).insert(
      LocalTransactionsCompanion.insert(
        id: id,
        workspaceId: wsId,
        accountId: accountId,
        categoryId: drift.Value(matchedCategoryId),
        type: type,
        status: 'draft',
        draftState: drift.Value(draftState),
        amount: amount,
        currency: currency,
        source: drift.Value(source),
        merchant: drift.Value(merchant),
        note: drift.Value(note),
        occurredAt: occurredAt.toUtc(),
        origin: drift.Value(origin),
      ),
    );

    final payloadMap = {
      'id': id,
      'workspace_id': wsId,
      'account_id': accountId,
      if (matchedCategoryId != null) 'category_id': matchedCategoryId,
      'type': type,
      'status': 'draft',
      if (draftState != null) 'draft_state': draftState,
      'amount': amount,
      'currency': currency,
      'source': source,
      if (merchant != null) 'merchant': merchant,
      'note': note,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'origin': origin,
    };

    await db.into(db.syncOutbox).insert(
      SyncOutboxCompanion.insert(
        id: _uuid.v4(),
        targetTable: 'transactions',
        recordId: id,
        action: 'upsert',
        payload: jsonEncode(payloadMap),
        createdAt: DateTime.now().toUtc(),
      ),
    );

    try {
      await SyncService.instance.triggerSync();
    } catch (_) {
      // Aman saat offline atau mode test.
    }

    return id;
  }

  /// Aturan pencocokan kategori lokal berbasis merchant & kata kunci transaksi.
  static String? matchCategoryId({
    required List<LocalCategory> categories,
    required String type,
    String? merchant,
    String? note,
  }) {
    final text = '${merchant ?? ''} ${note ?? ''}'.toLowerCase();
    final typed = categories.where((c) => c.type == type).toList();
    if (typed.isEmpty) return null;

    const keywordRules = <String, List<String>>{
      'makan': [
        'alfamart',
        'indomaret',
        'alfamidi',
        'superindo',
        'kopi',
        'coffee',
        'starbucks',
        'solaria',
        'hokben',
        'warung',
        'resto',
        'gofood',
        'grabfood',
        'shopeefood',
      ],
      'transport': [
        'gojek',
        'grab',
        'goride',
        'gocar',
        'pertamina',
        'shell',
        'spbu',
        'parkir',
        'tol',
        'kai',
        'transjakarta',
        'mrt',
      ],
      'tagihan': [
        'pln',
        'listrik',
        'pdam',
        'indihome',
        'telkom',
        'wifi',
        'pulsa',
        'bpjs',
        'internet',
      ],
      'kesehatan': ['apotek', 'kimia farma', 'k-24', 'klinik', 'rs ', 'guardian'],
      'belanja': ['tokopedia', 'shopee', 'lazada', 'uniqlo', 'gramedia', 'watsons'],
      'gaji': ['gaji', 'payroll', 'honor', 'fee', 'transfer masuk'],
    };

    for (final entry in keywordRules.entries) {
      if (entry.value.any(text.contains)) {
        for (final cat in typed) {
          final catLower = cat.name.toLowerCase();
          if (catLower.contains(entry.key) ||
              (entry.key == 'makan' && catLower.contains('minum')) ||
              (entry.key == 'gaji' &&
                  (catLower.contains('pemasukan') || catLower.contains('freelance')))) {
            return cat.id;
          }
        }
      }
    }

    return typed.first.id;
  }
}
