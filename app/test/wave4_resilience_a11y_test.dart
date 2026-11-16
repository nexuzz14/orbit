import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_attention_card.dart';
import 'package:orbit_app/core/widgets/orbit_shell.dart';
import 'package:orbit_app/core/widgets/orbit_view_switcher.dart';
import 'package:orbit_app/features/accounts/accounts_screen.dart';
import 'package:orbit_app/features/home/home_screen.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/planning/planning_screen.dart';
import 'package:orbit_app/features/projects/projects_screen.dart';
import 'package:orbit_app/features/schedule/schedule_screen.dart';
import 'package:orbit_app/features/settings/notification_settings_screen.dart';
import 'package:orbit_app/features/tasks/tasks_screen.dart';
import 'package:orbit_app/features/today/today_screen.dart';
import 'package:orbit_app/features/transactions/transactions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AllowLocalHttpOverrides extends HttpOverrides {}

class _RecordedRequest {
  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final String body;

  _RecordedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });
}

class _FakeSupabaseServer {
  final HttpServer server;
  final List<_RecordedRequest> requests = [];
  bool failMutations = false;
  bool returnDuplicateKeyOnInsert = false;
  Map<String, List<Map<String, dynamic>>> serverTables = {};
  Future<void> Function(String path)? onGetPath;

  _FakeSupabaseServer._(this.server);

  static Future<_FakeSupabaseServer> start() async {
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeSupabaseServer._(srv);
    fake._listen();
    return fake;
  }

  String get baseUrl => 'http://127.0.0.1:${server.port}';

  String _dummyJwt() {
    final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = base64Url.encode(
      utf8.encode(
        '{"sub":"user-w4","aud":"authenticated","role":"authenticated","exp":4102444800}',
      ),
    );
    return '$header.$payload.sig';
  }

  void _listen() {
    server.listen((HttpRequest req) async {
      final rawBody = await utf8.decoder.bind(req).join();
      final headerMap = <String, String>{};
      req.headers.forEach((name, values) {
        headerMap[name.toLowerCase()] = values.join(',');
      });
      requests.add(
        _RecordedRequest(
          method: req.method,
          path: req.uri.path,
          query: req.uri.queryParameters,
          headers: headerMap,
          body: rawBody,
        ),
      );

      req.response.headers.contentType = ContentType.json;

      if (req.uri.path.startsWith('/auth/v1/token')) {
        req.response.statusCode = 200;
        req.response.write(
          jsonEncode({
            'access_token': _dummyJwt(),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'refresh-w4',
            'user': {
              'id': 'user-w4',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'orbit-w4@example.com',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
              'created_at': '2026-11-15T00:00:00Z',
            },
          }),
        );
        await req.response.close();
        return;
      }

      if (req.uri.path.startsWith('/rest/v1/rpc/')) {
        if (failMutations) {
          req.response.statusCode = 500;
          req.response.write(
            jsonEncode({'code': 'XX000', 'message': 'simulated rpc failure'}),
          );
          await req.response.close();
          return;
        }
        final rpcName = req.uri.path.replaceFirst('/rest/v1/rpc/', '');
        if (rpcName == 'fn_agenda') {
          req.response.statusCode = 200;
          req.response.write('[]');
        } else {
          req.response.statusCode = 200;
          req.response.write('{}');
        }
        await req.response.close();
        return;
      }

      final table = req.uri.path.replaceFirst('/rest/v1/', '');

      if (req.method == 'GET') {
        if (onGetPath != null) {
          await onGetPath!(table);
        }
        if (table == 'workspace_members' &&
            req.uri.queryParameters['select'] == 'workspace_id') {
          req.response.statusCode = 200;
          req.response.write(jsonEncode({'workspace_id': 'ws-w4'}));
          await req.response.close();
          return;
        }
        final rows = serverTables[table] ?? const <Map<String, dynamic>>[];
        if (headerMap['accept']?.contains('application/vnd.pgrst.object+json') ==
            true) {
          req.response.statusCode = 200;
          req.response.write(jsonEncode(rows.isEmpty ? null : rows.first));
        } else {
          req.response.statusCode = 200;
          req.response.write(jsonEncode(rows));
        }
        await req.response.close();
        return;
      }

      // Write mutations (POST / PATCH / DELETE)
      if (returnDuplicateKeyOnInsert && req.method == 'POST') {
        req.response.statusCode = 409;
        req.response.write(
          jsonEncode({
            'code': '23505',
            'message': 'duplicate key value violates unique constraint',
          }),
        );
        await req.response.close();
        return;
      }

      if (failMutations) {
        req.response.statusCode = 500;
        req.response.write(
          jsonEncode({'code': 'XX000', 'message': 'simulated network error'}),
        );
        await req.response.close();
        return;
      }

      req.response.statusCode = 201;
      req.response.write(rawBody.isEmpty ? '[]' : rawBody);
      await req.response.close();
    });
  }

