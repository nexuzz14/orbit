import 'package:flutter/services.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/bank_notification_parser.dart';
import 'package:orbit_app/core/services/receipt_ocr_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ringkasan hasil konsumsi otomatis dari NotificationListener atau Share Target.
class AutoCaptureImportSummary {
  final int draftsCreated;
  final int needsReviewCount;
  final int ignoredCount;
  final int rejectedMimeCount;

  const AutoCaptureImportSummary({
    this.draftsCreated = 0,
    this.needsReviewCount = 0,
    this.ignoredCount = 0,
    this.rejectedMimeCount = 0,
  });
}

/// Jembatan Flutter <-> Android Native untuk:
/// 1) Pembaca notifikasi bank/e-wallet (`NotificationListenerService`) berbasis whitelist.
/// 2) Penerima `ACTION_SEND` Android Share Target (`text/plain` & gambar struk).
/// 3) Pemilih gambar struk lokal aman dengan pembersihan file sementara otomatis.
class AndroidAutoCaptureBridge {
  AndroidAutoCaptureBridge._();

  static final AndroidAutoCaptureBridge instance = AndroidAutoCaptureBridge._();

  static const MethodChannel _channel = MethodChannel(
    'id.my.nabilcf.orbit/auto_capture',
  );
  static const String _prefWhitelistKey = 'orbit_bank_listener_whitelist_v1';
  static const String _prefListenerEnabledKey = 'orbit_bank_listener_enabled_v1';

