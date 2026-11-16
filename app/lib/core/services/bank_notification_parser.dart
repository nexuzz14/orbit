/// Daftar paket aplikasi bank dan e-wallet Indonesia yang didukung untuk
/// pembacaan notifikasi lokal secara opt-in dan aman privasi.
class SupportedBankApp {
  final String packageName;
  final String displayName;
  final String providerCode;

  const SupportedBankApp({
    required this.packageName,
    required this.displayName,
    required this.providerCode,
  });
}

/// Hasil parsing terstruktur dari satu notifikasi bank/e-wallet.
/// Tidak menyimpan teks mentah notifikasi demi menjaga privasi pengguna.
class BankParseResult {
  final bool accepted;
  final bool needsReview;
  final double amount;
  final String currency;
  final String type; // 'expense' | 'income'
  final String provider;
  final String? merchant;
  final DateTime occurredAt;
  final double confidence;
  final String? reviewReason;
  final String? rejectionReason;

  const BankParseResult({
    required this.accepted,
    required this.needsReview,
    required this.amount,
    required this.currency,
    required this.type,
    required this.provider,
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
        : 'Transaksi Otomatis';
    return '$provider - $target';
  }
}

/// Parser deterministik notifikasi transaksi bank & e-wallet Indonesia.
/// Dirancang murni lokal tanpa mengirim maupun menyimpan teks mentah notifikasi.
class BankNotificationParser {
  BankNotificationParser._();

  static const Set<String> _validCurrencies = {
    'IDR',
    'USD',
    'SGD',
    'EUR',
    'MYR',
    'JPY',
    'AUD',
  };

  static const List<SupportedBankApp> supportedApps = [
    SupportedBankApp(
      packageName: 'com.bca',
      displayName: 'BCA mobile',
      providerCode: 'BCA',
    ),
    SupportedBankApp(
      packageName: 'com.bca.mybca.omni.android',
      displayName: 'myBCA',
      providerCode: 'BCA',
    ),
    SupportedBankApp(
      packageName: 'id.bmri.livin',
      displayName: "Livin' by Mandiri",
      providerCode: 'Mandiri',
    ),
    SupportedBankApp(
      packageName: 'src.com.bni',
      displayName: 'BNI Mobile Banking',
      providerCode: 'BNI',
    ),
    SupportedBankApp(
      packageName: 'id.co.bni.wondr',
      displayName: 'wondr by BNI',
      providerCode: 'BNI',
    ),
    SupportedBankApp(
      packageName: 'id.co.bri.brimo',
      displayName: 'BRImo',
      providerCode: 'BRI',
    ),
    SupportedBankApp(
      packageName: 'com.gojek.app',
      displayName: 'GoPay / Gojek',
      providerCode: 'GoPay',
    ),
    SupportedBankApp(
      packageName: 'com.gopay.app',
      displayName: 'GoPay App',
      providerCode: 'GoPay',
    ),
    SupportedBankApp(
      packageName: 'ovo.id',
      displayName: 'OVO',
      providerCode: 'OVO',
    ),
    SupportedBankApp(
      packageName: 'id.dana',
      displayName: 'DANA',
      providerCode: 'DANA',
    ),
    SupportedBankApp(
      packageName: 'com.shopee.id',
      displayName: 'Shopee / ShopeePay',
      providerCode: 'ShopeePay',
    ),
    SupportedBankApp(
      packageName: 'com.shopeepay.id',
      displayName: 'ShopeePay',
      providerCode: 'ShopeePay',
    ),
  ];

  static Set<String> get defaultWhitelistedPackages =>
      supportedApps.map((e) => e.packageName).toSet();

  static BankParseResult parse({
    required String title,
    required String body,
    String? packageName,
    DateTime? receivedAtUtc,
    DateTime? nowUtc,
  }) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    var occurredAt = (receivedAtUtc ?? now).toUtc();

