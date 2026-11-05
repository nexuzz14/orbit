import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
}
