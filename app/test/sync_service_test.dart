import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('SyncService fallback workspaceId returns personal-ws or local account workspace', () async {
    final client = SupabaseClient('http://127.0.0.1:54399', 'dummy-anon-key');
    final service = SyncService(db: db, supabase: client);

    final ws1 = await service.getWorkspaceId();
    expect(ws1, 'personal-ws');

    // Tambah akun lokal dengan workspace_id spesifik
    await db.into(db.localAccounts).insert(
      LocalAccountsCompanion.insert(
        id: 'acc-ws-test',
        workspaceId: 'ws-my-team',
        name: 'Bank Mandiri',
        type: 'bank',
        currency: 'IDR',
      ),
    );

    final service2 = SyncService(db: db, supabase: client);
    final ws2 = await service2.getWorkspaceId();
    expect(ws2, 'ws-my-team');
  });

  test('SyncService offline pushRecord queues operation into syncOutbox', () async {
    final client = SupabaseClient('http://127.0.0.1:54399', 'dummy-anon-key');
    final service = SyncService(db: db, supabase: client);

    await service.pushRecord(
      tableName: 'tasks',
      recordId: 'task-123',
      action: 'insert',
      payload: {
        'id': 'task-123',
        'workspace_id': 'personal-ws',
        'title': 'Offline task',
        'kind': 'freelance',
      },
    );

    final outbox = await db.select(db.syncOutbox).get();
    expect(outbox.length, 1);
    expect(outbox.first.targetTable, 'tasks');
    expect(outbox.first.recordId, 'task-123');
    expect(outbox.first.action, 'insert');
    expect(outbox.first.status, 'pending');
  });

  test('Drift schema v3 to v4 upgrade preserves existing tasks and creates v2 tables', () async {
    final upgradedDb = AppDatabase.forExecutor(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
            CREATE TABLE local_tasks (
              id TEXT NOT NULL PRIMARY KEY,
              workspace_id TEXT NOT NULL,
              project_id TEXT NULL,
              kind TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT NULL,
              status TEXT NOT NULL DEFAULT 'todo',
              priority TEXT NOT NULL DEFAULT 'sedang',
              due_at INTEGER NULL,
              due_is_date_only INTEGER NOT NULL DEFAULT 0,
              completed_at INTEGER NULL,
              milestone_payment_id TEXT NULL,
              deleted_at INTEGER NULL
            );
          ''');
          rawDb.execute('''
            CREATE TABLE local_events (
              id TEXT NOT NULL PRIMARY KEY,
              workspace_id TEXT NOT NULL,
              project_id TEXT NULL,
              kind TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT NULL,
              location TEXT NULL,
              starts_at INTEGER NOT NULL,
              ends_at INTEGER NOT NULL,
              all_day INTEGER NOT NULL DEFAULT 0,
              timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
              recurrence TEXT NULL,
              deleted_at INTEGER NULL
            );
          ''');
          rawDb.execute('''
            INSERT INTO local_tasks (id, workspace_id, kind, title, status)
            VALUES ('legacy-task-1', 'ws-1', 'freelance', 'Tugas v3 lama', 'doing');
          ''');
          rawDb.execute('PRAGMA user_version = 3;');
        },
      ),
    );
    addTearDown(() async => upgradedDb.close());

    final tasks = await upgradedDb.select(upgradedDb.localTasks).get();
    expect(tasks.length, 1);
    expect(tasks.first.title, 'Tugas v3 lama');
    expect(tasks.first.progressPercent, 0);
    expect(tasks.first.revisionCount, 0);
    expect(tasks.first.sortOrder, 0);

    await upgradedDb.into(upgradedDb.localSavedViews).insert(
      LocalSavedViewsCompanion.insert(
        id: 'view-1',
        workspaceId: 'ws-1',
        name: 'Kanban Freelance',
        scope: 'tasks',
        viewMode: const Value('board'),
      ),
    );
    final views = await upgradedDb.select(upgradedDb.localSavedViews).get();
    expect(views.length, 1);
    expect(views.first.viewMode, 'board');
  });

  test('SyncService.changeTaskStatus enforces D.2 revisi note, progress, history & outbox', () async {
    final client = SupabaseClient('http://127.0.0.1:54399', 'dummy-anon-key');
    final service = SyncService(db: db, supabase: client);

    await db.into(db.localTasks).insert(
      LocalTasksCompanion.insert(
        id: 'task-d2-1',
        workspaceId: 'ws-d2',
        kind: 'freelance',
        title: 'Desain Landing Page',
        status: const Value('doing'),
        progressPercent: const Value(50),
      ),
    );

    for (var i = 1; i <= 4; i++) {
      await db.into(db.localTaskChecklistItems).insert(
        LocalTaskChecklistItemsCompanion.insert(
          id: 'cl-$i',
          taskId: 'task-d2-1',
          textContent: 'Item $i',
          done: Value(i <= 3),
          sortOrder: Value(i),
        ),
      );
    }

    await expectLater(
      service.changeTaskStatus(taskId: 'task-d2-1', toStatus: 'revisi', note: '   '),
      throwsArgumentError,
    );

    await service.changeTaskStatus(
      taskId: 'task-d2-1',
      toStatus: 'revisi',
      note: 'Perbaiki kontras tombol CTA',
    );

    var task = await (db.select(db.localTasks)..where((t) => t.id.equals('task-d2-1'))).getSingle();
    expect(task.status, 'revisi');
    expect(task.revisionCount, 1);
    expect(task.latestRevisionNote, 'Perbaiki kontras tombol CTA');

    await service.changeTaskStatus(taskId: 'task-d2-1', toStatus: 'done');
    task = await (db.select(db.localTasks)..where((t) => t.id.equals('task-d2-1'))).getSingle();
    expect(task.status, 'done');
    expect(task.progressPercent, 100);
    expect(task.completedAt, isNotNull);

    await service.changeTaskStatus(taskId: 'task-d2-1', toStatus: 'todo');
    task = await (db.select(db.localTasks)..where((t) => t.id.equals('task-d2-1'))).getSingle();
    expect(task.status, 'todo');
    expect(task.progressPercent, 75);
    expect(task.completedAt, isNull);

    final history = await (db.select(db.localTaskStatusHistories)
          ..where((h) => h.taskId.equals('task-d2-1')))
        .get();
    expect(history.length, 3);
    expect(history.first.toStatus, 'revisi');
    expect(history.first.note, 'Perbaiki kontras tombol CTA');

    final outbox = await db.select(db.syncOutbox).get();
    expect(outbox.length, 3);
    expect(outbox.every((o) => o.targetTable == 'fn_change_task_status' && o.action == 'rpc'), isTrue);
  });

  test('v5.3 local collaboration tables support roundtrip persistence', () async {
    final now = DateTime(2026, 11, 15, 10, 0);
    await db.into(db.localComments).insert(
      LocalCommentsCompanion.insert(
        id: 'cmt-1',
        workspaceId: 'ws-1',
        entityType: 'task',
        entityId: 'task-1',
        body: 'Cek ulang lampiran kontrak',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.into(db.localEntityLinks).insert(
      LocalEntityLinksCompanion.insert(
        id: 'lnk-1',
        workspaceId: 'ws-1',
        sourceType: 'task',
        sourceId: 'task-1',
        targetType: 'event',
        targetId: 'ev-1',
        createdAt: now,
      ),
    );
    await db.into(db.localTaskTemplates).insert(
      LocalTaskTemplatesCompanion.insert(
        id: 'tpl-1',
        workspaceId: 'ws-1',
        name: 'Sprint Review Mingguan',
      ),
    );
    await db.into(db.localTaskTimeLogs).insert(
      LocalTaskTimeLogsCompanion.insert(
        id: 'log-1',
        workspaceId: 'ws-1',
        taskId: 'task-1',
        startedAt: now,
        durationSeconds: const Value(1500),
        mode: const Value('pomodoro'),
      ),
    );
    await db.into(db.localAttachments).insert(
      LocalAttachmentsCompanion.insert(
        id: 'att-1',
        workspaceId: 'ws-1',
        ownerTable: 'tasks',
        ownerId: 'task-1',
        storagePath: 'ws-1/tasks/task-1/spec.pdf',
        mime: 'application/pdf',
        size: 102400,
        fileName: const Value('spec.pdf'),
      ),
    );

    expect((await db.select(db.localComments).get()).single.body, 'Cek ulang lampiran kontrak');
    expect((await db.select(db.localEntityLinks).get()).single.targetId, 'ev-1');
    expect((await db.select(db.localTaskTemplates).get()).single.name, 'Sprint Review Mingguan');
    expect((await db.select(db.localTaskTimeLogs).get()).single.durationSeconds, 1500);
    expect((await db.select(db.localAttachments).get()).single.fileName, 'spec.pdf');
  });
}