    final combinedRaw = '${title.trim()} ${body.trim()}'.trim();
    if (combinedRaw.isEmpty) {
      return BankParseResult(
        accepted: false,
        needsReview: true,
        amount: 0,
        currency: 'IDR',
        type: 'expense',
        provider: _detectProvider(packageName, ''),
        merchant: null,
        occurredAt: occurredAt,
        confidence: 0,
        rejectionReason: 'Teks notifikasi kosong',
      );
    }

    final normalized = combinedRaw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = normalized.toLowerCase();
    final provider = _detectProvider(packageName, lower);

    // Tolak OTP, login alert, atau notifikasi promo non-transaksi.
    if (_isNonTransactionNoise(lower)) {
      return BankParseResult(
        accepted: false,
        needsReview: false,
        amount: 0,
        currency: 'IDR',
        type: 'expense',
        provider: provider,
        merchant: null,
        occurredAt: occurredAt,
        confidence: 0,
        rejectionReason: 'Bukan notifikasi transaksi (OTP/promo/keamanan)',
      );
    }

    // Validasi rentang tanggal notifikasi agar wajar.
    var dateDoubtful = false;
    final extractedDate = _extractDateFromText(normalized, now);
    if (extractedDate != null) {
      occurredAt = extractedDate;
    }
    if (occurredAt.isAfter(now.add(const Duration(hours: 24))) ||
        occurredAt.isBefore(now.subtract(const Duration(days: 365)))) {
      dateDoubtful = true;
      occurredAt = now;
    }

    final amountMatch = _extractAmountAndCurrency(normalized);
    if (amountMatch == null) {
      return BankParseResult(
        accepted: false,
        needsReview: true,
        amount: 0,
        currency: 'IDR',
        type: 'expense',
        provider: provider,
        merchant: null,
        occurredAt: occurredAt,
        confidence: 0.1,
        reviewReason: 'Nominal transaksi tidak ditemukan',
        rejectionReason: 'Nominal transaksi tidak dapat dikenali',
      );
    }

    if (amountMatch.isNegativeOrZero || amountMatch.amount <= 0) {
      return BankParseResult(
        accepted: false,
        needsReview: true,
        amount: 0,
        currency: amountMatch.currency,
        type: 'expense',
        provider: provider,
        merchant: null,
        occurredAt: occurredAt,
        confidence: 0,
        reviewReason: 'Nominal harus lebih besar dari nol',
        rejectionReason: 'Nominal tidak valid (<= 0)',
      );
    }

    if (!_validCurrencies.contains(amountMatch.currency)) {
      return BankParseResult(
        accepted: false,
        needsReview: true,
        amount: 0,
        currency: amountMatch.currency,
        type: 'expense',
        provider: provider,
        merchant: null,
        occurredAt: occurredAt,
        confidence: 0.1,
        reviewReason: 'Mata uang tidak valid',
        rejectionReason: 'Mata uang tidak dikenali',
      );
    }

    final direction = _detectDirection(lower);
    final merchant = _extractMerchant(normalized, lower, provider);

    var confidence = 0.85;
    final reviewReasons = <String>[];

    if (direction.ambiguous) {
      confidence -= 0.30;
      reviewReasons.add('Arah debit/kredit kurang jelas');
    }
    if (amountMatch.ambiguousFormat) {
      confidence -= 0.25;
      reviewReasons.add('Format pemisah ribuan/desimal meragukan');
    }
    if (amountMatch.currency != 'IDR') {
      confidence -= 0.20;
      reviewReasons.add('Mata uang non-IDR (${amountMatch.currency})');
    }
    if (merchant == null || merchant.isEmpty) {
      confidence -= 0.15;
      reviewReasons.add('Merchant tidak terdeteksi');
    }
    if (dateDoubtful) {
      confidence -= 0.15;
      reviewReasons.add('Tanggal transaksi disesuaikan');
    }
    if (provider == 'Bank/E-Wallet') {
      confidence -= 0.10;
    }