  Future<void> close() => server.close(force: true);
}

Future<SupabaseClient> _createSignedInClient(_FakeSupabaseServer server) async {
  final client = SupabaseClient(server.baseUrl, 'dummy-anon-key-w4');
  await client.auth.signInWithPassword(
    email: 'orbit-w4@example.com',
    password: 'password-w4',
  );
  return client;
}

Future<void> _setMobileViewport(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpAndVerifyScreenA11y(
  WidgetTester tester,
  Widget child, {
  required String screenName,
  bool requirePrivacyToggle = false,
}) async {
  final semHandle = tester.ensureSemantics();
  final errors = <FlutterErrorDetails>[];
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  try {
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = prevOnError;
  }

  try {
    expect(
      errors.map((e) => e.toString()).toList(),
      isEmpty,
      reason: '$screenName tidak boleh mengalami overflow/error di 390px',
    );

    // Verifikasi seluruh IconButton yang terlihat punya tooltip & target >= 44x44
    final iconButtons = find.byType(IconButton);
    for (var i = 0; i < iconButtons.evaluate().length; i++) {
      final finder = iconButtons.at(i);
      final widget = tester.widget<IconButton>(finder);
      final size = tester.getSize(finder);
      final tooltip = widget.tooltip?.trim() ?? '';
      expect(
        tooltip.isNotEmpty,
        isTrue,
        reason: '$screenName IconButton[$i] harus memiliki tooltip/Semantics label',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(44.0),
        reason: '$screenName IconButton[$i] width < 44px ($size)',
      );
      expect(
        size.height,
        greaterThanOrEqualTo(44.0),
        reason: '$screenName IconButton[$i] height < 44px ($size)',
      );
      final sem = tester.getSemantics(finder);
      expect(
        sem.label.trim().isNotEmpty ||
            sem.tooltip.trim().isNotEmpty ||
            find.bySemanticsLabel(RegExp(RegExp.escape(tooltip))).evaluate().isNotEmpty,
        isTrue,
        reason: '$screenName IconButton[$i] harus memiliki Semantics label ($tooltip)',
      );
    }

    // Verifikasi seluruh TextButton/OutlinedButton/FilledButton >= 44px tinggi
    for (final btnFinder in [
      find.byType(TextButton),
      find.byType(OutlinedButton),
      find.byType(FilledButton),
    ]) {
      for (var i = 0; i < btnFinder.evaluate().length; i++) {
        final size = tester.getSize(btnFinder.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(44.0),
          reason:
              '$screenName tombol [${btnFinder.description}#$i] height < 44px ($size)',
        );
      }
    }

    // Verifikasi OrbitViewSwitcher / OrbitSavedViewsBar jika ada di layar >= 44px
    final viewSwitchers = find.byType(OrbitViewSwitcher);
    if (viewSwitchers.evaluate().isNotEmpty) {
      for (var i = 0; i < viewSwitchers.evaluate().length; i++) {
        final size = tester.getSize(viewSwitchers.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(44.0),
          reason: '$screenName OrbitViewSwitcher height < 44px ($size)',
        );
      }
    }

    if (requirePrivacyToggle) {
      final toggleFinder = find.byKey(const Key('orbit_privacy_toggle_btn'));
      expect(
        toggleFinder,
        findsOneWidget,
        reason: '$screenName harus menampilkan OrbitPrivacyToggleButton di AppBar',
      );
      final size = tester.getSize(toggleFinder);
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));
    }
  } finally {
    semHandle.dispose();
  }
}

