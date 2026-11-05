import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/accounts/accounts_screen.dart';
import 'package:orbit_app/features/auth/login_screen.dart';
import 'package:orbit_app/features/home/home_screen.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/planning/planning_screen.dart';
import 'package:orbit_app/features/projects/projects_screen.dart';
import 'package:orbit_app/features/schedule/schedule_screen.dart';
import 'package:orbit_app/features/tasks/tasks_screen.dart';
import 'package:orbit_app/features/today/today_screen.dart';
import 'package:orbit_app/features/transactions/transactions_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    try {
      final segoeFile = File('C:/Windows/Fonts/segoeui.ttf');
      if (segoeFile.existsSync()) {
        final bytes = segoeFile.readAsBytesSync();
        final fontLoader = FontLoader('Segoe UI')
          ..addFont(Future.value(ByteData.view(bytes.buffer)));
        await fontLoader.load();

        final robotoLoader = FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(bytes.buffer)));
        await robotoLoader.load();
      }

      final iconFile = File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
      if (iconFile.existsSync()) {
        final iconBytes = iconFile.readAsBytesSync();
        final iconLoader = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.view(iconBytes.buffer)));
        await iconLoader.load();
      }
    } catch (e) {
      debugPrint('Font load error: $e');
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, Object>{};
        }
        return true;
      },
    );
    try {
      await Supabase.initialize(
        url: 'http://127.0.0.1:54399',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.dummy',
      );
    } catch (_) {}
  });

  Future<AppDatabase> createPopulatedTestDb() async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    await db.into(db.localAccounts).insert(
          LocalAccountsCompanion.insert(
            id: 'acc-1',
            workspaceId: 'ws-1',
            name: 'BCA Utama',
            type: 'bank',
            currency: 'IDR',
            currentBalance: const Value(12450000),
          ),
        );
    await db.into(db.localAccounts).insert(
          LocalAccountsCompanion.insert(
            id: 'acc-2',
            workspaceId: 'ws-1',
            name: 'GoPay',
            type: 'ewallet',
            currency: 'IDR',
            currentBalance: const Value(485000),
          ),
        );

    await db.into(db.localProjects).insert(
          LocalProjectsCompanion.insert(
            id: 'proj-1',
            workspaceId: 'ws-1',
            kind: 'intern',
            name: 'Magang Backend Engineer',
            color: const Value('#0284C7'),
          ),
        );
    await db.into(db.localProjects).insert(
          LocalProjectsCompanion.insert(
            id: 'proj-2',
            workspaceId: 'ws-1',
            kind: 'freelance',
            name: 'Redesign Portal Klien',
            color: const Value('#6D28D9'),
          ),
        );

    await db.into(db.localProjectPayments).insert(
          LocalProjectPaymentsCompanion.insert(
            id: 'pay-1',
            workspaceId: 'ws-1',
            projectId: 'proj-2',
            label: 'Termin 1 Desain & Prototipe',
            amount: 3500000,
            status: const Value('pending'),
          ),
        );

    await db.into(db.localEvents).insert(
          LocalEventsCompanion.insert(
            id: 'ev-1',
            workspaceId: 'ws-1',
            projectId: const Value('proj-1'),
            kind: 'intern',
            title: 'Sinkronisasi Sprint Engineering',
            startsAt: DateTime(now.year, now.month, now.day, 9, 0),
            endsAt: DateTime(now.year, now.month, now.day, 10, 0),
            location: const Value('Google Meet'),
          ),
        );
    await db.into(db.localEvents).insert(
          LocalEventsCompanion.insert(
            id: 'ev-2',
            workspaceId: 'ws-1',
            projectId: const Value('proj-2'),
            kind: 'freelance',
            title: 'Presentasi Prototipe ke Klien',
            startsAt: DateTime(now.year, now.month, now.day, 9, 30),
            endsAt: DateTime(now.year, now.month, now.day, 11, 0),
            location: const Value('Zoom'),
          ),
        );

    await db.into(db.localTasks).insert(
          LocalTasksCompanion.insert(
            id: 'task-1',
            workspaceId: 'ws-1',
            projectId: const Value('proj-2'),
            kind: 'freelance',
            title: 'Finalisasi sistem desain dan komponen UI',
            status: const Value('hari_ini'),
            priority: const Value('tinggi'),
            dueAt: Value(now.add(const Duration(hours: 4))),
          ),
        );
    await db.into(db.localTasks).insert(
          LocalTasksCompanion.insert(
            id: 'task-2',
            workspaceId: 'ws-1',
            kind: 'kuliah',
            title: 'Kumpulkan laporan praktikum arsitektur perangkat lunak',
            status: const Value('hari_ini'),
            priority: const Value('tinggi'),
            dueAt: Value(yesterday),
          ),
        );

    await db.into(db.localTransactions).insert(
          LocalTransactionsCompanion.insert(
            id: 'tx-1',
            workspaceId: 'ws-1',
            accountId: 'acc-1',
            categoryId: const Value('Freelance & Proyek'),
            type: 'income',
            status: 'confirmed',
            amount: 2500000,
            currency: 'IDR',
            source: const Value('freelance'),
            merchant: const Value('Studio Kreatif Nusantara'),
            occurredAt: DateTime(now.year, now.month, now.day, 11, 0),
          ),
        );
    await db.into(db.localTransactions).insert(
          LocalTransactionsCompanion.insert(
            id: 'tx-2',
            workspaceId: 'ws-1',
            accountId: 'acc-2',
            categoryId: const Value('Makan & Minum'),
            type: 'expense',
            status: 'confirmed',
            amount: 48000,
            currency: 'IDR',
            source: const Value('intern'),
            merchant: const Value('Kopi Kenangan'),
            occurredAt: DateTime(now.year, now.month, now.day, 8, 30),
          ),
        );
    await db.into(db.localTransactions).insert(
          LocalTransactionsCompanion.insert(
            id: 'tx-3',
            workspaceId: 'ws-1',
            accountId: 'acc-2',
            categoryId: const Value('Transportasi'),
            type: 'expense',
            status: 'draft',
            amount: 32000,
            currency: 'IDR',
            source: const Value('kuliah'),
            merchant: const Value('Gojek Indonesia'),
            occurredAt: DateTime(
              yesterday.year,
              yesterday.month,
              yesterday.day,
              17,
              20,
            ),
          ),
        );

    await db.into(db.localBudgets).insert(
          LocalBudgetsCompanion.insert(
            id: 'b-1',
            workspaceId: 'ws-1',
            categoryId: 'Makanan & Minuman',
            amount: 1500000,
          ),
        );
    await db.into(db.localBudgets).insert(
          LocalBudgetsCompanion.insert(
            id: 'b-2',
            workspaceId: 'ws-1',
            categoryId: 'Transportasi & BBM',
            amount: 600000,
          ),
        );
    await db.into(db.localBudgets).insert(
          LocalBudgetsCompanion.insert(
            id: 'b-3',
            workspaceId: 'ws-1',
            categoryId: 'Kebutuhan Kuliah & Buku',
            amount: 500000,
          ),
        );

    await db.into(db.localRecurringBills).insert(
          LocalRecurringBillsCompanion.insert(
            id: 'bill-1',
            workspaceId: 'ws-1',
            name: 'Spotify Premium Student',
            amount: 27500,
            categoryId: 'cat-1',
            accountId: 'acc-1',
            scheduleType: const Value('monthly'),
            scheduleValue: const Value(14),
          ),
        );
    await db.into(db.localRecurringBills).insert(
          LocalRecurringBillsCompanion.insert(
            id: 'bill-2',
            workspaceId: 'ws-1',
            name: 'GitHub Copilot Pro',
            amount: 160000,
            categoryId: 'cat-1',
            accountId: 'acc-1',
            scheduleType: const Value('monthly'),
            scheduleValue: const Value(20),
          ),
        );
    await db.into(db.localRecurringBills).insert(
          LocalRecurringBillsCompanion.insert(
            id: 'bill-3',
            workspaceId: 'ws-1',
            name: 'Internet Kos Fiber',
            amount: 250000,
            categoryId: 'cat-1',
            accountId: 'acc-1',
            scheduleType: const Value('monthly'),
            scheduleValue: const Value(1),
          ),
        );

    await db.into(db.localSavingsGoals).insert(
          LocalSavingsGoalsCompanion.insert(
            id: 'goal-1',
            workspaceId: 'ws-1',
            name: 'Dana Darurat Mahasiswa',
            targetAmount: 10000000,
            currentAmount: const Value(6500000),
          ),
        );
    await db.into(db.localSavingsGoals).insert(
          LocalSavingsGoalsCompanion.insert(
            id: 'goal-2',
            workspaceId: 'ws-1',
            name: 'Upgrade Laptop Kerja',
            targetAmount: 18000000,
            currentAmount: const Value(9200000),
          ),
        );

    return db;
  }

  Future<void> captureGolden(
    WidgetTester tester, {
    required Widget child,
    required ThemeMode themeMode,
    required String relativePath,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final lightTheme = AppTheme.light().copyWith(
      textTheme: AppTheme.light().textTheme.apply(fontFamily: 'Segoe UI'),
    );
    final darkTheme = AppTheme.dark().copyWith(
      textTheme: AppTheme.dark().textTheme.apply(fontFamily: 'Segoe UI'),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: lightTheme,
        darkTheme: darkTheme,
        home: child,
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(relativePath),
    );
  }

  testWidgets('Golden Visual Tests: Checkpoint & Sesudah (Semua Layar App)',
      (tester) async {
    final populatedDb = await createPopulatedTestDb();
    final emptyDb = AppDatabase.forExecutor(NativeDatabase.memory());

    try {
      // =======================================================================
      // A. CHECKPOINT GOLDEN SCREENSHOTS
      // =======================================================================
      AppDatabase.overrideForTesting(populatedDb);

      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 0),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/checkpoint/app-hari-ini-terang.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 0),
        themeMode: ThemeMode.dark,
        relativePath: '../../docs/design/checkpoint/app-hari-ini-gelap.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 2),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/checkpoint/app-transaksi-terang.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 2),
        themeMode: ThemeMode.dark,
        relativePath: '../../docs/design/checkpoint/app-transaksi-gelap.png',
      );
      await captureGolden(
        tester,
        child: const Scaffold(body: TransactionFormSheet()),
        themeMode: ThemeMode.light,
        relativePath:
            '../../docs/design/checkpoint/app-form-transaksi-terang.png',
      );
      await captureGolden(
        tester,
        child: const Scaffold(body: TransactionFormSheet()),
        themeMode: ThemeMode.dark,
        relativePath:
            '../../docs/design/checkpoint/app-form-transaksi-gelap.png',
      );

      // =======================================================================
      // B. SESUDAH GOLDEN SCREENSHOTS (POPULATED DATA - TERANG & GELAP)
      // =======================================================================
      await captureGolden(
        tester,
        child: const LoginScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-login-data.png',
      );
      await captureGolden(
        tester,
        child: const LoginScreen(),
        themeMode: ThemeMode.dark,
        relativePath: '../../docs/design/sesudah/app-login-gelap.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 0),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-hari-ini-data.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 0),
        themeMode: ThemeMode.dark,
        relativePath: '../../docs/design/sesudah/app-hari-ini-gelap.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 1),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-jadwal-data.png',
      );
      await captureGolden(
        tester,
        child: const TasksScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-tugas-data.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 2),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-transaksi-data.png',
      );
      await captureGolden(
        tester,
        child: const AccountsScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-akun-data.png',
      );
      await captureGolden(
        tester,
        child: const InboxScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-inbox-data.png',
      );
      await captureGolden(
        tester,
        child: const PlanningScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-perencanaan-data.png',
      );
      await captureGolden(
        tester,
        child: const ProjectsScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-proyek-data.png',
      );
      await captureGolden(
        tester,
        child: const HomeScreen(initialIndex: 3),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-lainnya-data.png',
      );

      // =======================================================================
      // C. SESUDAH GOLDEN SCREENSHOTS (EMPTY, LOADING, ERROR STATES)
      // =======================================================================
      AppDatabase.overrideForTesting(emptyDb);

      await captureGolden(
        tester,
        child: const TodayScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-hari-ini-empty.png',
      );
      await captureGolden(
        tester,
        child: const TodayScreen(forceLoading: true),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-hari-ini-loading.png',
      );
      await captureGolden(
        tester,
        child: const TodayScreen(
          forceError: 'Koneksi ke database lokal terputus.',
        ),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-hari-ini-error.png',
      );
      await captureGolden(
        tester,
        child: const ScheduleScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-jadwal-empty.png',
      );
      await captureGolden(
        tester,
        child: const TasksScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-tugas-empty.png',
      );
      await captureGolden(
        tester,
        child: const TransactionsScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-transaksi-empty.png',
      );
      await captureGolden(
        tester,
        child: const AccountsScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-akun-empty.png',
      );
      await captureGolden(
        tester,
        child: const InboxScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-inbox-empty.png',
      );
      await captureGolden(
        tester,
        child: const PlanningScreen(forceEmpty: true),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-perencanaan-empty.png',
      );
      await captureGolden(
        tester,
        child: const ProjectsScreen(),
        themeMode: ThemeMode.light,
        relativePath: '../../docs/design/sesudah/app-proyek-empty.png',
      );
    } finally {
      AppDatabase.overrideForTesting(null);
      await populatedDb.close();
      await emptyDb.close();
    }
  });
}
