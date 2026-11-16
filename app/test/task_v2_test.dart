import 'dart:convert';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/features/home/home_screen.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/tasks/orbit_task_detail_page.dart';
import 'package:orbit_app/features/tasks/tasks_screen.dart';
import 'package:orbit_app/features/tasks/widgets/orbit_kanban_board.dart';
import 'package:orbit_app/features/today/today_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  late AppDatabase db;
  late SyncService sync;

  setUp(() {
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

  Widget wrapMaterial(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: child,
    );
  }

  group('Kanban 14-hari Done & Macet >5 hari', () {
    test('filterDoneTasksForKanban hides tasks older than 14 days by default', () {
      final now = DateTime(2026, 11, 15, 12);
      final recentDone = LocalTask(
        id: 'done-recent',
        workspaceId: 'ws-1',
        kind: 'kuliah',
        title: 'Tugas Baru Selesai',
        status: 'done',
        priority: 'sedang',
        dueIsDateOnly: false,
        completedAt: now.subtract(const Duration(days: 5)),
        sortOrder: 0,
        progressPercent: 100,
        revisionCount: 0,
      );
      final oldDone = LocalTask(
        id: 'done-old',
        workspaceId: 'ws-1',
        kind: 'kuliah',
        title: 'Tugas Lama Selesai',
        status: 'done',
        priority: 'sedang',
        dueIsDateOnly: false,
        completedAt: now.subtract(const Duration(days: 20)),
        sortOrder: 1,
        progressPercent: 100,
        revisionCount: 0,
      );

      final defaultVisible = filterDoneTasksForKanban(
        [recentDone, oldDone],
        showAllDone: false,
        now: now,
      );
      expect(defaultVisible.map((t) => t.id), ['done-recent']);

      final allVisible = filterDoneTasksForKanban(
        [recentDone, oldDone],
        showAllDone: true,
        now: now,
      );
      expect(allVisible.map((t) => t.id), ['done-recent', 'done-old']);
    });

    test('isOrbitTaskStagnant flags active tasks unchanged >5 days only', () {
      final now = DateTime(2026, 11, 15, 12);
      final stagnantTask = LocalTask(
        id: 't-stag',
        workspaceId: 'ws-1',
        kind: 'intern',
        title: 'Review PR API',
        status: 'doing',
        priority: 'tinggi',
        dueIsDateOnly: false,
        statusChangedAt: now.subtract(const Duration(days: 6)),
        sortOrder: 0,
        progressPercent: 40,
        revisionCount: 0,
      );
      final freshTask = stagnantTask.copyWith(
        id: 't-fresh',
        statusChangedAt: Value(now.subtract(const Duration(days: 3))),
      );
      final doneOldTask = stagnantTask.copyWith(
        id: 't-done',
        status: 'done',
        completedAt: Value(now.subtract(const Duration(days: 2))),
      );

      expect(isOrbitTaskStagnant(stagnantTask, now: now), isTrue);
      expect(isOrbitTaskStagnant(freshTask, now: now), isFalse);
      expect(isOrbitTaskStagnant(doneOldTask, now: now), isFalse);
    });

    testWidgets('OrbitKanbanBoard renders 4 columns, Macet >5 hari, Revisi count, and Lihat semua selesai toggle',
        (tester) async {
      final now = DateTime(2026, 11, 15, 12);
      final tasks = [
        LocalTask(
          id: 't-1',
          workspaceId: 'ws-1',
          kind: 'freelance',
          title: 'Wireframe Beranda',
          status: 'todo',
          priority: 'tinggi',
          dueAt: now.subtract(const Duration(days: 1)),
          dueIsDateOnly: false,
          statusChangedAt: now.subtract(const Duration(days: 7)),
          sortOrder: 0,
          progressPercent: 25,
          revisionCount: 2,
        ),
        LocalTask(
          id: 't-2',
          workspaceId: 'ws-1',
          kind: 'kuliah',
          title: 'Makalah Bab 2',
          status: 'done',
          priority: 'sedang',
          dueIsDateOnly: false,
          completedAt: now.subtract(const Duration(days: 3)),
          sortOrder: 0,
          progressPercent: 100,
          revisionCount: 0,
        ),
        LocalTask(
          id: 't-3',
          workspaceId: 'ws-1',
          kind: 'pribadi',
          title: 'Arsip Lama',
          status: 'done',
          priority: 'rendah',
          dueIsDateOnly: false,
          completedAt: now.subtract(const Duration(days: 25)),
          sortOrder: 1,
          progressPercent: 100,
          revisionCount: 0,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(1300, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapMaterial(
          Scaffold(
            body: OrbitKanbanBoard(
              tasks: tasks,
              projectsById: const {},
              referenceNow: now,
              onTapTask: (_) {},
              onChangeStatus: (_, __, ___) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum dikerjakan'), findsOneWidget);
      expect(find.text('Dikerjakan'), findsOneWidget);
      expect(find.text('Revisi'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      expect(find.text('Wireframe Beranda'), findsOneWidget);
      expect(find.text('Revisi 2 kali'), findsOneWidget);
      expect(find.text('Macet >5 hari'), findsOneWidget);

      expect(find.text('Makalah Bab 2'), findsOneWidget);
      expect(find.text('Arsip Lama'), findsNothing);
      expect(find.text('Lihat semua selesai (+1)'), findsOneWidget);

      await tester.tap(find.text('Lihat semua selesai (+1)'));
      await tester.pumpAndSettle();

      expect(find.text('Arsip Lama'), findsOneWidget);
      expect(find.text('Tampilkan 14 hari terakhir'), findsOneWidget);
    });
  });

  group('Validasi wajib catatan alasan ke status Revisi', () {
    testWidgets('Moving status to Revisi blocks empty reason and accepts filled reason',
        (tester) async {
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'task-rev-1',
          workspaceId: 'ws-1',
          kind: 'freelance',
          title: 'Desain Landing Page',
          status: const Value('doing'),
        ),
      );

      final task = await (db.select(db.localTasks)
            ..where((t) => t.id.equals('task-rev-1')))
          .getSingle();

      String? capturedStatus;
      String? capturedNote;

      await tester.pumpWidget(
        wrapMaterial(
          Scaffold(
            body: OrbitKanbanBoard(
              tasks: [task],
              projectsById: const {},
              onTapTask: (_) {},
              onChangeStatus: (t, toStatus, note) async {
                capturedStatus = toStatus;
                capturedNote = note;
                await sync.changeTaskStatus(
                  taskId: t.id,
                  toStatus: toStatus,
                  note: note,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Pindah status
      await tester.tap(find.text('Pindah status'));
      await tester.pumpAndSettle();

      // Pilih Revisi
      await tester.tap(find.text('Memerlukan catatan alasan revisi'));
      await tester.pumpAndSettle();

      expect(find.text('Alasan Pemindahan ke Revisi'), findsOneWidget);

      // Coba kirim kosong -> harus ditolak dengan pesan error
      await tester.tap(find.text('Kirim Revisi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Catatan alasan revisi wajib diisi sebelum melanjutkan.'),
        findsOneWidget,
      );
      expect(capturedStatus, isNull);

      // Isi alasan lalu kirim
      await tester.enterText(
        find.byType(TextField).last,
        'Kontras teks tombol kurang jelas',
      );
      await tester.tap(find.text('Kirim Revisi'));
      await tester.pumpAndSettle();

      expect(capturedStatus, 'revisi');
      expect(capturedNote, 'Kontras teks tombol kurang jelas');

      final updated = await (db.select(db.localTasks)
            ..where((t) => t.id.equals('task-rev-1')))
          .getSingle();
      expect(updated.status, 'revisi');
      expect(updated.revisionCount, 1);
      expect(updated.latestRevisionNote, 'Kontras teks tombol kurang jelas');

      final history = await (db.select(db.localTaskStatusHistories)
            ..where((h) => h.taskId.equals('task-rev-1')))
          .get();
      expect(history.length, 1);
      expect(history.first.note, 'Kontras teks tombol kurang jelas');
    });
  });

  group('OrbitProgressControl mode terkunci vs slider step-5', () {
    testWidgets('Locked mode hides Slider and shows lock icon', (tester) async {
      await tester.pumpWidget(
        wrapMaterial(
          Scaffold(
            body: OrbitProgressControl(
              value: 50,
              lockedByChecklist: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('50%'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('Unlocked mode shows step-5 Slider and fires quantized callback',
        (tester) async {
      int latestValue = 20;
      await tester.pumpWidget(
        wrapMaterial(
          Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => OrbitProgressControl(
                value: latestValue,
                lockedByChecklist: false,
                onChanged: (v) => setState(() => latestValue = v),
              ),
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);
      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.divisions, 20);
      slider.onChanged!(43.0);
      await tester.pump();
      expect(latestValue, 45);
      expect(find.text('45%'), findsOneWidget);
    });
  });

  group('Nested Subtasks & Checklist Auto-Progress', () {
    test('Checklist and Subtasks automatically recompute parent progressPercent',
        () async {
      final parentId = await sync.createTask(
        title: 'Rilis Aplikasi v2',
        kind: 'intern',
        initialChecklist: ['Setup DB', 'Build UI'],
      );

      var parent = await (db.select(db.localTasks)
            ..where((t) => t.id.equals(parentId)))
          .getSingle();
      expect(parent.progressPercent, 0);

      final items = await (db.select(db.localTaskChecklistItems)
            ..where((c) => c.taskId.equals(parentId)))
          .get();
      expect(items.length, 2);

      // Selesaikan 1 checklist -> 50%
      await sync.toggleChecklistItem(itemId: items[0].id, done: true);
      parent = await (db.select(db.localTasks)
            ..where((t) => t.id.equals(parentId)))
          .getSingle();
      expect(parent.progressPercent, 50);

      // Selesaikan checklist ke-2 -> 100%
      await sync.toggleChecklistItem(itemId: items[1].id, done: true);
      parent = await (db.select(db.localTasks)
            ..where((t) => t.id.equals(parentId)))
          .getSingle();
      expect(parent.progressPercent, 100);

      // Hapus semua checklist agar subtugas mengambil alih kalkulasi
      await sync.deleteChecklistItem(items[0].id);
      await sync.deleteChecklistItem(items[1].id);

      final sub1 = await sync.createTask(
        title: 'Subtugas A',
        kind: 'intern',
        parentTaskId: parentId,
      );
      final sub2 = await sync.createTask(
        title: 'Subtugas B',
        kind: 'intern',
        parentTaskId: parentId,
      );

      parent = await (db.select(db.localTasks)
            ..where((t) => t.id.equals(parentId)))
          .getSingle();
      expect(parent.progressPercent, 0);

      await sync.changeTaskStatus(taskId: sub1, toStatus: 'done');
      parent = await (db.select(db.localTasks)
            ..where((t) => t.id.equals(parentId)))
          .getSingle();
      expect(parent.progressPercent, 50);

      await sync.changeTaskStatus(taskId: sub2, toStatus: 'done');
      parent = await (db.select(db.localTasks)
            ..where((t) => t.id.equals(parentId)))
          .getSingle();
      expect(parent.progressPercent, 100);
    });
  });

  group('OrbitCommandSearch Offline Drift Query', () {
    testWidgets('Searches across localTasks, localProjects, localEvents, and localTransactions',
        (tester) async {
      await db.into(db.localProjects).insert(
        LocalProjectsCompanion.insert(
          id: 'proj-alpha',
          workspaceId: 'ws-1',
          kind: 'freelance',
          name: 'Proposal Redaksi Orbit',
        ),
      );
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'task-alpha',
          workspaceId: 'ws-1',
          kind: 'freelance',
          title: 'Kirim Proposal Klien',
        ),
      );
      await db.into(db.localEvents).insert(
        LocalEventsCompanion.insert(
          id: 'evt-alpha',
          workspaceId: 'ws-1',
          kind: 'kuliah',
          title: 'Presentasi Proposal Skripsi',
          startsAt: DateTime(2026, 11, 15, 10),
          endsAt: DateTime(2026, 11, 15, 11),
        ),
      );
      await db.into(db.localTransactions).insert(
        LocalTransactionsCompanion.insert(
          id: 'tx-alpha',
          workspaceId: 'ws-1',
          accountId: 'acc-1',
          type: 'expense',
          status: 'confirmed',
          amount: 50000,
          currency: 'IDR',
          merchant: const Value('Cetak Proposal'),
          occurredAt: DateTime(2026, 11, 15, 9),
        ),
      );

      GlobalSearchHit? tappedHit;

      await tester.pumpWidget(
        wrapMaterial(
          Scaffold(
            body: OrbitCommandSearchSheet(
              onSelectHit: (hit) => tappedHit = hit,
            ),
          ),
        ),
      );

      // Quick Actions tampil saat query kosong
      expect(find.text('AKSI CEPAT'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Proposal');
      await tester.pumpAndSettle();

      expect(find.text('Kirim Proposal Klien'), findsOneWidget);
      expect(find.text('Proposal Redaksi Orbit'), findsOneWidget);
      expect(find.text('Presentasi Proposal Skripsi'), findsOneWidget);
      expect(find.text('Cetak Proposal'), findsOneWidget);

      await tester.tap(find.text('Kirim Proposal Klien'));
      await tester.pumpAndSettle();
      expect(tappedHit?.entityType, 'task');
      expect(tappedHit?.entityId, 'task-alpha');
    });
  });

  group('OrbitTaskDetailPage Rendering & Interaction', () {
    testWidgets('Renders all Notion/Jira sections and adds comment/checklist offline',
        (tester) async {
      await db.into(db.localProjects).insert(
        LocalProjectsCompanion.insert(
          id: 'proj-det',
          workspaceId: 'ws-1',
          kind: 'intern',
          name: 'Magang Backend',
        ),
      );
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'task-det-1',
          workspaceId: 'ws-1',
          projectId: const Value('proj-det'),
          kind: 'intern',
          title: 'Migrasi Endpoint Auth',
          status: const Value('revisi'),
          priority: const Value('tinggi'),
          revisionCount: const Value(1),
          latestRevisionNote: const Value('Tambahkan rate limiter'),
          estimateMinutes: const Value(90),
          recurrenceRuleJson: Value(jsonEncode({'freq': 'weekly', 'interval': 1})),
          tagsJson: Value(jsonEncode(['backend', 'keamanan'])),
          description: const Value('Implementasi refresh token rotasi'),
        ),
      );
      await db.into(db.localTaskChecklistItems).insert(
        LocalTaskChecklistItemsCompanion.insert(
          id: 'cl-det-1',
          taskId: 'task-det-1',
          textContent: 'Tulis unit test',
          done: const Value(false),
        ),
      );
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'sub-det-1',
          workspaceId: 'ws-1',
          parentTaskId: const Value('task-det-1'),
          kind: 'intern',
          title: 'Setup middleware Redis',
          status: const Value('todo'),
        ),
      );

      await tester.pumpWidget(
        wrapMaterial(const OrbitTaskDetailPage(taskId: 'task-det-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Migrasi Endpoint Auth'), findsOneWidget);
      expect(find.text('Tambahkan rate limiter'), findsOneWidget);
      expect(find.text('Magang Backend'), findsOneWidget);
      expect(find.text('90 menit'), findsOneWidget);
      expect(find.text('Setiap minggu'), findsOneWidget);
      expect(find.text('backend'), findsOneWidget);

      final mainScroll = find.byType(Scrollable).first;

      // Scroll ke Progres Penyelesaian lalu verifikasi terkunci karena ada checklist
      await tester.scrollUntilVisible(
        find.text('Progres Penyelesaian'),
        200,
        scrollable: mainScroll,
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      // Scroll ke checklist & subtugas (di luar viewport awal ListView)
      await tester.scrollUntilVisible(
        find.text('Tulis unit test'),
        250,
        scrollable: mainScroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tulis unit test'), findsOneWidget);

      // Toggle checklist dan pastikan progres ikut diperbarui menjadi 100%
      await tester.tap(find.text('Tulis unit test'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Setup middleware Redis'),
        250,
        scrollable: mainScroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('Setup middleware Redis'), findsOneWidget);

      // Scroll ke bagian Komentar lalu tambah komentar
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Tulis komentar atau catatan progres...'),
        300,
        scrollable: mainScroll,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Tulis komentar atau catatan progres...'),
        'Sudah ditambahkan pada PR #42',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sudah ditambahkan pada PR #42'), findsOneWidget);
    });
  });

  group('TodayScreen Attention Card & Inbox Sync', () {
    testWidgets('TodayScreen shows Attention Card metrics for overdue, revisi, stagnant, conflict',
        (tester) async {
      final now = DateTime.now();
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'today-t1',
          workspaceId: 'ws-1',
          kind: 'freelance',
          title: 'Perbaiki Header',
          status: const Value('revisi'),
          dueAt: Value(now.subtract(const Duration(days: 2))),
          statusChangedAt: Value(now.subtract(const Duration(days: 7))),
          revisionCount: const Value(1),
        ),
      );
      await db.into(db.localEvents).insert(
        LocalEventsCompanion.insert(
          id: 'ev-c1',
          workspaceId: 'ws-1',
          kind: 'kuliah',
          title: 'Kuliah A',
          startsAt: DateTime(now.year, now.month, now.day, 10, 0),
          endsAt: DateTime(now.year, now.month, now.day, 12, 0),
        ),
      );
      await db.into(db.localEvents).insert(
        LocalEventsCompanion.insert(
          id: 'ev-c2',
          workspaceId: 'ws-1',
          kind: 'intern',
          title: 'Daily Standup',
          startsAt: DateTime(now.year, now.month, now.day, 11, 0),
          endsAt: DateTime(now.year, now.month, now.day, 11, 30),
        ),
      );

      await tester.pumpWidget(wrapMaterial(const TodayScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Perlu Perhatian Segera'), findsOneWidget);
      expect(find.text('Terlambat (1)'), findsOneWidget);
      expect(find.text('Perlu Revisi (1)'), findsOneWidget);
      expect(find.text('Macet > 5 hari (1)'), findsOneWidget);
      expect(find.text('Jadwal Bentrok (1)'), findsOneWidget);
    });

    testWidgets('InboxScreen confirm and reject enqueue SyncService outbox records',
        (tester) async {
      await db.into(db.localTransactions).insert(
        LocalTransactionsCompanion.insert(
          id: 'draft-1',
          workspaceId: 'ws-1',
          accountId: 'acc-1',
          type: 'expense',
          status: 'draft',
          amount: 25000,
          currency: 'IDR',
          merchant: const Value('Kopi Kenangan'),
          occurredAt: DateTime.now(),
        ),
      );
      await db.into(db.localTransactions).insert(
        LocalTransactionsCompanion.insert(
          id: 'draft-2',
          workspaceId: 'ws-1',
          accountId: 'acc-1',
          type: 'expense',
          status: 'draft',
          amount: 15000,
          currency: 'IDR',
          merchant: const Value('Parkir Mall'),
          occurredAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(wrapMaterial(const InboxScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Kopi Kenangan'), findsOneWidget);
      await tester.tap(find.text('Konfirmasi').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tolak').first);
      await tester.pumpAndSettle();

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox.length, 2);
      expect(outbox.any((o) => o.targetTable == 'transactions' && o.action == 'update'), isTrue);
      expect(outbox.any((o) => o.targetTable == 'transactions' && o.action == 'delete'), isTrue);
    });

    testWidgets('TasksScreen mounts Daftar, Papan, and Proyek modes cleanly',
        (tester) async {
      await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'ts-1',
          workspaceId: 'ws-1',
          kind: 'kuliah',
          title: 'Belajar Drift',
          status: const Value('todo'),
        ),
      );

      await tester.pumpWidget(wrapMaterial(const TasksScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Daftar'), findsOneWidget);
      expect(find.text('Papan'), findsOneWidget);
      expect(find.text('Proyek'), findsOneWidget);
      expect(find.text('Belajar Drift'), findsOneWidget);

      await tester.tap(find.text('Papan'));
      await tester.pumpAndSettle();
      expect(find.text('Belum dikerjakan'), findsOneWidget);

      await tester.tap(find.text('Proyek'));
      await tester.pumpAndSettle();
      expect(find.text('Tanpa Proyek'), findsOneWidget);
    });

    testWidgets('HomeScreen opens Workspace Drawer with Saved Views & Global Search',
        (tester) async {
      await db.into(db.localSavedViews).insert(
        LocalSavedViewsCompanion.insert(
          id: 'sv-1',
          workspaceId: 'ws-1',
          name: 'Papan Freelance',
          scope: 'tasks',
          viewMode: const Value('board'),
          isPinned: const Value(true),
        ),
      );

      await tester.pumpWidget(wrapMaterial(const HomeScreen(initialIndex: 1)));
      await tester.pumpAndSettle();

      // Buka Workspace Drawer dari menu AppBar kiri
      await tester.tap(find.byTooltip('Menu Workspace').first);
      await tester.pumpAndSettle();

      expect(find.text('TAMPILAN TERSIMPAN'), findsOneWidget);
      expect(find.text('Papan Freelance'), findsOneWidget);
      expect(find.text('PROYEK AKTIF'), findsOneWidget);
      expect(find.text('Kotak Masuk Transaksi'), findsOneWidget);

      // Tap Saved View langsung mengarahkan ke mode Tugas dengan view aktif
      await tester.tap(find.text('Papan Freelance'));
      await tester.pumpAndSettle();
      expect(find.text('Belum dikerjakan'), findsOneWidget);

      // Buka Command Search dari AppBar kanan
      await tester.tap(find.byTooltip('Cari Global').first);
      await tester.pumpAndSettle();
      expect(find.text('AKSI CEPAT'), findsOneWidget);
      expect(find.text('Buat Tugas Baru'), findsOneWidget);
    });
  });
}