Future<void> _seedSampleDatabase(AppDatabase db) async {
  final now = DateTime.now();
  await db.into(db.localAccounts).insert(
        LocalAccountsCompanion.insert(
          id: 'acc-w4-1',
          workspaceId: 'ws-w4',
          name: 'BCA Utama',
          type: 'bank',
          currency: 'IDR',
          currentBalance: const Value(3500000),
          isLiquid: const Value(true),
        ),
      );
  await db.into(db.localCategories).insert(
        LocalCategoriesCompanion.insert(
          id: 'cat-w4-1',
          workspaceId: 'ws-w4',
          name: 'Makan & Kopi',
          type: 'expense',
        ),
      );
  await db.into(db.localProjects).insert(
        LocalProjectsCompanion.insert(
          id: 'proj-w4-1',
          workspaceId: 'ws-w4',
          kind: 'freelance',
          name: 'Portal Klien Wave 4',
          status: const Value('berjalan'),
        ),
      );
  await db.into(db.localTasks).insert(
        LocalTasksCompanion.insert(
          id: 'task-w4-1',
          workspaceId: 'ws-w4',
          projectId: const Value('proj-w4-1'),
          kind: 'freelance',
          title: 'Audit A11y Wave 4',
          status: const Value('doing'),
          dueAt: Value(now.add(const Duration(hours: 6))),
        ),
      );
  await db.into(db.localEvents).insert(
        LocalEventsCompanion.insert(
          id: 'evt-w4-1',
          workspaceId: 'ws-w4',
          kind: 'intern',
          title: 'Sync Standup Pagi',
          startsAt: now.add(const Duration(hours: 1)),
          endsAt: now.add(const Duration(hours: 2)),
        ),
      );
  await db.into(db.localTransactions).insert(
        LocalTransactionsCompanion.insert(
          id: 'tx-w4-1',
          workspaceId: 'ws-w4',
          accountId: 'acc-w4-1',
          categoryId: const Value('cat-w4-1'),
          type: 'expense',
          status: 'draft',
          draftState: const Value('needs_review'),
          amount: 42000,
          currency: 'IDR',
          source: const Value('receipt'),
          merchant: const Value('Alfamart Kemang'),
          occurredAt: now,
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late SyncService sync;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('id.my.nabilcf.orbit/home_widget'),
      (call) async =>
          call.method == 'consumePendingQuickAddAction' ? null : true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('id.my.nabilcf.orbit/auto_capture'),
      (call) async => call.method == 'isNotificationAccessGranted'
          ? false
          : call.method == 'consumePendingEvents'
              ? <dynamic>[]
              : null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('id.my.nabilcf.orbit/biometric'),
      (call) async => false,
    );
    try {
      await Supabase.initialize(
        url: 'http://127.0.0.1:54399',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.dummy',
      );
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'active_workspace_id': 'ws-w4'});
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    final offlineClient = SupabaseClient('http://127.0.0.1:54399', 'dummy');
    sync = SyncService(db: db, supabase: offlineClient);
    AppDatabase.overrideForTesting(db);
    SyncService.overrideForTesting(sync);
    await PrivacyModeController.instance.setEnabled(false);
    await PrivacyModeController.instance.setHideWidgetBalance(false);
  });

  tearDown(() async {
    SyncService.overrideForTesting(null);
    AppDatabase.overrideForTesting(null);
    await db.close();
  });

  group('1. Ketahanan SyncService & Resolusi Konflik (Wave 4)', () {
    test(
      'push-before-pull mendorong outbox tertunda sebelum tarik server + insert memakai upsert idempoten',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final server = await _FakeSupabaseServer.start();
          final client = await _createSignedInClient(server);
          addTearDown(() async {
            await client.dispose();
            await server.close();
          });

          final onlineSync = SyncService(db: db, supabase: client);

          // Masukkan item outbox saat masih offline
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-offline-insert-1',
                  targetTable: 'tasks',
                  recordId: 'task-offline-1',
                  action: 'insert',
                  payload: jsonEncode({
                    'id': 'task-offline-1',
                    'workspace_id': 'ws-w4',
                    'kind': 'freelance',
                    'title': 'Tugas Offline Pertama',
                  }),
                  createdAt: DateTime.utc(2026, 11, 15, 8, 0),
                  status: const Value('pending'),
                ),
              );

          server.requests.clear();
          await onlineSync.pullAllFromSupabase();

          final pushIndex = server.requests.indexWhere(
            (r) => r.method == 'POST' && r.path == '/rest/v1/tasks',
          );
          final firstPullIndex = server.requests.indexWhere(
            (r) =>
                r.method == 'GET' &&
                (r.path == '/rest/v1/accounts' || r.path == '/rest/v1/tasks'),
          );

          expect(pushIndex, greaterThanOrEqualTo(0));
          expect(firstPullIndex, greaterThan(pushIndex));

          // Verifikasi upsert(onConflict: 'id') dipakai untuk aksi insert dengan id
          final pushReq = server.requests[pushIndex];
          expect(pushReq.query['on_conflict'], 'id');
          expect(pushReq.headers['prefer'], contains('resolution=merge-duplicates'));

          final outboxRow = await (db.select(db.syncOutbox)
                ..where((t) => t.id.equals('op-offline-insert-1')))
              .getSingle();
          expect(outboxRow.status, 'synced');
        }, _AllowLocalHttpOverrides());
      },
    );

    test(
      'getPendingRecordIdsByTable & pullAllFromSupabase melindungi record pending/failed pada 5 tabel lokal',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final server = await _FakeSupabaseServer.start();
          final client = await _createSignedInClient(server);
          addTearDown(() async {
            await client.dispose();
            await server.close();
          });

          final onlineSync = SyncService(db: db, supabase: client);

          // 1. Siapkan 5 baris lokal dengan perubahan offline yang belum tersinkron
          await db.into(db.localProjects).insert(
                LocalProjectsCompanion.insert(
                  id: 'proj-pend-1',
                  workspaceId: 'ws-w4',
                  kind: 'freelance',
                  name: 'Proyek Lokal Belum Push',
                ),
              );
          await db.into(db.localTasks).insert(
                LocalTasksCompanion.insert(
                  id: 'task-pend-1',
                  workspaceId: 'ws-w4',
                  kind: 'freelance',
                  title: 'Tugas Lokal Revisi Offline',
                  status: const Value('revisi'),
                ),
              );
          await db.into(db.localEvents).insert(
                LocalEventsCompanion.insert(
                  id: 'evt-pend-1',
                  workspaceId: 'ws-w4',
                  kind: 'kuliah',
                  title: 'Jadwal Lokal Offline',
                  startsAt: DateTime.utc(2026, 11, 15, 10, 0),
                  endsAt: DateTime.utc(2026, 11, 15, 11, 0),
                ),
              );
          await db.into(db.localTransactions).insert(
                LocalTransactionsCompanion.insert(
                  id: 'tx-pend-1',
                  workspaceId: 'ws-w4',
                  accountId: 'acc-1',
                  type: 'expense',
                  status: 'confirmed',
                  amount: 88000,
                  currency: 'IDR',
                  merchant: const Value('Toko Lokal Offline'),
                  occurredAt: DateTime.utc(2026, 11, 15, 9, 0),
                ),
              );
          await db.into(db.localProjectPayments).insert(
                LocalProjectPaymentsCompanion.insert(
                  id: 'pay-pend-1',
                  workspaceId: 'ws-w4',
                  projectId: 'proj-pend-1',
                  label: 'Termin Lunas Lokal',
                  amount: 1500000,
                  status: const Value('paid'),
                ),
              );

          // 2. Masukkan antrean pending + failed + RPC mapping ke syncOutbox
          final now = DateTime.utc(2026, 11, 15, 10, 0);
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-proj',
                  targetTable: 'projects',
                  recordId: 'proj-pend-1',
                  action: 'update',
                  payload: jsonEncode({'name': 'Proyek Lokal Belum Push'}),
                  createdAt: now,
                  status: const Value('pending'),
                ),
              );
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-task-rpc',
                  targetTable: 'fn_change_task_status',
                  recordId: 'task-pend-1',
                  action: 'rpc',
                  payload: jsonEncode({
                    'p_task_id': 'task-pend-1',
                    'p_to_status': 'revisi',
                  }),
                  createdAt: now,
                  status: const Value('pending'),
                ),
              );
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-evt-failed',
                  targetTable: 'events',
                  recordId: 'evt-pend-1',
                  action: 'update',
                  payload: jsonEncode({'title': 'Jadwal Lokal Offline'}),
                  createdAt: now,
                  status: const Value('failed'),
                  attempts: const Value(5),
                ),
              );
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-tx-rpc',
                  targetTable: 'fn_confirm_draft',
                  recordId: 'tx-pend-1',
                  action: 'rpc',
                  payload: jsonEncode({'p_transaction_id': 'tx-pend-1'}),
                  createdAt: now,
                  status: const Value('pending'),
                ),
              );
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-pay',
                  targetTable: 'project_payments',
                  recordId: 'pay-pend-1',
                  action: 'update',
                  payload: jsonEncode({'status': 'paid'}),
                  createdAt: now,
                  status: const Value('pending'),
                ),
              );

          final pendingMap = await onlineSync.getPendingRecordIdsByTable();
          expect(pendingMap['projects'], contains('proj-pend-1'));
          expect(pendingMap['tasks'], contains('task-pend-1'));
          expect(pendingMap['events'], contains('evt-pend-1'));
          expect(pendingMap['transactions'], contains('tx-pend-1'));
          expect(pendingMap['project_payments'], contains('pay-pend-1'));

          // 3. Server mengembalikan versi lama untuk 5 ID yang masih tertunda + 1 baris baru
          server.failMutations = true;
          server.serverTables = {
            'projects': [
              {
                'id': 'proj-pend-1',
                'workspace_id': 'ws-w4',
                'kind': 'freelance',
                'name': 'VERSI LAMA SERVER',
                'status': 'berjalan',
              },
            ],
            'tasks': [
              {
                'id': 'task-pend-1',
                'workspace_id': 'ws-w4',
                'kind': 'freelance',
                'title': 'TUGAS LAMA SERVER',
                'status': 'todo',
                'priority': 'sedang',
              },
              {
                'id': 'task-server-baru',
                'workspace_id': 'ws-w4',
                'kind': 'pribadi',
                'title': 'Tugas Baru Dari Server',
                'status': 'todo',
                'priority': 'tinggi',
              },
            ],
            'events': [
              {
                'id': 'evt-pend-1',
                'workspace_id': 'ws-w4',
                'kind': 'kuliah',
                'title': 'JADWAL LAMA SERVER',
                'starts_at': '2026-11-15T10:00:00Z',
                'ends_at': '2026-11-15T11:00:00Z',
              },
            ],
            'transactions': [
              {
                'id': 'tx-pend-1',
                'workspace_id': 'ws-w4',
                'account_id': 'acc-1',
                'type': 'expense',
                'status': 'draft',
                'amount': 1000,
                'currency': 'IDR',
                'merchant': 'MERCHANT LAMA SERVER',
                'occurred_at': '2026-11-15T09:00:00Z',
              },
            ],
            'project_payments': [
              {
                'id': 'pay-pend-1',
                'workspace_id': 'ws-w4',
                'project_id': 'proj-pend-1',
                'label': 'TERMIN LAMA SERVER',
                'amount': 100,
                'status': 'pending',
              },
            ],
          };

          await onlineSync.pullAllFromSupabase();

          // Pastikan 5 data lokal tertunda TIDAK tertimpa oleh server!
          final proj = await (db.select(db.localProjects)
                ..where((t) => t.id.equals('proj-pend-1')))
              .getSingle();
          expect(proj.name, 'Proyek Lokal Belum Push');

          final task = await (db.select(db.localTasks)
                ..where((t) => t.id.equals('task-pend-1')))
              .getSingle();
          expect(task.title, 'Tugas Lokal Revisi Offline');
          expect(task.status, 'revisi');

          final evt = await (db.select(db.localEvents)
                ..where((t) => t.id.equals('evt-pend-1')))
              .getSingle();
          expect(evt.title, 'Jadwal Lokal Offline');

          final tx = await (db.select(db.localTransactions)
                ..where((t) => t.id.equals('tx-pend-1')))
              .getSingle();
          expect(tx.status, 'confirmed');
          expect(tx.amount, 88000);
          expect(tx.merchant, 'Toko Lokal Offline');

          final pay = await (db.select(db.localProjectPayments)
                ..where((t) => t.id.equals('pay-pend-1')))
              .getSingle();
          expect(pay.status, 'paid');
          expect(pay.label, 'Termin Lunas Lokal');

          // Data server lain yang tidak konflik tetap masuk dengan normal
          final newServerTask = await (db.select(db.localTasks)
                ..where((t) => t.id.equals('task-server-baru')))
              .getSingleOrNull();
          expect(newServerTask?.title, 'Tugas Baru Dari Server');
        }, _AllowLocalHttpOverrides());
      },
    );

    test(
      '5x gagal menjadi failed, getOutboxHealthSummary akurat, duplicate key idempoten, & retryFailedOutboxOps pulih',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final server = await _FakeSupabaseServer.start();
          final client = await _createSignedInClient(server);
          addTearDown(() async {
            await client.dispose();
            await server.close();
          });

          final onlineSync = SyncService(db: db, supabase: client);
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-retry-1',
                  targetTable: 'tasks',
                  recordId: 'task-retry-1',
                  action: 'insert',
                  payload: jsonEncode({
                    'id': 'task-retry-1',
                    'workspace_id': 'ws-w4',
                    'kind': 'pribadi',
                    'title': 'Tugas Retry',
                  }),
                  createdAt: DateTime.utc(2026, 11, 15, 7, 0),
                  status: const Value('pending'),
                ),
              );

          server.failMutations = true;
          for (var i = 1; i <= 4; i++) {
            await onlineSync.triggerSync();
            final row = await (db.select(db.syncOutbox)
                  ..where((t) => t.id.equals('op-retry-1')))
                .getSingle();
            expect(row.attempts, i);
            expect(row.status, 'pending');
          }

          // Kegagalan ke-5 -> status menjadi 'failed'
          await onlineSync.triggerSync();
          var failedRow = await (db.select(db.syncOutbox)
                ..where((t) => t.id.equals('op-retry-1')))
              .getSingle();
          expect(failedRow.attempts, 5);
          expect(failedRow.status, 'failed');
          expect(failedRow.lastError, isNotNull);

          final healthBefore = await onlineSync.getOutboxHealthSummary();
          expect(healthBefore.failedCount, 1);
          expect(healthBefore.pendingCount, 0);
          expect(healthBefore.hasIssues, isTrue);

          // Pulihkan koneksi & uji retryFailedOutboxOps()
          server.failMutations = false;
          final retried = await onlineSync.retryFailedOutboxOps();
          expect(retried, 1);

          final syncedRow = await (db.select(db.syncOutbox)
                ..where((t) => t.id.equals('op-retry-1')))
              .getSingle();
          expect(syncedRow.status, 'synced');
          expect(syncedRow.lastError, isNull);

          final healthAfter = await onlineSync.getOutboxHealthSummary();
          expect(healthAfter.failedCount, 0);
          expect(healthAfter.syncedCount, 1);
          expect(healthAfter.hasIssues, isFalse);

          // Uji idempotensi saat server mengembalikan duplicate key 23505
          server.returnDuplicateKeyOnInsert = true;
          await db.into(db.syncOutbox).insert(
                SyncOutboxCompanion.insert(
                  id: 'op-dup-1',
                  targetTable: 'tasks',
                  recordId: 'task-dup-1',
                  action: 'insert',
                  payload: jsonEncode({
                    'workspace_id': 'ws-w4',
                    'kind': 'pribadi',
                    'title': 'Tanpa ID tetap aman duplicate',
                  }),
                  createdAt: DateTime.utc(2026, 11, 15, 7, 30),
                  status: const Value('pending'),
                ),
              );
          await onlineSync.triggerSync();
          final dupRow = await (db.select(db.syncOutbox)
                ..where((t) => t.id.equals('op-dup-1')))
              .getSingle();
          expect(dupRow.status, 'synced');
        }, _AllowLocalHttpOverrides());
      },
    );

    test(
      'post-pull triggerSync mengirim operasi baru yang masuk selama proses pull',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final server = await _FakeSupabaseServer.start();
          final client = await _createSignedInClient(server);
          addTearDown(() async {
            await client.dispose();
            await server.close();
          });

          final onlineSync = SyncService(db: db, supabase: client);
          var injected = false;
          server.onGetPath = (table) async {
            if (!injected && table == 'budgets') {
              injected = true;
              await db.into(db.syncOutbox).insert(
                    SyncOutboxCompanion.insert(
                      id: 'op-mid-pull-1',
                      targetTable: 'tasks',
                      recordId: 'task-mid-pull-1',
                      action: 'insert',
                      payload: jsonEncode({
                        'id': 'task-mid-pull-1',
                        'workspace_id': 'ws-w4',
                        'kind': 'pribadi',
                        'title': 'Tugas Masuk Saat Pull',
                      }),
                      createdAt: DateTime.utc(2026, 11, 15, 11, 0),
                      status: const Value('pending'),
                    ),
                  );
            }
          };

          await onlineSync.pullAllFromSupabase();

          final midRow = await (db.select(db.syncOutbox)
                ..where((t) => t.id.equals('op-mid-pull-1')))
              .getSingle();
          expect(midRow.status, 'synced');
        }, _AllowLocalHttpOverrides());
      },
    );
  });

  group('2. Audit Aksesibilitas & Ketahanan Layar Utama v2 (Wave 4)', () {
    testWidgets('TodayScreen lolos audit A11y, touch target >=44px, tooltip, & attention card', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);
      await db.into(db.localTasks).insert(
            LocalTasksCompanion.insert(
              id: 'task-w4-overdue',
              workspaceId: 'ws-w4',
              projectId: const Value('proj-w4-1'),
              kind: 'freelance',
              title: 'Revisi Tagihan Terlambat',
              status: const Value('revisi'),
              dueAt: Value(DateTime.now().subtract(const Duration(days: 1))),
            ),
          );

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const TodayScreen()),
        screenName: 'TodayScreen',
        requirePrivacyToggle: true,
      );

      // Verifikasi Attention Card tidak error & tombol attention >= 44px bila muncul
      expect(find.byType(OrbitAttentionCard), findsWidgets);
    });

    testWidgets('TasksScreen lolos audit A11y, ViewSwitcher >=44px, & semantics', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const TasksScreen()),
        screenName: 'TasksScreen',
      );
    });

    testWidgets('ScheduleScreen lolos audit A11y, tombol AppBar tooltip & >=44px', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const ScheduleScreen()),
        screenName: 'ScheduleScreen',
      );
    });

    testWidgets('TransactionsScreen lolos audit A11y, toggle Mode Privasi semantics, & >=44px', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const TransactionsScreen()),
        screenName: 'TransactionsScreen',
        requirePrivacyToggle: true,
      );

      final toggle = find.byKey(const Key('orbit_privacy_toggle_btn'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(PrivacyModeController.instance.enabled, isTrue);
      expect(find.text(PrivacyModeController.maskedPlaceholder), findsWidgets);
    });

    testWidgets('InboxScreen lolos audit A11y, Konfirmasi Semua & PrivacyToggle >=44px', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const InboxScreen()),
        screenName: 'InboxScreen',
        requirePrivacyToggle: true,
      );
    });

    testWidgets('AccountsScreen lolos audit A11y & PrivacyToggle >=44px', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const AccountsScreen()),
        screenName: 'AccountsScreen',
        requirePrivacyToggle: true,
      );
    });

    testWidgets('ProjectsScreen lolos audit A11y & PrivacyToggle >=44px', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const ProjectsScreen()),
        screenName: 'ProjectsScreen',
        requirePrivacyToggle: true,
      );
    });

    testWidgets('PlanningScreen lolos audit A11y, ViewSwitcher & PrivacyToggle >=44px', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const PlanningScreen()),
        screenName: 'PlanningScreen',
        requirePrivacyToggle: true,
      );
    });

    testWidgets('NotificationSettingsScreen & kartu Kesehatan Antrean Sync lolos audit A11y', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);
      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              id: 'op-ui-failed-1',
              targetTable: 'tasks',
              recordId: 'task-w4-1',
              action: 'update',
              payload: jsonEncode({'title': 'Audit A11y Wave 4'}),
              createdAt: DateTime.utc(2026, 11, 15, 6, 0),
              status: const Value('failed'),
              attempts: const Value(5),
              lastError: const Value('Timeout jaringan'),
            ),
          );

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(
          theme: AppTheme.light(),
          home: const NotificationSettingsScreen(),
        ),
        screenName: 'NotificationSettingsScreen',
      );

      final scrollable = find.byType(Scrollable).first;
      final healthHeader = find.text('Kesehatan Antrean Sinkronisasi');
      await tester.scrollUntilVisible(healthHeader, 300, scrollable: scrollable);
      expect(healthHeader, findsOneWidget);

      final retryBtn = find.byKey(const Key('settings_retry_failed_sync_btn'));
      await tester.scrollUntilVisible(retryBtn, 200, scrollable: scrollable);
      expect(tester.getSize(retryBtn).height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('HomeScreen shell Drawer, Search, & BottomNav lolos audit A11y di 390px', (tester) async {
      await _setMobileViewport(tester);
      await _seedSampleDatabase(db);

      await _pumpAndVerifyScreenA11y(
        tester,
        MaterialApp(theme: AppTheme.light(), home: const HomeScreen()),
        screenName: 'HomeScreen',
      );

      expect(find.byType(OrbitShellMenuButton), findsWidgets);
      expect(find.byType(OrbitShellSearchButton), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      final fabFinder = find.byType(FloatingActionButton);
      final fabWidget = tester.widget<FloatingActionButton>(fabFinder);
      expect(fabWidget.tooltip, isNotNull);
      expect(tester.getSize(fabFinder).width, greaterThanOrEqualTo(44.0));
      expect(tester.getSize(fabFinder).height, greaterThanOrEqualTo(44.0));
    });
  });
}
