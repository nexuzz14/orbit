import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/android_auto_capture_bridge.dart';
import 'package:orbit_app/core/services/bank_notification_parser.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/notification_scheduler_service.dart';
import 'package:orbit_app/core/services/notification_service.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/receipt_ocr_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/settings/notification_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeBiometricAdapter implements BiometricAuthAdapter {
  bool available = true;
  bool nextResult = true;
  int authenticateCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls += 1;
    return nextResult;
  }
}

Future<void> _setMobileViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpAndCheckNoOverflow(WidgetTester tester, Widget child) async {
  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  try {
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousOnError;
  }
  expect(
    errors.map((e) => e.toString()).toList(),
    isEmpty,
    reason: 'Tidak boleh ada overflow atau error layout pada layar Wave 3',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SyncService sync;
  late InMemorySecureLockStorage lockStorage;
  late _FakeBiometricAdapter fakeBio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'active_workspace_id': 'personal-ws',
    });
    NotificationService.ensureTimezonesInitialized();
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    final client = SupabaseClient('http://127.0.0.1:54399', 'dummy-anon-key');
    sync = SyncService(db: db, supabase: client);
    AppDatabase.overrideForTesting(db);
    SyncService.overrideForTesting(sync);

    PrivacyModeController.instance.resetForTesting(
      initialPrivacy: false,
      initialHideWidgetBalance: false,
      persistWithSharedPrefs: false,
    );

    lockStorage = InMemorySecureLockStorage();
    fakeBio = _FakeBiometricAdapter();
    AppLockService.instance.overrideForTesting(
      storage: lockStorage,
      biometric: fakeBio,
    );
    ReceiptOcrService.overrideOcrRunnerForTesting(null);

    await db.into(db.localAccounts).insert(
      LocalAccountsCompanion.insert(
        id: 'acc-bca',
        workspaceId: 'personal-ws',
        name: 'BCA Utama',
        type: 'bank',
        currency: 'IDR',
        initialBalance: const drift.Value(2000000),
        currentBalance: const drift.Value(2500000),
        isLiquid: const drift.Value(true),
      ),
    );

    await db.into(db.localCategories).insert(
      LocalCategoriesCompanion.insert(
        id: 'cat-makan',
        workspaceId: 'personal-ws',
        name: 'Makan & Minum',
        type: 'expense',
      ),
    );
  });

  tearDown(() async {
    ReceiptOcrService.overrideOcrRunnerForTesting(null);
    AppLockService.instance.resetToDefaults();
    PrivacyModeController.instance.resetForTesting();
    await sync.unsubscribeRealtime();
    SyncService.overrideForTesting(null);
    AppDatabase.overrideForTesting(null);
    await db.close();
  });

  group('1. BankNotificationParser (R5)', () {
    test('parse notifikasi BCA, Mandiri, GoPay, dan QRIS dengan akurat', () {
      final bca = BankNotificationParser.parse(
        packageName: 'com.bca',
        title: 'BCA mobile',
        body: 'Transfer ke KOPI KENANGAN Rp 48.500 berhasil',
      );
      expect(bca.accepted, isTrue);
      expect(bca.provider, 'BCA');
      expect(bca.type, 'expense');
      expect(bca.amount, 48500);
      expect(bca.currency, 'IDR');
      expect(bca.needsReview, isFalse);

      final mandiri = BankNotificationParser.parse(
        packageName: 'id.bmri.livin',
        title: "Livin' by Mandiri",
        body: 'Transfer masuk Rp 1.500.000 dari PT KLIEN KREATIF berhasil',
      );
      expect(mandiri.accepted, isTrue);
      expect(mandiri.provider, 'Mandiri');
      expect(mandiri.type, 'income');
      expect(mandiri.amount, 1500000);

      final gopay = BankNotificationParser.parse(
        packageName: 'com.gojek.app',
        title: 'GoPay',
        body: 'Pembayaran Rp25.000 ke GoFood Ayam Bakar berhasil',
      );
      expect(gopay.accepted, isTrue);
      expect(gopay.provider, 'GoPay');
      expect(gopay.type, 'expense');
      expect(gopay.amount, 25000);

      final qris = BankNotificationParser.parse(
        packageName: 'id.dana',
        title: 'DANA',
        body: 'Bayar QRIS Rp 32.000 di INDOMARET SUDIRMAN sukses',
      );
      expect(qris.accepted, isTrue);
      expect(qris.provider, 'DANA QRIS');
      expect(qris.amount, 32000);
    });

    test('menolak nominal <= 0, OTP non-transaksi, dan menandai Perlu dicek bila meragukan', () {
      final zeroAmount = BankNotificationParser.parse(
        packageName: 'com.bca',
        title: 'BCA mobile',
        body: 'Transaksi Rp 0 di Merchant ABC gagal',
      );
      expect(zeroAmount.accepted, isFalse);
      expect(zeroAmount.needsReview, isTrue);
      expect(zeroAmount.draftState, 'needs_review');

      final negativeAmount = BankNotificationParser.parse(
        packageName: 'id.bmri.livin',
        title: "Livin' by Mandiri",
        body: 'Koreksi saldo -Rp 15.000',
      );
      expect(negativeAmount.accepted, isFalse);
      expect(negativeAmount.needsReview, isTrue);

      final otp = BankNotificationParser.parse(
        packageName: 'com.bca',
        title: 'BCA mobile',
        body: 'Kode OTP rahasia 123456. Jangan berikan kode ke siapa pun Rp 100.000.',
      );
      expect(otp.accepted, isFalse);

      final lowConfidence = BankNotificationParser.parse(
        packageName: 'unknown.wallet.pkg',
        title: 'Info Saldo',
        body: 'Mutasi USD 25 nominal tercatat di sistem',
      );
      expect(lowConfidence.accepted, isTrue);
      expect(lowConfidence.needsReview, isTrue);
      expect(lowConfidence.draftState, 'needs_review');
    });
  });

  group('2. ReceiptOcrService & Share Target (R5)', () {
    test('parse teks struk Alfamart & Indomaret lalu simpan sebagai draft Inbox + SyncOutbox', () async {
      const alfamartReceipt = '''
PT SUMBER ALFARIA TRIJAYA TBK
ALFAMART KEMANG SELATAN
15/11/2026 14:20
SUSU UHT 1L           18.500
ROTI TAWAR            27.000
TOTAL BAYAR           Rp 45.500
TUNAI                 50.000
''';
      final parsed = ReceiptOcrService.parseReceiptText(
        alfamartReceipt,
        nowUtc: DateTime.utc(2026, 11, 15, 8, 0),
      );
      expect(parsed.accepted, isTrue);
      expect(parsed.amount, 45500);
      expect(parsed.currency, 'IDR');
      expect(parsed.merchant?.toLowerCase(), contains('alfamart'));
      expect(parsed.needsReview, isFalse);

      final draftId = await ReceiptOcrService.saveReceiptDraftToInbox(
        db: db,
        parsed: parsed,
        workspaceId: 'personal-ws',
      );
      expect(draftId, isNotNull);
      final savedDraftId = draftId!;

      final tx = await (db.select(db.localTransactions)
            ..where((t) => t.id.equals(savedDraftId)))
          .getSingle();
      expect(tx.status, 'draft');
      expect(tx.source, 'receipt');
      expect(tx.amount, 45500);
      expect(tx.categoryId, 'cat-makan');

      final outbox = await (db.select(db.syncOutbox)
            ..where((o) => o.recordId.equals(savedDraftId)))
          .get();
      expect(outbox.length, 1);
      expect(outbox.first.targetTable, 'transactions');
    });

    test('extractAndParseFromImageFile SELALU menghapus file gambar sementara walau sukses atau gagal', () async {
      final tempDir = await Directory.systemTemp.createTemp('orbit_ocr_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final tempImage = File('${tempDir.path}${Platform.pathSeparator}struk1.jpg');
      await tempImage.writeAsBytes([1, 2, 3, 4]);
      ReceiptOcrService.overrideOcrRunnerForTesting(
        (_) async => 'INDOMARET SUDIRMAN\nTOTAL Rp 31.200\nTERIMA KASIH',
      );

      final okOutcome = await ReceiptOcrService.extractAndParseFromImageFile(
        tempImage.path,
      );
      expect(okOutcome.tempFileDeleted, isTrue);
      expect(tempImage.existsSync(), isFalse);
      expect(okOutcome.result.accepted, isTrue);
      expect(okOutcome.result.amount, 31200);

      final failImage = File('${tempDir.path}${Platform.pathSeparator}struk2.png');
      await failImage.writeAsBytes([5, 6, 7, 8]);
      ReceiptOcrService.overrideOcrRunnerForTesting(
        (_) async => throw PlatformException(code: 'OCR_ERR', message: 'gagal'),
      );

      final errOutcome = await ReceiptOcrService.extractAndParseFromImageFile(
        failImage.path,
      );
      expect(errOutcome.tempFileDeleted, isTrue);
      expect(failImage.existsSync(), isFalse);
      expect(errOutcome.ocrEngineUnavailable, isTrue);
      expect(errOutcome.result.accepted, isFalse);
      expect(errOutcome.result.needsReview, isTrue);
    });

    test('Share Target menolak MIME non-whitelist dan tetap menghapus file temp', () async {
      final tempDir = await Directory.systemTemp.createTemp('orbit_share_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final blockedFile = File('${tempDir.path}${Platform.pathSeparator}doc.pdf');
      await blockedFile.writeAsBytes([9, 9, 9]);

      final blockedSummary = await AndroidAutoCaptureBridge.instance.processSharePayload(
        db: db,
        mimeType: 'application/pdf',
        tempImagePath: blockedFile.path,
        workspaceId: 'personal-ws',
      );
      expect(blockedSummary.rejectedMimeCount, 1);
      expect(blockedSummary.draftsCreated, 0);
      expect(blockedFile.existsSync(), isFalse);

      final textSummary = await AndroidAutoCaptureBridge.instance.processSharePayload(
        db: db,
        mimeType: 'text/plain',
        text: 'ALFAMART PANCORAN\nTOTAL BAYAR Rp 22.000',
        workspaceId: 'personal-ws',
      );
      expect(textSummary.draftsCreated, 1);
    });
  });

  group('3. Smart Alerts & Ringkasan Mingguan (#6, #12)', () {
    test('deteksi jadwal bentrok, tugas macet >5 hari, deadline H-24j/H-1j, budget 80%, tagihan H-3, dan Senin 08:00 WIB', () {
      // 2026-11-15 05:00 WIB (Minggu) = 2026-11-14 22:00 UTC
      final nowUtc = DateTime.utc(2026, 11, 14, 22, 0);

      final events = [
        LocalEvent(
          id: 'evt-a',
          workspaceId: 'personal-ws',
          projectId: null,
          kind: 'kuliah',
          title: 'Kuliah Sistem Operasi',
          description: null,
          location: null,
          startsAt: DateTime.utc(2026, 11, 15, 2, 0), // 09:00 WIB
          endsAt: DateTime.utc(2026, 11, 15, 4, 0), // 11:00 WIB
          allDay: false,
          timezone: 'Asia/Jakarta',
          recurrence: null,
          deletedAt: null,
        ),
        LocalEvent(
          id: 'evt-b',
          workspaceId: 'personal-ws',
          projectId: null,
          kind: 'freelance',
          title: 'Demo Klien Bentrok',
          description: null,
          location: null,
          startsAt: DateTime.utc(2026, 11, 15, 3, 0), // 10:00 WIB (overlap)
          endsAt: DateTime.utc(2026, 11, 15, 5, 0), // 12:00 WIB
          allDay: false,
          timezone: 'Asia/Jakarta',
          recurrence: null,
          deletedAt: null,
        ),
      ];

      final tasks = [
        LocalTask(
          id: 'task-macet',
          workspaceId: 'personal-ws',
          projectId: null,
          kind: 'freelance',
          title: 'Refactor API Pembayaran',
          description: null,
          status: 'doing',
          priority: 'high',
          dueAt: DateTime.utc(2026, 11, 16, 10, 0), // 16 Nov 17:00 WIB -> H-24h & H-1h
          dueIsDateOnly: false,
          completedAt: null,
          statusChangedAt: nowUtc.subtract(const Duration(days: 6)),
          milestonePaymentId: null,
          sortOrder: 0,
          progressPercent: 40,
          revisionCount: 0,
          deletedAt: null,
        ),
        LocalTask(
          id: 'task-baru',
          workspaceId: 'personal-ws',
          projectId: null,
          kind: 'pribadi',
          title: 'Tugas Baru 2 Hari',
          description: null,
          status: 'doing',
          priority: 'medium',
          dueAt: null,
          dueIsDateOnly: true,
          completedAt: null,
          statusChangedAt: nowUtc.subtract(const Duration(days: 2)),
          milestonePaymentId: null,
          sortOrder: 1,
          progressPercent: 20,
          revisionCount: 0,
          deletedAt: null,
        ),
      ];

      final bills = [
        const LocalRecurringBill(
          id: 'bill-kost',
          workspaceId: 'personal-ws',
          name: 'Sewa Kost',
          amount: 1500000,
          categoryId: 'cat-makan',
          accountId: 'acc-bca',
          scheduleType: 'monthly',
          scheduleValue: 18, // H-3 dari 15 Nov
          remindDaysBefore: '[3, 0]',
          active: true,
          autoCreateDraft: true,
          deletedAt: null,
        ),
      ];

      final categories = [
        const LocalCategory(
          id: 'cat-makan',
          workspaceId: 'personal-ws',
          name: 'Makan',
          type: 'expense',
          parentId: null,
          systemKey: null,
          archived: false,
          sortOrder: 0,
        ),
      ];

      final budgets = [
        const LocalBudget(
          id: 'bud-1',
          workspaceId: 'personal-ws',
          categoryId: 'cat-makan',
          amount: 1000000,
          period: 'monthly',
          rollover: false,
          notifyAtPercent: 80,
          deletedAt: null,
        ),
      ];

      final transactions = [
        LocalTransaction(
          id: 'tx-exp',
          workspaceId: 'personal-ws',
          accountId: 'acc-bca',
          categoryId: 'cat-makan',
          type: 'expense',
          status: 'confirmed',
          draftState: null,
          amount: 850000, // 85%
          currency: 'IDR',
          source: 'personal',
          merchant: 'Resto',
          note: null,
          occurredAt: DateTime.utc(2026, 11, 10, 5, 0),
          transferGroupId: null,
          transferDirection: null,
          origin: 'manual',
          deletedAt: null,
        ),
      ];

      final plan = NotificationSchedulerService.evaluatePlan(
        nowUtc: nowUtc,
        prefs: const OrbitNotificationPrefs(
          showTitleOnLockscreen: false,
          weeklyDigestEnabled: true,
          smartConflictAlertsEnabled: true,
          stagnantTaskAlertsEnabled: true,
        ),
        events: events,
        tasks: tasks,
        bills: bills,
        budgets: budgets,
        transactions: transactions,
        categories: categories,
      );

      expect(plan.scheduleConflicts.length, 1);
      expect(plan.stagnantTasks.map((s) => s.taskId), ['task-macet']);
      expect(plan.immediateBudgetAlerts.length, 1);
      expect(plan.immediateBudgetAlerts.first.exceeded, isFalse);
      expect(plan.immediateBillAlerts.length, 1);
      expect(plan.immediateBillAlerts.first.daysLeft, 3);

      // Verifikasi deadline H-24h & H-1h serta privasi lockscreen
      final task24h = plan.scheduled
          .where((s) => s.title.contains('H-24 Jam'))
          .toList();
      final task1h = plan.scheduled
          .where((s) => s.title == 'Pengingat Tenggat Tugas')
          .toList();
      expect(task24h.length, 1);
      expect(task1h.length, 1);
      expect(task24h.first.body, isNot(contains('Refactor API Pembayaran')));
      expect(task1h.first.body, isNot(contains('Refactor API Pembayaran')));

      // Verifikasi Ringkasan Mingguan Senin 08:00 WIB & penyamaran nominal lockscreen
      final digestItem = plan.scheduled.firstWhere(
        (s) => s.id == NotificationSchedulerService.weeklyDigestId,
      );
      final digestAtWib = NotificationService.toJakartaTz(digestItem.scheduledAt);
      expect(digestAtWib.weekday, DateTime.monday);
      expect(digestAtWib.hour, 8);
      expect(digestAtWib.minute, 0);
      expect(plan.weeklyDigest, isNotNull);
      expect(plan.weeklyDigest!.privacyMasked, isTrue);
      expect(plan.weeklyDigest!.summaryText, contains('Rp ••••••'));
      expect(digestItem.body, isNot(contains('850.000')));
    });
  });

  group('4. Privacy Mode, Widget Payload, App Lock, & Realtime', () {
    test('PrivacyModeController menyamarkan nominal di OrbitAmountText dan HomeWidgetSnapshot', () async {
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 't-prio',
          workspaceId: 'personal-ws',
          kind: 'freelance',
          title: 'Siapkan Presentasi',
          status: const drift.Value('revisi'),
          priority: const drift.Value('urgent'),
        ),
      );

      final visibleSnap = await HomeWidgetBridge.buildSnapshotFromDatabase(db);
      expect(visibleSnap.privacyMasked, isFalse);
      expect(visibleSnap.balanceDisplayText, contains('2.500.000'));
      expect(visibleSnap.activeTaskCount, 1);
      expect(visibleSnap.priorityTasks.first.title, 'Siapkan Presentasi');

      await PrivacyModeController.instance.setHideWidgetBalance(true);
      final hiddenByWidgetToggle =
          await HomeWidgetBridge.buildSnapshotFromDatabase(db);
      expect(hiddenByWidgetToggle.privacyMasked, isTrue);
      expect(hiddenByWidgetToggle.balanceDisplayText, 'Rp ••••••');

      await PrivacyModeController.instance.setHideWidgetBalance(false);
      await PrivacyModeController.instance.setEnabled(true);
      final hiddenByPrivacy =
          await HomeWidgetBridge.buildSnapshotFromDatabase(db);
      expect(hiddenByPrivacy.balanceDisplayText, 'Rp ••••••');

      expect(
        HomeWidgetBridge.parseQuickAddTypeFromUri(
          Uri.parse('io.supabase.orbit://quick-add?type=receipt'),
        ),
        'receipt',
      );
      expect(
        HomeWidgetBridge.parseQuickAddTypeFromUri(
          Uri.parse('https://example.com/quick-add?type=receipt'),
        ),
        isNull,
      );
    });

    testWidgets('OrbitAmountText & OrbitPrivacyToggleButton mengubah tampilan nominal saat ditekan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Row(
              children: [
                OrbitAmountText(amount: 1500000),
                OrbitPrivacyToggleButton(),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('1.500.000'), findsOneWidget);
      await tester.tap(find.byKey(const Key('orbit_privacy_toggle_btn')));
      await tester.pump();
      expect(find.text('Rp ••••••'), findsOneWidget);
      expect(find.textContaining('1.500.000'), findsNothing);
    });

    testWidgets('AppLockService menyimpan PIN SHA-256 + salt (tanpa plaintext) dan OrbitAppLockGate membuka kunci', (tester) async {
      expect(AppLockService.instance.isLockEnabled, isFalse);

      await AppLockService.instance.setupPin('246810', enableBiometric: true);
      expect(AppLockService.instance.isLockEnabled, isTrue);
      expect(
        lockStorage.values.values.any((v) => v.contains('246810')),
        isFalse,
      );

      AppLockService.instance.lockNow();
      expect(AppLockService.instance.isLocked, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const OrbitAppLockGate(
            child: Scaffold(body: Text('Konten Aman Orbit')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Orbit Terkunci'), findsOneWidget);
      expect(find.text('Konten Aman Orbit'), findsNothing);

      // PIN salah ditolak
      await tester.enterText(
        find.byKey(const Key('orbit_lock_pin_field')),
        '000000',
      );
      await tester.tap(find.byKey(const Key('orbit_lock_unlock_btn')));
      await tester.pumpAndSettle();
      expect(find.text('PIN tidak cocok. Coba lagi.'), findsOneWidget);
      expect(AppLockService.instance.failedAttempts, 1);

      // PIN benar membuka kunci
      await tester.enterText(
        find.byKey(const Key('orbit_lock_pin_field')),
        '246810',
      );
      await tester.tap(find.byKey(const Key('orbit_lock_unlock_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Konten Aman Orbit'), findsOneWidget);

      // Uji kunci ulang & buka via biometrik
      AppLockService.instance.lockNow();
      await tester.pumpAndSettle();
      expect(find.text('Orbit Terkunci'), findsOneWidget);
      await tester.tap(find.byKey(const Key('orbit_lock_biometric_btn')));
      await tester.pumpAndSettle();
      expect(fakeBio.authenticateCalls, 1);
      expect(find.text('Konten Aman Orbit'), findsOneWidget);
    });

    test('SyncService.subscribeRealtime aman no-op saat offline/belum login', () async {
      await sync.subscribeRealtime();
      expect(sync.isRealtimeSubscribed, isFalse);
      await sync.unsubscribeRealtime();
    });
  });

  group('5. UI Wave 3 (InboxScreen & NotificationSettingsScreen)', () {
    testWidgets('InboxScreen merender tombol scan/simulasi (>=44px), badge Perlu dicek, & impor teks struk tanpa overflow', (tester) async {
      await _setMobileViewport(tester);

      await db.into(db.localTransactions).insert(
        LocalTransactionsCompanion.insert(
          id: 'draft-needs-review',
          workspaceId: 'personal-ws',
          accountId: 'acc-bca',
          type: 'expense',
          status: 'draft',
          draftState: const drift.Value('needs_review'),
          amount: 75000,
          currency: 'IDR',
          source: const drift.Value('notification'),
          merchant: const drift.Value('Merchant Ragu'),
          note: const drift.Value('Bank/E-Wallet - Merchant Ragu'),
          occurredAt: DateTime.utc(2026, 11, 15, 3, 0),
        ),
      );

      await _pumpAndCheckNoOverflow(
        tester,
        MaterialApp(
          theme: AppTheme.light(),
          home: const InboxScreen(),
        ),
      );

      final scanBtn = find.byKey(const Key('inbox_scan_receipt_btn'));
      final simBtn = find.byKey(const Key('inbox_simulate_bank_btn'));
      expect(scanBtn, findsOneWidget);
      expect(simBtn, findsOneWidget);
      expect(find.text('Perlu dicek'), findsOneWidget);

      expect(tester.getSize(scanBtn).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(simBtn).height, greaterThanOrEqualTo(44));

      // Buka modal impor teks struk lalu simpan draf ke Inbox
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('inbox_receipt_text_field')),
        'INDOMARET MENTENG\nTOTAL BAYAR Rp 41.000',
      );
      await tester.tap(find.byKey(const Key('inbox_receipt_save_btn')));
      await tester.pumpAndSettle();

      final allTx = await db.select(db.localTransactions).get();
      expect(
        allTx.any(
          (t) =>
              t.status == 'draft' &&
              t.source == 'receipt' &&
              t.amount == 41000,
        ),
        isTrue,
      );
    });

    testWidgets('NotificationSettingsScreen merender semua seksi Wave 3 tanpa overflow dan parser tester berjalan', (tester) async {
      await _setMobileViewport(tester);

      await _pumpAndCheckNoOverflow(
        tester,
        MaterialApp(
          theme: AppTheme.light(),
          home: const NotificationSettingsScreen(),
        ),
      );

      final scrollable = find.byType(Scrollable).first;
      final digestHeader = find.text('Ringkasan Mingguan & Pengingat Cerdas');
      await tester.scrollUntilVisible(digestHeader, 300, scrollable: scrollable);
      expect(digestHeader, findsOneWidget);

      final widgetHeader = find.text('Widget Android & Sync Latar');
      await tester.scrollUntilVisible(widgetHeader, 300, scrollable: scrollable);
      expect(widgetHeader, findsOneWidget);

      final refreshWidgetBtn = find.byKey(
        const Key('settings_refresh_widget_btn'),
      );
      await tester.scrollUntilVisible(
        refreshWidgetBtn,
        200,
        scrollable: scrollable,
      );
      expect(tester.getSize(refreshWidgetBtn).height, greaterThanOrEqualTo(44));

      final listenerHeader = find.text(
        'Pembaca Notifikasi Bank & Share Target',
      );
      await tester.scrollUntilVisible(listenerHeader, 300, scrollable: scrollable);
      expect(listenerHeader, findsOneWidget);

      final parserField = find.byKey(
        const Key('settings_bank_parser_test_field'),
      );
      await tester.scrollUntilVisible(parserField, 200, scrollable: scrollable);
      await tester.enterText(
        parserField,
        'Pembayaran QRIS BCA Rp 63.000 di WARUNG NASI berhasil',
      );
      final testBtn = find.byKey(const Key('settings_bank_parser_test_btn'));
      await tester.scrollUntilVisible(testBtn, 200, scrollable: scrollable);
      await tester.tap(testBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('63.000'), findsWidgets);

      final securityHeader = find.text('Keamanan & Privasi Aplikasi');
      await tester.scrollUntilVisible(securityHeader, 300, scrollable: scrollable);
      expect(securityHeader, findsOneWidget);
    });
  });
}