    confidence = confidence.clamp(0.0, 1.0);
    final needsReview =
        confidence < 0.72 || direction.ambiguous || amountMatch.ambiguousFormat;

    return BankParseResult(
      accepted: true,
      needsReview: needsReview,
      amount: amountMatch.amount,
      currency: amountMatch.currency,
      type: direction.type,
      provider: provider,
      merchant: merchant,
      occurredAt: occurredAt,
      confidence: confidence,
      reviewReason: reviewReasons.isEmpty ? null : reviewReasons.join('; '),
    );
  }

  static String _detectProvider(String? packageName, String lower) {
    if (packageName != null && packageName.isNotEmpty) {
      for (final app in supportedApps) {
        if (app.packageName == packageName) {
          if (lower.contains('qris')) return '${app.providerCode} QRIS';
          return app.providerCode;
        }
      }
    }

    if (lower.contains('bca') || lower.contains('mybca')) {
      return lower.contains('qris') ? 'BCA QRIS' : 'BCA';
    }
    if (lower.contains('mandiri') || lower.contains("livin'")) {
      return lower.contains('qris') ? 'Mandiri QRIS' : 'Mandiri';
    }
    if (lower.contains('bni') || lower.contains('wondr')) {
      return lower.contains('qris') ? 'BNI QRIS' : 'BNI';
    }
    if (lower.contains('bri') || lower.contains('brimo')) {
      return lower.contains('qris') ? 'BRI QRIS' : 'BRI';
    }
    if (lower.contains('gopay') || lower.contains('gojek')) {
      return lower.contains('qris') ? 'GoPay QRIS' : 'GoPay';
    }
    if (lower.contains('ovo')) return 'OVO';
    if (lower.contains('dana')) return 'DANA';
    if (lower.contains('shopeepay') || lower.contains('shopee')) {
      return 'ShopeePay';
    }
    if (lower.contains('qris')) return 'QRIS';
    return 'Bank/E-Wallet';
  }

  static bool _isNonTransactionNoise(String lower) {
    const noiseTokens = [
      'otp',
      'kode verifikasi',
      'kode rahasia',
      'jangan bagikan kode',
      'jangan berikan kode',
      'login berhasil',
      'perangkat baru',
      'promo spesial',
      'diskon hingga',
      'cashback hingga',
      'voucher gratis',
    ];
    final hasNoise = noiseTokens.any(lower.contains);
    if (!hasNoise) return false;

    const strongTxTokens = [
      'pembayaran berhasil',
      'transaksi berhasil',
      'transfer berhasil',
      'dana masuk',
      'uang masuk',
      'terdebit',
      'dikreditkan',
    ];
    return !strongTxTokens.any(lower.contains);
  }

  static _AmountExtract? _extractAmountAndCurrency(String text) {
    // Deteksi explicit minus atau nol dulu agar nominal <= 0 langsung terflag.
    final negativeRegex = RegExp(
      r'(?:-\s*(?:rp|idr)|(?:rp|idr)\s*-)\s*([\d.,]+)',
      caseSensitive: false,
    );
    if (negativeRegex.hasMatch(text)) {
      return const _AmountExtract(
        amount: 0,
        currency: 'IDR',
        isNegativeOrZero: true,
        ambiguousFormat: false,
      );
    }

    final currencyAmountRegex = RegExp(
      r'(Rp|IDR|USD|SGD|EUR|MYR|JPY|AUD)\s*\.?\s*(-?[\d]+(?:[.,]\d+)*)',
      caseSensitive: false,
    );
    final matches = currencyAmountRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      // Fallback: angka berformat ribuan/jutaan setelah kata sebesar/senilai/nominal.
      final keywordAmountRegex = RegExp(
        r'(?:sebesar|senilai|nominal|total|bayar)\s+(-?[\d]{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)',
        caseSensitive: false,
      );
      final kw = keywordAmountRegex.firstMatch(text);
      if (kw == null) return null;
      final parsed = parseIndonesianNumber(kw.group(1) ?? '');
      if (parsed == null) return null;
      return _AmountExtract(
        amount: parsed.value,
        currency: 'IDR',
        isNegativeOrZero: parsed.value <= 0,
        ambiguousFormat: parsed.ambiguous,
      );
    }