  static const Set<String> allowedImageMimeTypes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  };

  bool _handlerRegistered = false;
  void Function(AutoCaptureImportSummary summary)? _onDraftsImported;

  void attachListener({
    void Function(AutoCaptureImportSummary summary)? onDraftsImported,
  }) {
    _onDraftsImported = onDraftsImported;
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onShareReceived' ||
            call.method == 'onBankNotificationQueued') {
          final summary = await syncPendingAutoCaptures(AppDatabase.shared);
          if (summary.draftsCreated > 0 || summary.rejectedMimeCount > 0) {
            _onDraftsImported?.call(summary);
          }
        }
      });
    } on MissingPluginException {
      // Aman saat headless test.
    } catch (_) {}
  }

  Future<bool> isNotificationAccessGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod<bool>('openNotificationListenerSettings');
    } on MissingPluginException {
      // Aman di platform non-Android.
    } on PlatformException {
      // Aman diabaikan.
    }
  }

  Future<bool> loadListenerEnabledPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefListenerEnabledKey) ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setListenerEnabledPref(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefListenerEnabledKey, enabled);
    } on MissingPluginException {
      // Headless safe.
    } catch (_) {}

    try {
      await _channel.invokeMethod<bool>('setBankListenerEnabled', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Headless safe.
    } on PlatformException {
      // Headless safe.
    }
  }

  Future<Set<String>> loadWhitelistedPackages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefWhitelistKey);
      if (list != null) {
        return list.toSet();
      }
    } on MissingPluginException {
      // Headless safe.
    } catch (_) {}
    return BankNotificationParser.defaultWhitelistedPackages;
  }

  Future<void> saveWhitelistedPackages(Set<String> packages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefWhitelistKey, packages.toList()..sort());
    } on MissingPluginException {
      // Headless safe.
    } catch (_) {}

    try {
      await _channel.invokeMethod<bool>('setWhitelistedPackages', {
        'packages': packages.toList(),
      });
    } on MissingPluginException {
      // Headless safe.
    } on PlatformException {
      // Headless safe.
    }
  }

  /// Sinkronkan pengaturan whitelist & flag aktif ke lapisan native Android.
  Future<void> pushConfigToNative() async {
    final enabled = await loadListenerEnabledPref();
    final packages = await loadWhitelistedPackages();
    try {
      await _channel.invokeMethod<bool>('setBankListenerEnabled', {
        'enabled': enabled,
      });
      await _channel.invokeMethod<bool>('setWhitelistedPackages', {
        'packages': packages.toList(),
      });
    } on MissingPluginException {
      // Headless safe.
    } on PlatformException {
      // Headless safe.
    }
  }

  /// Pilih foto struk via Android Photo Picker native dan kembalikan path berkas sementara.
  Future<String?> pickReceiptImageTempPath() async {
    try {
      return await _channel.invokeMethod<String>('pickReceiptImage');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Proses seluruh notifikasi bank & Share Target yang menunggu di antrean native.
  Future<AutoCaptureImportSummary> syncPendingAutoCaptures(
    AppDatabase db, {
    String? workspaceId,
  }) async {
    var created = 0;
    var needsReview = 0;
    var ignored = 0;
    var rejectedMime = 0;

    final notifResult = await _consumePendingNotifications(
      db,
      workspaceId: workspaceId,
    );
    created += notifResult.draftsCreated;
    needsReview += notifResult.needsReviewCount;
    ignored += notifResult.ignoredCount;

    final shareResult = await _consumePendingShares(
      db,
      workspaceId: workspaceId,
    );
    created += shareResult.draftsCreated;
    needsReview += shareResult.needsReviewCount;
    ignored += shareResult.ignoredCount;
    rejectedMime += shareResult.rejectedMimeCount;

    return AutoCaptureImportSummary(
      draftsCreated: created,
      needsReviewCount: needsReview,
      ignoredCount: ignored,
      rejectedMimeCount: rejectedMime,
    );
  }

  Future<AutoCaptureImportSummary> _consumePendingNotifications(
    AppDatabase db, {
    String? workspaceId,
  }) async {
    List<dynamic>? items;
    try {
      items = await _channel.invokeMethod<List<dynamic>>(
        'consumePendingBankNotifications',
      );
    } on MissingPluginException {
      return const AutoCaptureImportSummary();
    } on PlatformException {
      return const AutoCaptureImportSummary();
    }

    if (items == null || items.isEmpty) {
      return const AutoCaptureImportSummary();
    }

    final whitelist = await loadWhitelistedPackages();
    var created = 0;
    var needsReview = 0;
    var ignored = 0;

    for (final raw in items) {
      if (raw is! Map) {
        ignored++;
        continue;
      }
      final pkg = raw['packageName']?.toString() ?? '';
      if (pkg.isEmpty || !whitelist.contains(pkg)) {
        ignored++;
        continue;
      }

      // Data yang diparse di native dikirim minimal (tanpa teks mentah bila sudah diekstrak),
      // atau jika berupa title+body sementara, langsung diparse dan dibuang tanpa log.
      final title = raw['title']?.toString() ?? '';
      final body = raw['body']?.toString() ?? '';
      final tsMs = raw['timestampMs'];
      final receivedAt = tsMs is int
          ? DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true)
          : DateTime.now().toUtc();

      final parsed = BankNotificationParser.parse(
        title: title,
        body: body,
        packageName: pkg,
        receivedAtUtc: receivedAt,
      );
      if (!parsed.accepted || parsed.amount <= 0) {
        ignored++;
        continue;
      }

      final draftId = await ReceiptOcrService.saveBankNotificationDraftToInbox(
        db: db,
        parsed: parsed,
        workspaceId: workspaceId,
      );
      if (draftId != null) {
        created++;
        if (parsed.needsReview) needsReview++;
      } else {
        ignored++;
      }
    }

    return AutoCaptureImportSummary(
      draftsCreated: created,
      needsReviewCount: needsReview,
      ignoredCount: ignored,
    );
  }

  Future<AutoCaptureImportSummary> _consumePendingShares(
    AppDatabase db, {
    String? workspaceId,
  }) async {
    List<dynamic>? items;
    try {
      items = await _channel.invokeMethod<List<dynamic>>(
        'consumePendingShares',
      );
    } on MissingPluginException {
      return const AutoCaptureImportSummary();
    } on PlatformException {
      return const AutoCaptureImportSummary();
    }

    if (items == null || items.isEmpty) {
      return const AutoCaptureImportSummary();
    }

    var created = 0;
    var needsReview = 0;
    var ignored = 0;
    var rejectedMime = 0;

    for (final raw in items) {
      if (raw is! Map) {
        ignored++;
        continue;
      }
      final mime = (raw['mimeType']?.toString() ?? '').toLowerCase().trim();
      final text = raw['text']?.toString();
      final filePath = raw['filePath']?.toString();

      final single = await processSharePayload(
        db: db,
        mimeType: mime,
        text: text,
        tempImagePath: filePath,
        workspaceId: workspaceId,
      );
      created += single.draftsCreated;
      needsReview += single.needsReviewCount;
      ignored += single.ignoredCount;
      rejectedMime += single.rejectedMimeCount;
    }

    return AutoCaptureImportSummary(
      draftsCreated: created,
      needsReviewCount: needsReview,
      ignoredCount: ignored,
      rejectedMimeCount: rejectedMime,
    );
  }

  /// Memproses satu payload Share Target Android secara aman dan teruji.
  /// Hanya menerima `text/plain` dan `image/jpeg|image/png|image/webp`.
  Future<AutoCaptureImportSummary> processSharePayload({
    required AppDatabase db,
    required String mimeType,
    String? text,
    String? tempImagePath,
    String? workspaceId,
  }) async {
    final mime = mimeType.toLowerCase().trim();

    if (mime == 'text/plain' && text != null && text.trim().isNotEmpty) {
      final bankParsed = BankNotificationParser.parse(
        title: '',
        body: text,
      );
      if (bankParsed.accepted && bankParsed.amount > 0) {
        final id = await ReceiptOcrService.saveBankNotificationDraftToInbox(
          db: db,
          parsed: bankParsed,
          workspaceId: workspaceId,
        );
        if (id != null) {
          return AutoCaptureImportSummary(
            draftsCreated: 1,
            needsReviewCount: bankParsed.needsReview ? 1 : 0,
          );
        }
      }

      final receiptParsed = ReceiptOcrService.parseReceiptText(text);
      if (receiptParsed.accepted && receiptParsed.amount > 0) {
        final id = await ReceiptOcrService.saveReceiptDraftToInbox(
          db: db,
          parsed: receiptParsed,
          source: 'share',
          origin: 'share_target',
          workspaceId: workspaceId,
        );
        if (id != null) {
          return AutoCaptureImportSummary(
            draftsCreated: 1,
            needsReviewCount: receiptParsed.needsReview ? 1 : 0,
          );
        }
      }
      return const AutoCaptureImportSummary(ignoredCount: 1);
    }

    if (allowedImageMimeTypes.contains(mime) &&
        tempImagePath != null &&
        tempImagePath.trim().isNotEmpty) {
      final outcome = await ReceiptOcrService.extractAndParseFromImageFile(
        tempImagePath,
        deleteTempFile: true,
      );
      if (outcome.result.accepted && outcome.result.amount > 0) {
        final id = await ReceiptOcrService.saveReceiptDraftToInbox(
          db: db,
          parsed: outcome.result,
          source: 'receipt',
          origin: 'share_target',
          workspaceId: workspaceId,
        );
        if (id != null) {
          return AutoCaptureImportSummary(
            draftsCreated: 1,
            needsReviewCount: outcome.result.needsReview ? 1 : 0,
          );
        }
      }
      return const AutoCaptureImportSummary(ignoredCount: 1);
    }

    // Tolak MIME tidak diizinkan dan tetap hapus file temp bila ada.
    if (tempImagePath != null && tempImagePath.trim().isNotEmpty) {
      await ReceiptOcrService.safeDeleteTempFile(tempImagePath);
    }
    return const AutoCaptureImportSummary(rejectedMimeCount: 1);
  }
}
