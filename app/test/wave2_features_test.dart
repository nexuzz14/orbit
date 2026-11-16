import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/finance_csv_service.dart';
import 'package:orbit_app/core/services/ics_calendar_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/features/projects/projects_screen.dart';
import 'package:orbit_app/features/schedule/schedule_screen.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_time_tracker_block.dart';
import 'package:orbit_app/features/transactions/transactions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'active_workspace_id': 'personal-ws',
    });
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    final client = SupabaseClient('http://127.0.0.1:54399', 'dummy-anon-key');
    sync = SyncService(db: db, supabase: client);
    AppDatabase.overrideForTesting(db);
    SyncService.overrideForTesting(sync);
  });

  tearDown(() async {
    SyncService.overrideForTesting(null);
    AppDatabase.overrideForTesting(null);
    await db.close();
  });

  group('IcsCalendarService RFC 5545', () {
    test('ekspor dan parse ulang menjaga VEVENT, all-day, dan escaping', () {
      final events = [
        LocalEvent(
          id: 'evt-1',
          workspaceId: 'personal-ws',
          projectId: null,
          kind: 'freelance',
          title: 'Demo Klien, Fase 2; Urgent',
          description: 'Baris 1\nBaris 2',
          location: 'Ruang Rapat A',
          startsAt: DateTime.utc(2026, 11, 15, 2, 0),
          endsAt: DateTime.utc(2026, 11, 15, 3, 30),
          allDay: false,
          timezone: 'Asia/Jakarta',
          recurrence: null,
          externalProvider: null,
          externalEventId: null,
          externalEtag: null,
          lastSyncedAt: null,
          deletedAt: null,
        ),
        LocalEvent(
          id: 'evt-2',
          workspaceId: 'personal-ws',
          projectId: null,
          kind: 'kuliah',
          title: 'Ujian Tengah Semester',
          description: null,
          location: null,
          startsAt: DateTime(2026, 11, 18, 0, 0),
          endsAt: DateTime(2026, 11, 18, 23, 59, 59),
          allDay: true,
          timezone: 'Asia/Jakarta',
          recurrence: null,
          externalProvider: 'google',
          externalEventId: 'gcal-evt-2@google.com',
          externalEtag: null,
          lastSyncedAt: null,
          deletedAt: null,
        ),
      ];

      final ics = IcsCalendarService.exportEventsToIcs(events);
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261118'));
      expect(ics, contains('DTEND;VALUE=DATE:20261119'));
      expect(ics, contains('END:VCALENDAR'));

      final parsed = IcsCalendarService.parseIcsEvents(
        ics,
        workspaceId: 'personal-ws',
      );
      expect(parsed.length, 2);

      final first = parsed[0];
      expect(first.title, 'Demo Klien, Fase 2; Urgent');
      expect(first.description, 'Baris 1\nBaris 2');
      expect(first.location, 'Ruang Rapat A');
      expect(first.allDay, isFalse);
      expect(first.externalProvider, 'google');
      expect(first.externalEventId, 'evt-1@orbit.app');
      expect(first.startsAt.toUtc(), DateTime.utc(2026, 11, 15, 2, 0));

      final second = parsed[1];
      expect(second.title, 'Ujian Tengah Semester');
      expect(second.allDay, isTrue);
      expect(second.externalEventId, 'gcal-evt-2@google.com');
    });

    test('parse contoh Google Calendar dengan folded lines', () {
      const folded =
          'BEGIN:VCALENDAR\r\n'
          'VERSION:2.0\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:fold-1@google.com\r\n'
          'DTSTART:20261120T090000Z\r\n'
          'DTEND:20261120T100000Z\r\n'
          'SUMMARY:Pertemuan Desain \r\n'
          ' Lanjutan\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final parsed = IcsCalendarService.parseIcsEvents(
        folded,
        workspaceId: 'personal-ws',
      );
      expect(parsed.length, 1);
      expect(parsed.first.title, 'Pertemuan Desain Lanjutan');
      expect(parsed.first.uid, 'fold-1@google.com');
    });
  });

  group('FinanceCsvService Impor & Ekspor', () {
    test('parse mutasi bank separator titik koma (;) dengan Debit & Kredit', () {
      final parsed = FinanceCsvService.parseBankMutationCsv(
        FinanceCsvService.sampleBankMutationCsv,
      );
      expect(parsed.length, 4);
      expect(parsed[0].type, 'expense');
      expect(parsed[0].amount, 28500);
      expect(parsed[0].merchant, contains('Kopi Kenangan'));

      expect(parsed[1].type, 'income');
      expect(parsed[1].amount, 3500000);

      expect(parsed[2].type, 'expense');
      expect(parsed[2].amount, 185000);

      expect(parsed[3].type, 'income');
      expect(parsed[3].amount, 1200000);
    });

    test('parse mutasi bank separator koma (,) dengan Nominal bertanda', () {
      const csvComma =
          'Date,Description,Amount\n'
          '2026-11-15,"Makan Siang, Warung",-45000\n'
          '2026-11-16,"Gaji Magang",+2500000\n';

      final parsed = FinanceCsvService.parseBankMutationCsv(csvComma);
      expect(parsed.length, 2);
      expect(parsed[0].type, 'expense');
      expect(parsed[0].amount, 45000);
      expect(parsed[0].note, 'Makan Siang, Warung');
      expect(parsed[1].type, 'income');
      expect(parsed[1].amount, 2500000);
    });

    test('ekspor CSV mengamankan sel formula injection', () {
      final txs = [
        LocalTransaction(
          id: 'tx-sec',
          workspaceId: 'personal-ws',
          accountId: 'acc-1',
          categoryId: null,
          projectId: null,
          type: 'expense',
          status: 'confirmed',
          draftState: null,
          amount: 50000,
          currency: 'IDR',
          source: 'personal',
          merchant: '=HYPERLINK("http://evil.example","Klik")',
          note: '+cmd|calc',
          occurredAt: DateTime.utc(2026, 11, 15, 5, 0),
          transferGroupId: null,
          transferDirection: null,
          origin: 'manual',
          deletedAt: null,
        ),
      ];

      final csv = FinanceCsvService.exportTransactionsCsv(
        txs,
        {'acc-1': 'BCA'},
        {},
      );
      expect(csv, contains("'=HYPERLINK"));
      expect(csv, contains("'+cmd|calc"));
    });
  });

  group('OrbitTimeTrackerBlock & Drift Persistence', () {
    testWidgets('Stopwatch tick + simpan sesi + catat manual masuk Outbox', (
      tester,
    ) async {
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'task-focus-1',
          workspaceId: 'personal-ws',
          kind: 'freelance',
          title: 'Optimasi Query',
          status: const drift.Value('doing'),
          priority: const drift.Value('high'),
          estimateMinutes: const drift.Value(60),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: OrbitTimeTrackerBlock(
                  taskId: 'task-focus-1',
                  estimateMinutes: 60,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pindah ke mode Stopwatch
      await tester.tap(find.text('Stopwatch'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mulai'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:02'), findsOneWidget);

      await tester.tap(find.text('Jeda'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Sesi'));
      await tester.pumpAndSettle();

      // Pindah ke Catat Manual
      await tester.tap(find.text('Catat Manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Catatan Waktu'));
      await tester.pumpAndSettle();

      final logs = await db.select(db.localTaskTimeLogs).get();
      expect(logs.length, 2);
      expect(logs.any((l) => l.mode == 'stopwatch' && l.durationSeconds == 2), isTrue);
      expect(logs.any((l) => l.mode == 'manual' && l.durationSeconds == 1800), isTrue);

      final outbox = await db.select(db.syncOutbox).get();
      expect(
        outbox.where((o) => o.targetTable == 'task_time_logs').length,
        2,
      );
    });
  });

  group('Widget Overhaul Gelombang 2', () {
    testWidgets('ScheduleScreen: Daftar | Kalender | Linimasa + Impor .ics', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final dayBase = DateTime(now.year, now.month, now.day, 10, 0);
      await db.into(db.localEvents).insert(
        LocalEventsCompanion.insert(
          id: 'ev-a',
          workspaceId: 'personal-ws',
          kind: 'intern',
          title: 'Standup Tim',
          startsAt: dayBase,
          endsAt: dayBase.add(const Duration(hours: 1)),
        ),
      );
      await db.into(db.localEvents).insert(
        LocalEventsCompanion.insert(
          id: 'ev-b',
          workspaceId: 'personal-ws',
          kind: 'kuliah',
          title: 'Kelas Algoritma',
          startsAt: dayBase.add(const Duration(minutes: 30)),
          endsAt: dayBase.add(const Duration(hours: 2)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Standup Tim'), findsOneWidget);
      expect(find.text('Bentrok Waktu'), findsWidgets);

      // Switch ke Kalender
      await tester.tap(find.text('Kalender'));
      await tester.pumpAndSettle();
      expect(find.text('Hari Ini'), findsOneWidget);

      // Switch ke Linimasa
      await tester.tap(find.text('Linimasa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Linimasa Harian'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);

      // Buka Panel Sinkron Google Calendar & .ics dan impor contoh
      await tester.tap(find.text('Sinkron / .ics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muat Contoh .ics Google Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impor .ics ke Agenda'));
      await tester.pumpAndSettle();

      final events = await db.select(db.localEvents).get();
      expect(events.any((e) => e.externalProvider == 'google'), isTrue);
    });

    testWidgets('ProjectsScreen: 4 tab, Tandai Lunas, Overload, dan Margin', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await db.into(db.localProjects).insert(
        LocalProjectsCompanion.insert(
          id: 'proj-1',
          workspaceId: 'personal-ws',
          kind: 'freelance',
          name: 'Portal Kampus',
          status: const drift.Value('active'),
          clientName: const drift.Value('Fakultas TI'),
          contractValue: const drift.Value(5000000),
          startedOn: drift.Value(DateTime(2026, 11, 1)),
          deadline: drift.Value(DateTime(2026, 11, 30)),
        ),
      );
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 't-heavy',
          workspaceId: 'personal-ws',
          projectId: const drift.Value('proj-1'),
          kind: 'freelance',
          title: 'Bangun Modul Auth & Billing',
          status: const drift.Value('doing'),
          priority: const drift.Value('high'),
          estimateMinutes: const drift.Value(2600), // > 40 jam
        ),
      );
      await db.into(db.localProjectPayments).insert(
        LocalProjectPaymentsCompanion.insert(
          id: 'pay-1',
          workspaceId: 'personal-ws',
          projectId: 'proj-1',
          label: 'Termin 1 DP',
          amount: 2500000,
          dueDate: drift.Value(DateTime(2026, 11, 20)),
        ),
      );
      await db.into(db.localAccounts).insert(
        LocalAccountsCompanion.insert(
          id: 'acc-main',
          workspaceId: 'personal-ws',
          name: 'BCA Utama',
          type: 'bank',
          currency: 'IDR',
          currentBalance: const drift.Value(1000000),
        ),
      );
      await db.into(db.localTransactions).insert(
        LocalTransactionsCompanion.insert(
          id: 'tx-exp-proj',
          workspaceId: 'personal-ws',
          accountId: 'acc-main',
          projectId: const drift.Value('proj-1'),
          type: 'expense',
          status: 'confirmed',
          amount: 350000,
          currency: 'IDR',
          merchant: const drift.Value('Sewa Server'),
          occurredAt: DateTime(2026, 11, 10),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ProjectsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tab 1: Kegiatan
      expect(find.text('Portal Kampus'), findsOneWidget);

      // Tab 2: Piutang + Tandai Lunas
      await tester.tap(find.text('Piutang'));
      await tester.pumpAndSettle();
      expect(find.text('Termin 1 DP'), findsOneWidget);
      await tester.tap(find.text('Tandai Lunas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tandai Lunas & Sinkronkan'));
      await tester.pumpAndSettle();

      final updatedPay =
          await (db.select(
            db.localProjectPayments,
          )..where((p) => p.id.equals('pay-1'))).getSingle();
      expect(updatedPay.status, 'paid');

      // Tab 3: Linimasa & Beban + Peringatan Overload
      await tester.tap(find.text('Linimasa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Peringatan Overload'), findsOneWidget);

      // Tab 4: Laporan & Margin
      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Laporan & Margin Proyek'), findsOneWidget);
      expect(find.text('Ekspor CSV Laporan Proyek'), findsOneWidget);
    });

    testWidgets('TransactionsScreen: Grafik Ringkasan + Impor CSV Batch', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await db.into(db.localAccounts).insert(
        LocalAccountsCompanion.insert(
          id: 'acc-bca',
          workspaceId: 'personal-ws',
          name: 'BCA Operasional',
          type: 'bank',
          currency: 'IDR',
          currentBalance: const drift.Value(500000),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Impor CSV Mutasi Batch
      await tester.tap(find.text('Impor CSV Mutasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muat Contoh Mutasi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pratinjau (4 baris siap disimpan)'), findsOneWidget);

      await tester.tap(find.text('Simpan Batch (4)'));
      await tester.pumpAndSettle();

      final txs = await db.select(db.localTransactions).get();
      expect(txs.where((t) => t.origin == 'csv_import').length, 4);

      // Switch ke Ringkasan -> pastikan Grafik Ringkasan muncul
      await tester.tap(find.text('Ringkasan'));
      await tester.pumpAndSettle();
      expect(find.text('Arus Kas Bulanan'), findsOneWidget);
      expect(find.text('Top Kategori Pengeluaran'), findsOneWidget);
    });
  });
}