    // Hindari menangkap angka saldo jika ada nominal transaksi utama sebelumnya.
    RegExpMatch chosen = matches.first;
    for (final m in matches) {
      final beforeStart = (m.start - 18).clamp(0, text.length);
      final prefix = text.substring(beforeStart, m.start).toLowerCase();
      if (!prefix.contains('saldo') && !prefix.contains('sisa')) {
        chosen = m;
        break;
      }
    }

    final rawCurrency = (chosen.group(1) ?? 'IDR').toUpperCase();
    final currency = rawCurrency == 'RP' ? 'IDR' : rawCurrency;
    final rawNumber = chosen.group(2) ?? '';
    final parsed = parseIndonesianNumber(rawNumber);
    if (parsed == null) return null;

    return _AmountExtract(
      amount: parsed.value,
      currency: currency,
      isNegativeOrZero: parsed.value <= 0,
      ambiguousFormat: parsed.ambiguous,
    );
  }

  /// Parsing angka nominal Indonesia (contoh `150.000`, `150.000,00`, `150,000.50`).
  static ({double value, bool ambiguous})? parseIndonesianNumber(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    if (clean.startsWith('-')) {
      return (value: -1, ambiguous: false);
    }

    final dotOnly = RegExp(r'^\d{1,3}(?:\.\d{3})+$');
    final commaOnly = RegExp(r'^\d{1,3}(?:,\d{3})+$');
    final indoDecimal = RegExp(r'^\d{1,3}(?:\.\d{3})+,\d{1,2}$');
    final usDecimal = RegExp(r'^\d{1,3}(?:,\d{3})+\.\d{1,2}$');
    final plainInt = RegExp(r'^\d+$');
    final plainSmallDecimal = RegExp(r'^\d+[.,]\d{1,2}$');

    if (indoDecimal.hasMatch(clean)) {
      final normalized = clean.replaceAll('.', '').replaceAll(',', '.');
      final v = double.tryParse(normalized);
      return v == null ? null : (value: v, ambiguous: false);
    }
    if (usDecimal.hasMatch(clean)) {
      final normalized = clean.replaceAll(',', '');
      final v = double.tryParse(normalized);
      return v == null ? null : (value: v, ambiguous: false);
    }
    if (dotOnly.hasMatch(clean)) {
      final normalized = clean.replaceAll('.', '');
      final v = double.tryParse(normalized);
      return v == null ? null : (value: v, ambiguous: false);
    }
    if (commaOnly.hasMatch(clean)) {
      final normalized = clean.replaceAll(',', '');
      final v = double.tryParse(normalized);
      return v == null ? null : (value: v, ambiguous: false);
    }
    if (plainInt.hasMatch(clean)) {
      final v = double.tryParse(clean);
      return v == null ? null : (value: v, ambiguous: false);
    }
    if (plainSmallDecimal.hasMatch(clean)) {
      final normalized = clean.replaceAll(',', '.');
      final v = double.tryParse(normalized);
      return v == null ? null : (value: v, ambiguous: true);
    }

    final fallback = double.tryParse(clean.replaceAll(RegExp(r'[^\d]'), ''));
    return fallback == null ? null : (value: fallback, ambiguous: true);
  }

  static ({String type, bool ambiguous}) _detectDirection(String lower) {
    const incomeKeywords = [
      'dana masuk',
      'uang masuk',
      'transfer masuk',
      'kredit',
      'dikreditkan',
      'diterima dari',
      'menerima dana',
      'terima dana',
      'terima transfer',
      'top up berhasil',
      'topup berhasil',
      'saldo bertambah',
      'refund',
      'cashback masuk',
    ];
    const expenseKeywords = [
      'debit',
      'terdebit',
      'didebet',
      'pembayaran',
      'bayar',
      'qris',
      'pembelian',
      'transaksi ke',
      'transfer ke',
      'kirim ke',
      'tarik tunai',
      'potong saldo',
      'berhasil ke',
      'belanja di',
    ];

    final hasIncome = incomeKeywords.any(lower.contains);
    final hasExpense = expenseKeywords.any(lower.contains);

    if (hasIncome && !hasExpense) {
      return (type: 'income', ambiguous: false);
    }
    if (hasExpense && !hasIncome) {
      return (type: 'expense', ambiguous: false);
    }
    if (hasIncome && hasExpense) {
      // Misal "Transfer berhasil ke BCA" vs "Terima transfer": cek pola eksplisit.
      if (lower.contains('transfer ke') ||
          lower.contains('pembayaran') ||
          lower.contains('qris')) {
        return (type: 'expense', ambiguous: false);
      }
      return (type: 'expense', ambiguous: true);
    }
    return (type: 'expense', ambiguous: true);
  }

  static String? _extractMerchant(
    String text,
    String lower,
    String provider,
  ) {
    final patterns = [
      RegExp(
        r'(?:pembayaran\s+qris\s+(?:di|ke)|bayar\s+qris\s+(?:di|ke)|qris\s+(?:di|ke))\s+([A-Za-z0-9][A-Za-z0-9 &._/-]{1,42}?)(?=\s+(?:sebesar|senilai|nominal|rp|idr|pada|tgl|tanggal|berhasil|sukses|\d{2}[/-]\d{2})|[.,!?\n]|$)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:di|ke|merchant|dari|kepada)\s+([A-Za-z0-9][A-Za-z0-9 &._/-]{1,42}?)(?=\s+(?:sebesar|senilai|nominal|rp|idr|pada|tgl|tanggal|berhasil|sukses|\d{2}[/-]\d{2})|[.,!?\n]|$)',
        caseSensitive: false,
      ),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        var candidate = (m.group(1) ?? '').trim();
        candidate = candidate.replaceAll(
          RegExp(r'\s+(?:berhasil|sukses|via|dengan)$', caseSensitive: false),
          '',
        );
        // Jangan kembalikan string sensitif seperti nomor rekening panjang.
        if (RegExp(r'^\d{6,}$').hasMatch(candidate)) continue;
        if (candidate.isNotEmpty &&
            candidate.toLowerCase() != provider.toLowerCase()) {
          return candidate.length > 48 ? candidate.substring(0, 48) : candidate;
        }
      }
    }

    if (lower.contains('qris')) {
      return 'Merchant QRIS';
    }
    return null;
  }

  static DateTime? _extractDateFromText(String text, DateTime nowUtc) {
    // Format DD/MM/YYYY atau DD-MM-YYYY opsional dengan jam HH:MM.
    final m = RegExp(
      r'(\d{2})[/-](\d{2})[/-](\d{4})(?:\s+(\d{2})[:.](\d{2}))?',
    ).firstMatch(text);
    if (m == null) return null;

    final day = int.tryParse(m.group(1) ?? '');
    final month = int.tryParse(m.group(2) ?? '');
    final year = int.tryParse(m.group(3) ?? '');
    final hour = int.tryParse(m.group(4) ?? '') ?? 12;
    final minute = int.tryParse(m.group(5) ?? '') ?? 0;

    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    try {
      // Asumsikan waktu WIB (+07:00) lalu konversi ke UTC.
      final wibWall = DateTime.utc(year, month, day, hour, minute);
      return wibWall.subtract(const Duration(hours: 7));
    } catch (_) {
      return nowUtc;
    }
  }
}

class _AmountExtract {
  final double amount;
  final String currency;
  final bool isNegativeOrZero;
  final bool ambiguousFormat;

  const _AmountExtract({
    required this.amount,
    required this.currency,
    required this.isNegativeOrZero,
    required this.ambiguousFormat,
  });
}
