import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SyncService {
  final AppDatabase db;
  final SupabaseClient supabase;

  static SyncService? _instance;
  static SyncService get instance =>
      _instance ??= SyncService(db: AppDatabase.shared, supabase: Supabase.instance.client);

  static void overrideForTesting(SyncService? s) {
    _instance = s;
  }

  String? _cachedWorkspaceId;
  String? _cachedWorkspaceName;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncedAtNotifier =
      ValueNotifier<DateTime?>(null);
  final ValueNotifier<DateTime?> lastRealtimeEventAtNotifier =
      ValueNotifier<DateTime?>(null);

  RealtimeChannel? _realtimeChannel;
  String? _realtimeWorkspaceId;
  Timer? _realtimeDebounce;
  Future<void>? _activeTriggerSync;
  bool _triggerSyncFollowup = false;

  bool get isRealtimeSubscribed => _realtimeChannel != null;

  SyncService({required this.db, required this.supabase});

  /// Berlangganan perubahan data Supabase Realtime per workspace dengan debounce aman.
  /// Aman no-op saat offline, belum login, atau berada dalam pengujian headless.
  Future<void> subscribeRealtime({
    Duration debounce = const Duration(milliseconds: 900),
    void Function()? onSynced,
  }) async {
    try {
      if (supabase.auth.currentUser == null) return;
      final wsId = await getWorkspaceId();
      if (wsId == null || wsId.isEmpty) return;

      if (_realtimeChannel != null && _realtimeWorkspaceId == wsId) {
        return;
      }

      await unsubscribeRealtime();

      const tables = [
        'tasks',
        'events',
        'transactions',
        'accounts',
        'projects',
        'budgets',
        'recurring_bills',
      ];

      var channel = supabase.channel('orbit-workspace-$wsId');
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'workspace_id',
        value: wsId,
      );

      for (final table in tables) {
        channel = channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (_) {
            lastRealtimeEventAtNotifier.value = DateTime.now().toUtc();
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(debounce, () async {
              try {
                await pullAllFromSupabase();
                await HomeWidgetBridge.syncFromDatabase(db);
                onSynced?.call();
              } catch (e) {
                debugPrint('SyncService realtime refresh skipped: $e');
              }
            });
          },
        );
      }

      _realtimeChannel = channel;
      _realtimeWorkspaceId = wsId;
      channel.subscribe();
    } catch (e) {
      debugPrint('SyncService.subscribeRealtime safe fallback: $e');
    }
  }

  /// Hentikan langganan Realtime & batalkan timer debounce saat logout/dispose.
  Future<void> unsubscribeRealtime() async {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeWorkspaceId = null;
    if (channel != null) {
      try {
        await supabase.removeChannel(channel);
      } catch (e) {
        try {
          await channel.unsubscribe();
        } catch (_) {}
        debugPrint('SyncService.unsubscribeRealtime ignored: $e');
      }
    }
  }

  void clearCachedWorkspace() {
    _cachedWorkspaceId = null;
    _cachedWorkspaceName = null;
  }

  void _setSyncing(bool value) {
    _isSyncing = value;
    isSyncingNotifier.value = value;
  }

  /// Mengambil nama workspace aktif (online jika tersedia, fallback aman offline)
  Future<String> getWorkspaceName() async {
    if (_cachedWorkspaceName != null && _cachedWorkspaceName!.isNotEmpty) {
      return _cachedWorkspaceName!;
    }
    final wsId = await getWorkspaceId();
    if (supabase.auth.currentUser != null &&
        wsId != null &&
        wsId.isNotEmpty) {
      try {
        final row = await supabase
            .from('workspaces')
            .select('name')
            .eq('id', wsId)
            .maybeSingle();
        if (row != null && row['name'] != null) {
          _cachedWorkspaceName = row['name'] as String;
          return _cachedWorkspaceName!;
        }
      } catch (e) {
        debugPrint('SyncService.getWorkspaceName failed: $e');
      }
    }
    return 'Orbit Workspace';
  }

  /// Memantau jumlah operasi tertunda pada outbox lokal
  Stream<int> watchPendingOutboxCount() {
    return (db.select(db.syncOutbox)
          ..where((t) => t.status.equals('pending')))
        .watch()
        .map((rows) => rows.length);
  }

  static String _canonicalTableForOutbox(String targetTable) {
    switch (targetTable) {
      case 'fn_change_task_status':
        return 'tasks';
      case 'fn_confirm_draft':
        return 'transactions';
      default:
        return targetTable;
    }
  }

  /// Mengambil peta `tableName -> Set<recordId>` untuk operasi outbox yang
  /// masih berstatus `'pending'` (dan `'failed'` jika [includeFailed] aktif)
  /// agar data lokal offline tidak tertimpa saat pull dari server.
  Future<Map<String, Set<String>>> getPendingRecordIdsByTable({
    bool includeFailed = true,
  }) async {
    final statuses = includeFailed ? const ['pending', 'failed'] : const ['pending'];
    final rows = await (db.select(db.syncOutbox)
          ..where((tbl) => tbl.status.isIn(statuses)))
        .get();

    final result = <String, Set<String>>{};
    for (final row in rows) {
      if (row.recordId.isEmpty) continue;
      result.putIfAbsent(row.targetTable, () => <String>{}).add(row.recordId);
      final canonical = _canonicalTableForOutbox(row.targetTable);
      if (canonical != row.targetTable) {
        result.putIfAbsent(canonical, () => <String>{}).add(row.recordId);
      }
    }
    return result;
  }

  /// Mengambil ringkasan kesehatan antrean outbox (`pending`, `failed`, `synced`).
  Future<OutboxHealthSummary> getOutboxHealthSummary() async {
    final rows = await db.select(db.syncOutbox).get();
    var pending = 0;
    var failed = 0;
    var synced = 0;
    DateTime? oldestPending;
    String? latestErr;

    for (final r in rows) {
      if (r.status == 'pending') {
        pending++;
        if (oldestPending == null || r.createdAt.isBefore(oldestPending)) {
          oldestPending = r.createdAt;
        }
      } else if (r.status == 'failed') {
        failed++;
        if (r.lastError != null && r.lastError!.isNotEmpty) {
          latestErr = r.lastError;
        }
      } else if (r.status == 'synced') {
        synced++;
      }
    }

    return OutboxHealthSummary(
      pendingCount: pending,
      failedCount: failed,
      syncedCount: synced,
      oldestPendingAt: oldestPending,
      lastError: latestErr,
    );
  }

  /// Mereset operasi outbox berstatus `'failed'` ke `'pending'` (`attempts = 0`)
  /// lalu memicu sinkronisasi ulang. Mengembalikan jumlah operasi yang diulang.
  Future<int> retryFailedOutboxOps() async {
    final failedRows = await (db.select(db.syncOutbox)
          ..where((tbl) => tbl.status.equals('failed')))
        .get();
    if (failedRows.isEmpty) return 0;

    await (db.update(db.syncOutbox)
          ..where((tbl) => tbl.status.equals('failed')))
        .write(
      const SyncOutboxCompanion(
        status: Value('pending'),
        attempts: Value(0),
        lastError: Value(null),
      ),
    );

    await triggerSync();
    return failedRows.length;
  }

  /// Mengambil workspace_id pengguna aktif
  Future<String?> getWorkspaceId() async {
    if (_cachedWorkspaceId != null && _cachedWorkspaceId!.isNotEmpty) {
      return _cachedWorkspaceId;
    }

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final member = await supabase
            .from('workspace_members')
            .select('workspace_id')
            .limit(1)
            .maybeSingle();

        if (member != null && member['workspace_id'] != null) {
          _cachedWorkspaceId = member['workspace_id'] as String;
          return _cachedWorkspaceId;
        }
      } catch (e) {
        debugPrint('SyncService.getWorkspaceId failed: $e');
      }
    }

    // Cari dari data lokal jika offline
    final localAccount =
        await (db.select(db.localAccounts)..limit(1)).getSingleOrNull();
    if (localAccount != null && localAccount.workspaceId.isNotEmpty) {
      _cachedWorkspaceId = localAccount.workspaceId;
      return _cachedWorkspaceId;
    }

    final localTask =
        await (db.select(db.localTasks)..limit(1)).getSingleOrNull();
    if (localTask != null &&
        localTask.workspaceId.isNotEmpty &&
        localTask.workspaceId != 'ws-local') {
      _cachedWorkspaceId = localTask.workspaceId;
      return _cachedWorkspaceId;
    }

    return _cachedWorkspaceId ?? 'personal-ws';
  }

  /// Menarik semua data dari Supabase ke SQLite lokal (Drift)
  Future<void> pullAllFromSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (_isSyncing) return;

    _setSyncing(true);
    try {
      final wsId = await getWorkspaceId();
      if (wsId == null || wsId.isEmpty) return;

      // 0. Push-before-pull: kirim antrean outbox tertunda sebelum menarik server
      final prePullPendingIds = (await (db.select(db.syncOutbox)
                ..where((tbl) => tbl.status.equals('pending')))
              .get())
          .map((e) => e.id)
          .toSet();
      if (supabase.auth.currentUser != null) {
        await triggerSync();
      }
      final protectedIdsByTable = await getPendingRecordIdsByTable();
      final protectedProjects =
          protectedIdsByTable['projects'] ?? const <String>{};
      final protectedTasks = protectedIdsByTable['tasks'] ?? const <String>{};
      final protectedEvents =
          protectedIdsByTable['events'] ?? const <String>{};
      final protectedTransactions =
          protectedIdsByTable['transactions'] ?? const <String>{};
      final protectedProjectPayments =
          protectedIdsByTable['project_payments'] ?? const <String>{};

      // 1. Tarik Akun Keuangan (accounts)
      try {
        final accountsData = await supabase
            .from('accounts')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in accountsData) {
          await db.into(db.localAccounts).insertOnConflictUpdate(
            LocalAccountsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              name: m['name'] as String,
              type: m['type'] as String,
              currency: m['currency'] as String? ?? 'IDR',
              initialBalance:
                  Value((m['initial_balance'] as num?)?.toDouble() ?? 0.0),
              currentBalance:
                  Value((m['current_balance'] as num?)?.toDouble() ?? 0.0),
              isLiquid: Value(m['is_liquid'] == true),
              visibility: Value(m['visibility'] as String? ?? 'shared'),
              archived: Value(m['archived'] == true),
              sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync accounts error: $e');
      }

      // 2. Tarik Kategori (categories)
      try {
        final categoriesData = await supabase
            .from('categories')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in categoriesData) {
          await db.into(db.localCategories).insertOnConflictUpdate(
            LocalCategoriesCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              name: m['name'] as String,
              type: m['type'] as String,
              parentId: Value(m['parent_id'] as String?),
              systemKey: Value(m['system_key'] as String?),
              archived: Value(m['archived'] == true),
              sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync categories error: $e');
      }

      // 3. Tarik Proyek / Kegiatan (projects)
      try {
        final projectsData = await supabase
            .from('projects')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in projectsData) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty || protectedProjects.contains(id)) continue;
          await db.into(db.localProjects).insertOnConflictUpdate(
            LocalProjectsCompanion.insert(
              id: id,
              workspaceId: m['workspace_id'] as String,
              kind: m['kind'] as String,
              name: m['name'] as String,
              description: Value(m['description'] as String?),
              status: Value(m['status'] as String? ?? 'berjalan'),
              startedOn: Value(m['started_on'] != null
                  ? DateTime.tryParse(m['started_on'].toString())
                  : null),
              deadline: Value(m['deadline'] != null
                  ? DateTime.tryParse(m['deadline'].toString())
                  : null),
              color: Value(m['color'] as String?),
              clientName: Value(m['client_name'] as String?),
              contractValue:
                  Value((m['contract_value'] as num?)?.toDouble()),
              currency: Value(m['currency'] as String?),
              platformFeePercent:
                  Value((m['platform_fee_percent'] as num?)?.toDouble()),
              feeMode: Value(m['fee_mode'] as String?),
              semester: Value((m['semester'] as num?)?.toInt()),
              courseCode: Value(m['course_code'] as String?),
              credits: Value((m['credits'] as num?)?.toInt()),
              stipendAmount: Value((m['stipend_amount'] as num?)?.toDouble()),
              stipendDay: Value((m['stipend_day'] as num?)?.toInt()),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync projects error: $e');
      }

      // 4. Tarik Tugas (tasks) termasuk kolom D.2 & v5.3
      try {
        final tasksData = await supabase
            .from('tasks')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in tasksData) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty || protectedTasks.contains(id)) continue;
          await db.into(db.localTasks).insertOnConflictUpdate(
            LocalTasksCompanion.insert(
              id: id,
              workspaceId: m['workspace_id'] as String,
              projectId: Value(m['project_id'] as String?),
              kind: m['kind'] as String,
              title: m['title'] as String,
              description: Value(m['description'] as String?),
              status: Value(m['status'] as String? ?? 'todo'),
              priority: Value(m['priority'] as String? ?? 'sedang'),
              dueAt: Value(m['due_at'] != null
                  ? DateTime.tryParse(m['due_at'].toString())
                  : null),
              dueIsDateOnly: Value(m['due_is_date_only'] == true),
              completedAt: Value(m['completed_at'] != null
                  ? DateTime.tryParse(m['completed_at'].toString())
                  : null),
              milestonePaymentId: Value(m['milestone_payment_id'] as String?),
              sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
              progressPercent:
                  Value((m['progress_percent'] as num?)?.toInt() ?? 0),
              revisionCount:
                  Value((m['revision_count'] as num?)?.toInt() ?? 0),
              latestRevisionNote: Value(m['latest_revision_note'] as String?),
              statusChangedAt: Value(m['status_changed_at'] != null
                  ? DateTime.tryParse(m['status_changed_at'].toString())
                  : null),
              parentTaskId: Value(m['parent_task_id'] as String?),
              assigneeId: Value(m['assignee_id'] as String?),
              descriptionBlocksJson: Value(m['description_blocks'] != null
                  ? jsonEncode(m['description_blocks'])
                  : null),
              recurrenceRuleJson: Value(m['recurrence_rule'] != null
                  ? jsonEncode(m['recurrence_rule'])
                  : null),
              recurrenceParentId: Value(m['recurrence_parent_id'] as String?),
              tagsJson:
                  Value(m['tags'] is List ? jsonEncode(m['tags']) : null),
              estimateMinutes:
                  Value((m['estimate_minutes'] as num?)?.toInt()),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync tasks error: $e');
      }

      // 5. Tarik Checklist Items (task_checklist_items)
      try {
        final checklistData =
            await supabase.from('task_checklist_items').select('*');

        for (final m in checklistData) {
          await db.into(db.localTaskChecklistItems).insertOnConflictUpdate(
            LocalTaskChecklistItemsCompanion.insert(
              id: m['id'] as String,
              taskId: m['task_id'] as String,
              textContent: m['text'] as String,
              done: Value(m['done'] == true),
              sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync task checklists error: $e');
      }

      // 6. Tarik Jadwal (events)
      try {
        final eventsData = await supabase
            .from('events')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in eventsData) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty || protectedEvents.contains(id)) continue;
          final startsAt = DateTime.tryParse(m['starts_at'].toString()) ??
              DateTime.now();
          final endsAt = DateTime.tryParse(m['ends_at'].toString()) ??
              startsAt.add(const Duration(hours: 1));
          await db.into(db.localEvents).insertOnConflictUpdate(
            LocalEventsCompanion.insert(
              id: id,
              workspaceId: m['workspace_id'] as String,
              projectId: Value(m['project_id'] as String?),
              kind: m['kind'] as String,
              title: m['title'] as String,
              description: Value(m['description'] as String?),
              location: Value(m['location'] as String?),
              startsAt: startsAt,
              endsAt: endsAt,
              allDay: Value(m['all_day'] == true),
              timezone: Value(m['timezone'] as String? ?? 'Asia/Jakarta'),
              recurrence: Value(m['recurrence'] != null
                  ? jsonEncode(m['recurrence'])
                  : null),
              externalProvider: Value(m['external_provider'] as String?),
              externalEventId: Value(m['external_event_id'] as String?),
              externalEtag: Value(m['external_etag'] as String?),
              lastSyncedAt: Value(m['last_synced_at'] != null
                  ? DateTime.tryParse(m['last_synced_at'].toString())
                  : null),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync events error: $e');
      }

      // 7. Tarik Transaksi (transactions)
      try {
        final txData = await supabase
            .from('transactions')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null)
            .order('occurred_at', ascending: false)
            .limit(200);

        for (final m in txData) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty || protectedTransactions.contains(id)) continue;
          final occurredAt =
              DateTime.tryParse(m['occurred_at'].toString()) ?? DateTime.now();
          await db.into(db.localTransactions).insertOnConflictUpdate(
            LocalTransactionsCompanion.insert(
              id: id,
              workspaceId: m['workspace_id'] as String,
              accountId: m['account_id'] as String,
              categoryId: Value(m['category_id'] as String?),
              projectId: Value(m['project_id'] as String?),
              type: m['type'] as String,
              status: m['status'] as String? ?? 'confirmed',
              draftState: Value(m['draft_state'] as String?),
              amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
              currency: m['currency'] as String? ?? 'IDR',
              source: Value(m['source'] as String?),
              merchant: Value(m['merchant'] as String?),
              note: Value(m['note'] as String?),
              occurredAt: occurredAt,
              transferGroupId: Value(m['transfer_group_id'] as String?),
              transferDirection: Value(m['transfer_direction'] as String?),
              origin: Value(m['origin'] as String? ?? 'manual'),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync transactions error: $e');
      }

      // 8. Tarik Milestone Pembayaran (project_payments)
      try {
        final paymentsData = await supabase
            .from('project_payments')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in paymentsData) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty || protectedProjectPayments.contains(id)) continue;
          await db.into(db.localProjectPayments).insertOnConflictUpdate(
            LocalProjectPaymentsCompanion.insert(
              id: id,
              workspaceId: m['workspace_id'] as String,
              projectId: m['project_id'] as String,
              label: m['label'] as String,
              amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
              dueDate: Value(m['due_date'] != null
                  ? DateTime.tryParse(m['due_date'].toString())
                  : null),
              status: Value(m['status'] as String? ?? 'pending'),
              paidAmount:
                  Value((m['paid_amount'] as num?)?.toDouble() ?? 0.0),
              paidAt: Value(m['paid_at'] != null
                  ? DateTime.tryParse(m['paid_at'].toString())
                  : null),
              accountId: Value(m['account_id'] as String?),
              transactionId: Value(m['transaction_id'] as String?),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync project payments error: $e');
      }

      // 9. Tarik Anggaran (budgets)
      try {
        final budgetsData = await supabase
            .from('budgets')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in budgetsData) {
          await db.into(db.localBudgets).insertOnConflictUpdate(
            LocalBudgetsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              categoryId: m['category_id'] as String,
              amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
              period: Value(m['period'] as String? ?? 'monthly'),
              rollover: Value(m['rollover'] == true),
              notifyAtPercent:
                  Value((m['notify_at_percent'] as num?)?.toDouble() ?? 80.0),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync budgets error: $e');
      }

      // 10. Tarik Tagihan Rutin (recurring_bills)
      try {
        final billsData = await supabase
            .from('recurring_bills')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in billsData) {
          await db.into(db.localRecurringBills).insertOnConflictUpdate(
            LocalRecurringBillsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              name: m['name'] as String,
              amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
              categoryId: m['category_id'] as String,
              accountId: m['account_id'] as String,
              scheduleType: Value(m['schedule_type'] as String? ?? 'monthly'),
              scheduleValue:
                  Value((m['schedule_value'] as num?)?.toInt() ?? 1),
              remindDaysBefore: Value(m['remind_days_before'] != null
                  ? jsonEncode(m['remind_days_before'])
                  : '[3, 0]'),
              active: Value(m['active'] != false),
              autoCreateDraft: Value(m['auto_create_draft'] != false),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync recurring bills error: $e');
      }

      // 11. Tarik Target Tabungan (savings_goals)
      try {
        final goalsData = await supabase
            .from('savings_goals')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in goalsData) {
          await db.into(db.localSavingsGoals).insertOnConflictUpdate(
            LocalSavingsGoalsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              name: m['name'] as String,
              targetAmount:
                  (m['target_amount'] as num?)?.toDouble() ?? 0.0,
              currentAmount:
                  Value((m['current_amount'] as num?)?.toDouble() ?? 0.0),
              targetDate: Value(m['target_date'] != null
                  ? DateTime.tryParse(m['target_date'].toString())
                  : null),
              isCompleted: Value(m['is_completed'] == true),
              notes: Value(m['notes'] as String?),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync savings goals error: $e');
      }

      // 12. Tarik Agenda RPC Hari Ini untuk Cache Offline (PRD M10c)
      try {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final agendaData = await supabase.rpc('fn_agenda', params: {
          'p_workspace_id': wsId,
          'p_start_date': todayStr,
          'p_end_date': todayStr,
        });

        if (agendaData is List) {
          for (final item in agendaData) {
            final m = item as Map<String, dynamic>;
            await db.into(db.localAgendaCache).insertOnConflictUpdate(
              LocalAgendaCacheCompanion.insert(
                id: m['id'] as String,
                cachedDate: todayStr,
                workspaceId: wsId,
                itemType: m['item_type'] as String,
                kind: m['kind'] as String,
                title: m['title'] as String,
                description: Value(m['description'] as String?),
                projectId: Value(m['project_id'] as String?),
                projectName: Value(m['project_name'] as String?),
                startsAt: Value(m['starts_at'] != null
                    ? DateTime.tryParse(m['starts_at'].toString())
                    : null),
                endsAt: Value(m['ends_at'] != null
                    ? DateTime.tryParse(m['ends_at'].toString())
                    : null),
                allDay: Value(m['all_day'] == true),
                location: Value(m['location'] as String?),
                status: m['status'] as String? ?? 'todo',
                priority: Value(m['priority'] as String?),
                dueAt: Value(m['due_at'] != null
                    ? DateTime.tryParse(m['due_at'].toString())
                    : null),
                dueIsDateOnly: Value(m['due_is_date_only'] == true),
                isOverdue: Value(m['is_overdue'] == true),
                checklistTotal:
                    Value((m['checklist_total'] as num?)?.toInt() ?? 0),
                checklistDone:
                    Value((m['checklist_done'] as num?)?.toInt() ?? 0),
                eventId: Value(m['event_id'] as String?),
                isRecurring: Value(m['is_recurring'] == true),
                milestonePaymentId:
                    Value(m['milestone_payment_id'] as String?),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Sync agenda cache error: $e');
      }

      // 13. Tarik Riwayat Transisi Status D.2 (task_status_history)
      try {
        final historyData = await supabase
            .from('task_status_history')
            .select('*')
            .eq('workspace_id', wsId)
            .order('created_at', ascending: false)
            .limit(300);

        for (final m in historyData) {
          await db.into(db.localTaskStatusHistories).insertOnConflictUpdate(
            LocalTaskStatusHistoriesCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              taskId: m['task_id'] as String,
              fromStatus: Value(m['from_status'] as String?),
              toStatus: m['to_status'] as String,
              note: Value(m['note'] as String?),
              changedBy: Value(m['changed_by'] as String?),
              createdAt: DateTime.tryParse(m['created_at'].toString()) ??
                  DateTime.now(),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync task status history error: $e');
      }

      // 14. Tarik Komentar (comments)
      try {
        final commentsData = await supabase
            .from('comments')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in commentsData) {
          await db.into(db.localComments).insertOnConflictUpdate(
            LocalCommentsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              entityType: m['entity_type'] as String,
              entityId: m['entity_id'] as String,
              parentCommentId: Value(m['parent_comment_id'] as String?),
              body: m['body'] as String,
              authorId: Value(m['author_id'] as String?),
              createdAt: DateTime.tryParse(m['created_at'].toString()) ??
                  DateTime.now(),
              updatedAt: DateTime.tryParse(m['updated_at'].toString()) ??
                  DateTime.now(),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync comments error: $e');
      }

      // 15. Tarik Tautan Antar Entitas (entity_links)
      try {
        final linksData = await supabase
            .from('entity_links')
            .select('*')
            .eq('workspace_id', wsId);

        for (final m in linksData) {
          await db.into(db.localEntityLinks).insertOnConflictUpdate(
            LocalEntityLinksCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              sourceType: m['source_type'] as String,
              sourceId: m['source_id'] as String,
              targetType: m['target_type'] as String,
              targetId: m['target_id'] as String,
              relationType: Value(m['relation_type'] as String? ?? 'related'),
              createdBy: Value(m['created_by'] as String?),
              createdAt: DateTime.tryParse(m['created_at'].toString()) ??
                  DateTime.now(),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync entity links error: $e');
      }

      // 16. Tarik Tampilan Tersimpan (saved_views)
      try {
        final viewsData = await supabase
            .from('saved_views')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in viewsData) {
          await db.into(db.localSavedViews).insertOnConflictUpdate(
            LocalSavedViewsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              createdBy: Value(m['created_by'] as String?),
              name: m['name'] as String,
              scope: m['scope'] as String,
              viewMode: Value(m['view_mode'] as String? ?? 'list'),
              filterJson: Value(m['filter_json'] != null
                  ? jsonEncode(m['filter_json'])
                  : '{}'),
              sortJson: Value(m['sort_json'] != null
                  ? jsonEncode(m['sort_json'])
                  : '{}'),
              isPinned: Value(m['is_pinned'] == true),
              sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
              createdAt: Value(m['created_at'] != null
                  ? DateTime.tryParse(m['created_at'].toString())
                  : null),
              updatedAt: Value(m['updated_at'] != null
                  ? DateTime.tryParse(m['updated_at'].toString())
                  : null),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync saved views error: $e');
      }

      // 17. Tarik Template Tugas (task_templates)
      try {
        final templatesData = await supabase
            .from('task_templates')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in templatesData) {
          await db.into(db.localTaskTemplates).insertOnConflictUpdate(
            LocalTaskTemplatesCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              createdBy: Value(m['created_by'] as String?),
              name: m['name'] as String,
              kind: Value(m['kind'] as String? ?? 'pribadi'),
              defaultPriority:
                  Value(m['default_priority'] as String? ?? 'sedang'),
              defaultEstimateMinutes:
                  Value((m['default_estimate_minutes'] as num?)?.toInt()),
              checklistJson: Value(m['checklist_json'] != null
                  ? jsonEncode(m['checklist_json'])
                  : '[]'),
              blocksJson: Value(
                  m['blocks_json'] != null ? jsonEncode(m['blocks_json']) : null),
              createdAt: Value(m['created_at'] != null
                  ? DateTime.tryParse(m['created_at'].toString())
                  : null),
              updatedAt: Value(m['updated_at'] != null
                  ? DateTime.tryParse(m['updated_at'].toString())
                  : null),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync task templates error: $e');
      }

      // 18. Tarik Catatan Waktu Tugas (task_time_logs)
      try {
        final logsData = await supabase
            .from('task_time_logs')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null)
            .order('started_at', ascending: false)
            .limit(300);

        for (final m in logsData) {
          await db.into(db.localTaskTimeLogs).insertOnConflictUpdate(
            LocalTaskTimeLogsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              taskId: m['task_id'] as String,
              userId: Value(m['user_id'] as String?),
              startedAt: DateTime.tryParse(m['started_at'].toString()) ??
                  DateTime.now(),
              endedAt: Value(m['ended_at'] != null
                  ? DateTime.tryParse(m['ended_at'].toString())
                  : null),
              durationSeconds:
                  Value((m['duration_seconds'] as num?)?.toInt() ?? 0),
              mode: Value(m['mode'] as String? ?? 'stopwatch'),
              note: Value(m['note'] as String?),
              createdAt: Value(m['created_at'] != null
                  ? DateTime.tryParse(m['created_at'].toString())
                  : null),
              updatedAt: Value(m['updated_at'] != null
                  ? DateTime.tryParse(m['updated_at'].toString())
                  : null),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync task time logs error: $e');
      }

      // 19. Tarik Metadata Lampiran (attachments)
      try {
        final attachmentsData = await supabase
            .from('attachments')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in attachmentsData) {
          await db.into(db.localAttachments).insertOnConflictUpdate(
            LocalAttachmentsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              ownerTable: m['owner_table'] as String,
              ownerId: m['owner_id'] as String,
              storagePath: m['storage_path'] as String,
              mime: m['mime'] as String,
              size: (m['size'] as num?)?.toInt() ?? 1,
              fileName: Value(m['file_name'] as String?),
              createdBy: Value(m['created_by'] as String?),
              createdAt: Value(m['created_at'] != null
                  ? DateTime.tryParse(m['created_at'].toString())
                  : null),
              deletedAt: Value(m['deleted_at'] != null
                  ? DateTime.tryParse(m['deleted_at'].toString())
                  : null),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync attachments error: $e');
      }

      // 19b. Sync Workspace Members (kolaborasi & penanggung jawab)
      try {
        final memberData = await supabase
            .from('workspace_members')
            .select('workspace_id, user_id, role, updated_at')
            .eq('workspace_id', wsId);
        for (final m in memberData) {
          final uid = m['user_id']?.toString() ?? '';
          if (uid.isEmpty) continue;
          String? displayName;
          String? email;
          try {
            final prof = await supabase
                .from('profiles')
                .select('full_name, email')
                .eq('id', uid)
                .maybeSingle();
            if (prof != null) {
              displayName = prof['full_name'] as String?;
              email = prof['email'] as String?;
            }
          } catch (_) {
            // Profiles lookup is optional under strict RLS
          }
          await db.into(db.localWorkspaceMembers).insertOnConflictUpdate(
            LocalWorkspaceMembersCompanion.insert(
              workspaceId: m['workspace_id'] as String,
              userId: uid,
              role: Value(m['role'] as String? ?? 'editor'),
              displayName: Value(displayName),
              email: Value(email),
              updatedAt: Value(
                m['updated_at'] != null
                    ? DateTime.tryParse(m['updated_at'].toString())
                    : null,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync workspace_members error: $e');
      }

      // 19c. Sync Calendar Connections (status Google Calendar)
      try {
        final calData = await supabase
            .from('calendar_connections')
            .select()
            .eq('workspace_id', wsId);
        for (final m in calData) {
          await db.into(db.localCalendarConnections).insertOnConflictUpdate(
            LocalCalendarConnectionsCompanion.insert(
              id: m['id'] as String,
              userId: m['user_id']?.toString() ?? user.id,
              workspaceId: m['workspace_id'] as String,
              provider: Value(m['provider'] as String? ?? 'google'),
              externalCalendarId:
                  Value(m['external_calendar_id'] as String? ?? 'primary'),
              syncDirection:
                  Value(m['sync_direction'] as String? ?? 'two_way'),
              enabled: Value(m['enabled'] as bool? ?? true),
              lastSyncedAt: Value(
                m['last_synced_at'] != null
                    ? DateTime.tryParse(m['last_synced_at'].toString())
                    : null,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Sync calendar_connections error: $e');
      }

      // 20. Kirim antrean outbox baru yang belum tersinkronisasi setelah pull
      final postPullPending = await (db.select(db.syncOutbox)
            ..where((tbl) => tbl.status.equals('pending')))
          .get();
      if (postPullPending.any((op) => !prePullPendingIds.contains(op.id))) {
        await triggerSync();
      }
      lastSyncedAtNotifier.value = DateTime.now();
    } catch (e, st) {
      debugPrint('SyncService.pullAllFromSupabase error: $e\n$st');
    } finally {
      _setSyncing(false);
    }
  }

  /// Simpan sesi pelacakan waktu tugas ke LocalTaskTimeLogs + antrean sinkronisasi.
  Future<String> createTaskTimeLog({
    required String taskId,
    required DateTime startedAt,
    DateTime? endedAt,
    required int durationSeconds,
    required String mode,
    String? note,
  }) async {
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    String? userId;
    try {
      userId = supabase.auth.currentUser?.id;
    } catch (_) {
      userId = null;
    }
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final safeDuration = durationSeconds < 0 ? 0 : durationSeconds;
    final trimmedNote = note?.trim();
    final finalNote = (trimmedNote == null || trimmedNote.isEmpty)
        ? null
        : trimmedNote;

    await db.into(db.localTaskTimeLogs).insertOnConflictUpdate(
      LocalTaskTimeLogsCompanion.insert(
        id: id,
        workspaceId: wsId,
        taskId: taskId,
        userId: Value(userId),
        startedAt: startedAt,
        endedAt: Value(endedAt ?? startedAt.add(Duration(seconds: safeDuration))),
        durationSeconds: Value(safeDuration),
        mode: Value(mode),
        note: Value(finalNote),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await pushRecord(
      tableName: 'task_time_logs',
      recordId: id,
      action: 'insert',
      payload: {
        'id': id,
        'workspace_id': wsId,
        'task_id': taskId,
        if (userId != null) 'user_id': userId,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at':
            (endedAt ?? startedAt.add(Duration(seconds: safeDuration)))
                .toUtc()
                .toIso8601String(),
        'duration_seconds': safeDuration,
        'mode': mode,
        'note': finalNote,
      },
    );
    return id;
  }

  /// Hapus (soft-delete) catatan waktu tugas.
  Future<void> deleteTaskTimeLog(String logId) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.localTaskTimeLogs)..where((t) => t.id.equals(logId)))
        .write(LocalTaskTimeLogsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ));
    await pushRecord(
      tableName: 'task_time_logs',
      recordId: logId,
      action: 'delete',
      payload: {'deleted_at': now.toIso8601String()},
    );
  }

  /// Tandai pembayaran proyek lunas secara offline-first dan antrekan sinkronisasi.
  Future<void> markProjectPaymentPaid({
    required LocalProjectPayment payment,
    String? accountId,
    double fee = 0.0,
  }) async {
    final now = DateTime.now().toUtc();
    final safeFee = fee < 0 ? 0.0 : fee;
    final netAmount =
        (payment.amount - safeFee) < 0 ? 0.0 : (payment.amount - safeFee);

    await (db.update(db.localProjectPayments)
          ..where((p) => p.id.equals(payment.id)))
        .write(
      LocalProjectPaymentsCompanion(
        status: const Value('paid'),
        paidAmount: Value(payment.amount),
        paidAt: Value(now),
        accountId: Value(accountId ?? payment.accountId),
      ),
    );

    if (accountId != null && accountId.isNotEmpty) {
      final txId = const Uuid().v4();
      await db.into(db.localTransactions).insertOnConflictUpdate(
        LocalTransactionsCompanion.insert(
          id: txId,
          workspaceId: payment.workspaceId,
          accountId: accountId,
          projectId: Value(payment.projectId),
          type: 'income',
          status: 'confirmed',
          amount: netAmount,
          currency: 'IDR',
          source: const Value('freelance'),
          merchant: Value(payment.label),
          note: Value('Pelunasan termin: ${payment.label}'),
          occurredAt: now,
          origin: const Value('project_payment'),
        ),
      );
      final acc = await (db.select(db.localAccounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingleOrNull();
      if (acc != null) {
        await (db.update(db.localAccounts)
              ..where((a) => a.id.equals(accountId)))
            .write(LocalAccountsCompanion(
          currentBalance: Value(acc.currentBalance + netAmount),
        ));
      }
      await pushRecord(
        tableName: 'transactions',
        recordId: txId,
        action: 'insert',
        payload: {
          'id': txId,
          'workspace_id': payment.workspaceId,
          'account_id': accountId,
          'project_id': payment.projectId,
          'type': 'income',
          'status': 'confirmed',
          'amount': netAmount,
          'currency': 'IDR',
          'source': 'freelance',
          'merchant': payment.label,
          'note': 'Pelunasan termin: ${payment.label}',
          'occurred_at': now.toIso8601String(),
          'origin': 'project_payment',
        },
      );
    }

    await pushRecord(
      tableName: 'project_payments',
      recordId: payment.id,
      action: 'update',
      payload: {
        'id': payment.id,
        'workspace_id': payment.workspaceId,
        'project_id': payment.projectId,
        'label': payment.label,
        'amount': payment.amount,
        'due_date': payment.dueDate?.toIso8601String(),
        'status': 'paid',
        'paid_amount': payment.amount,
        'paid_at': now.toIso8601String(),
        if (accountId != null) 'account_id': accountId,
      },
    );
  }

  /// Ambil daftar undangan workspace tertunda saat online (offline return list kosong).
  Future<List<Map<String, dynamic>>> fetchWorkspaceInvites() async {
    try {
      if (supabase.auth.currentUser == null) return [];
      final wsId = await getWorkspaceId();
      if (wsId == null || wsId.isEmpty) return [];
      final data = await supabase
          .from('workspace_invites')
          .select('id, email, role, expires_at, accepted_at, revoked_at, created_at')
          .eq('workspace_id', wsId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('fetchWorkspaceInvites error: $e');
      return [];
    }
  }

  /// Simpan konfigurasi koneksi kalender eksternal lokal + outbox.
  Future<void> saveCalendarConnection({
    String provider = 'google',
    String externalCalendarId = 'primary',
    String syncDirection = 'two_way',
    bool enabled = true,
  }) async {
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    String userId = 'local_user';
    try {
      userId = supabase.auth.currentUser?.id ?? 'local_user';
    } catch (_) {}
    final existing = await (db.select(db.localCalendarConnections)
          ..where((c) =>
              c.workspaceId.equals(wsId) & c.provider.equals(provider)))
        .getSingleOrNull();
    final id = existing?.id ?? const Uuid().v4();
    final now = DateTime.now().toUtc();

    await db.into(db.localCalendarConnections).insertOnConflictUpdate(
      LocalCalendarConnectionsCompanion.insert(
        id: id,
        userId: userId,
        workspaceId: wsId,
        provider: Value(provider),
        externalCalendarId: Value(externalCalendarId),
        syncDirection: Value(syncDirection),
        enabled: Value(enabled),
        lastSyncedAt: Value(now),
      ),
    );

    await pushRecord(
      tableName: 'calendar_connections',
      recordId: id,
      action: existing == null ? 'insert' : 'update',
      payload: {
        'id': id,
        'user_id': userId,
        'workspace_id': wsId,
        'provider': provider,
        'external_calendar_id': externalCalendarId,
        'sync_direction': syncDirection,
        'enabled': enabled,
        'last_synced_at': now.toIso8601String(),
      },
    );
  }

  @visibleForTesting
  static bool isIdempotentDuplicateError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '23505') return true;
      final msg = error.message.toLowerCase();
      if (msg.contains('duplicate key') || msg.contains('already exists')) {
        return true;
      }
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('23505') || msg.contains('duplicate key');
  }

  Future<void> _upsertOrInsertIdempotent(
    String targetTable,
    Map<String, dynamic> payload,
  ) async {
    try {
      if (payload.containsKey('id') && payload['id'] != null) {
        await supabase.from(targetTable).upsert(payload, onConflict: 'id');
      } else {
        await supabase.from(targetTable).insert(payload);
      }
    } on PostgrestException catch (e) {
      if (isIdempotentDuplicateError(e)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _executeRemoteOp({
    required String targetTable,
    required String recordId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    if (action == 'rpc') {
      await supabase.rpc(targetTable, params: payload);
      return;
    }
    if (action == 'insert') {
      await _upsertOrInsertIdempotent(targetTable, payload);
      return;
    }
    if (action == 'update') {
      await supabase.from(targetTable).update(payload).eq('id', recordId);
      return;
    }
    if (action == 'delete') {
      if (targetTable == 'transactions') {
        await supabase.rpc(
          'fn_delete_transaction',
          params: {'p_transaction_id': recordId},
        );
      } else {
        await supabase.from(targetTable).delete().eq('id', recordId);
      }
      return;
    }
    throw UnsupportedError('Aksi sinkronisasi tidak dikenal: $action');
  }

  /// Menambah atau memperbarui rekaman lokal dan mengirimnya ke Supabase jika online,
  /// atau memasukkannya ke antrean outbox jika offline.
  Future<void> pushRecord({
    required String tableName,
    required String recordId,
    required String action, // insert, update, delete, rpc
    required Map<String, dynamic> payload,
  }) async {
    if (supabase.auth.currentUser != null) {
      try {
        await _executeRemoteOp(
          targetTable: tableName,
          recordId: recordId,
          action: action,
          payload: payload,
        );
        return;
      } catch (e) {
        debugPrint('Direct push to $tableName failed, enqueuing to outbox: $e');
      }
    }

    // Masukkan ke outbox jika offline atau gagal kirim langsung
    await enqueueOperation(
      tableName: tableName,
      recordId: recordId,
      action: action,
      payload: payload,
    );
  }

  /// Menambahkan operasi ke outbox lokal (idempoten)
  Future<String> enqueueOperation({
    required String tableName,
    required String recordId,
    required String action, // insert, update, delete, rpc
    required Map<String, dynamic> payload,
  }) async {
    final clientGeneratedId = const Uuid().v4();

    await db.into(db.syncOutbox).insert(
      SyncOutboxCompanion.insert(
        id: clientGeneratedId,
        targetTable: tableName,
        recordId: recordId,
        action: action,
        payload: jsonEncode(payload),
        createdAt: DateTime.now(),
        status: const Value('pending'),
      ),
    );

    // Memicu sinkronisasi di latar belakang jika online
    triggerSync();
    return clientGeneratedId;
  }

  /// Memproses antrean outbox ke Supabase secara berurutan dan idempoten.
  Future<void> triggerSync() {
    if (supabase.auth.currentUser == null) return Future.value();
    final existing = _activeTriggerSync;
    if (existing != null) {
      _triggerSyncFollowup = true;
      return existing;
    }
    final future = _runTriggerSyncLoop().whenComplete(() {
      _activeTriggerSync = null;
      _triggerSyncFollowup = false;
    });
    _activeTriggerSync = future;
    return future;
  }

  Future<void> _runTriggerSyncLoop() async {
    await _runTriggerSyncOnce();
    if (_triggerSyncFollowup) {
      _triggerSyncFollowup = false;
      await _runTriggerSyncOnce();
    }
  }

  Future<void> _runTriggerSyncOnce() async {
    if (supabase.auth.currentUser == null) return;

    final pendingOps = await (db.select(db.syncOutbox)
          ..where((tbl) => tbl.status.equals('pending'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();

    for (final op in pendingOps) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        await _executeRemoteOp(
          targetTable: op.targetTable,
          recordId: op.recordId,
          action: op.action,
          payload: payload,
        );

        // Tandai sukses sinkronisasi
        await (db.update(db.syncOutbox)..where((tbl) => tbl.id.equals(op.id)))
            .write(
          const SyncOutboxCompanion(
            status: Value('synced'),
            lastError: Value(null),
          ),
        );
      } catch (e) {
        debugPrint('Sync failed for op ${op.id}: $e');
        final nextAttempts = op.attempts + 1;
        await (db.update(db.syncOutbox)..where((tbl) => tbl.id.equals(op.id)))
            .write(
          SyncOutboxCompanion(
            attempts: Value(nextAttempts),
            lastError: Value(e.toString()),
            status: Value(nextAttempts >= 5 ? 'failed' : 'pending'),
          ),
        );
      }
    }
  }

  /// Transisi status tugas D.2 (offline-first + RPC fn_change_task_status saat online)
  Future<void> changeTaskStatus({
    required String taskId,
    required String toStatus,
    String? note,
    int? sortOrder,
  }) async {
    final task = await (db.select(db.localTasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    if (task == null) {
      throw StateError('Tugas tidak ditemukan di penyimpanan lokal.');
    }

    final cleanNote =
        (note != null && note.trim().isNotEmpty) ? note.trim() : null;
    final oldStatus = task.status;
    if (toStatus == 'revisi' && oldStatus != 'revisi' && cleanNote == null) {
      throw ArgumentError(
          'Catatan alasan wajib diisi saat memindahkan tugas ke Revisi.');
    }

    int nextProgress = task.progressPercent;
    DateTime? nextCompletedAt;
    if (toStatus == 'done') {
      nextProgress = 100;
      nextCompletedAt = task.completedAt ?? DateTime.now();
    } else {
      nextCompletedAt = null;
      if (oldStatus == 'done') {
        final checklists = await (db.select(db.localTaskChecklistItems)
              ..where((c) => c.taskId.equals(taskId)))
            .get();
        if (checklists.isNotEmpty) {
          final doneCount = checklists.where((c) => c.done).length;
          nextProgress = ((doneCount * 100) / checklists.length).round();
        } else {
          final subs = await (db.select(db.localTasks)
                ..where((s) =>
                    s.parentTaskId.equals(taskId) & s.deletedAt.isNull()))
              .get();
          if (subs.isNotEmpty) {
            final doneCount = subs.where((s) => s.status == 'done').length;
            nextProgress = ((doneCount * 100) / subs.length).round();
          } else {
            nextProgress = 0;
          }
        }
      }
    }

    final nextRevisionCount = (toStatus == 'revisi' && oldStatus != 'revisi')
        ? task.revisionCount + 1
        : task.revisionCount;
    final nextRevisionNote = (toStatus == 'revisi' && cleanNote != null)
        ? cleanNote
        : task.latestRevisionNote;
    final now = DateTime.now();

    await db.transaction(() async {
      await (db.update(db.localTasks)..where((t) => t.id.equals(taskId))).write(
        LocalTasksCompanion(
          status: Value(toStatus),
          completedAt: Value(nextCompletedAt),
          progressPercent: Value(nextProgress),
          revisionCount: Value(nextRevisionCount),
          latestRevisionNote: Value(nextRevisionNote),
          sortOrder: Value(sortOrder ?? task.sortOrder),
          statusChangedAt:
              toStatus != oldStatus ? Value(now) : Value(task.statusChangedAt),
        ),
      );

      if (toStatus != oldStatus) {
        await db.into(db.localTaskStatusHistories).insert(
          LocalTaskStatusHistoriesCompanion.insert(
            id: const Uuid().v4(),
            workspaceId: task.workspaceId,
            taskId: taskId,
            fromStatus: Value(oldStatus),
            toStatus: toStatus,
            note: Value(cleanNote),
            changedBy: Value(supabase.auth.currentUser?.id),
            createdAt: now,
          ),
        );
      }
    });

    await pushRecord(
      tableName: 'fn_change_task_status',
      recordId: taskId,
      action: 'rpc',
      payload: {
        'p_task_id': taskId,
        'p_to_status': toStatus,
        'p_note': cleanNote,
        if (sortOrder != null) 'p_sort_order': sortOrder,
      },
    );

    if (task.parentTaskId != null && task.parentTaskId!.isNotEmpty) {
      await recomputeTaskProgress(task.parentTaskId!);
    }
  }

  /// Menghitung ulang progress otomatis tugas dari checklist atau subtugas
  Future<int> recomputeTaskProgress(String taskId) async {
    final task = await (db.select(db.localTasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    if (task == null) return 0;

    final checklists = await (db.select(db.localTaskChecklistItems)
          ..where((c) => c.taskId.equals(taskId)))
        .get();

    int? computed;
    if (checklists.isNotEmpty) {
      final doneCount = checklists.where((c) => c.done).length;
      computed = ((doneCount * 100) / checklists.length).round();
    } else {
      final subs = await (db.select(db.localTasks)
            ..where(
                (s) => s.parentTaskId.equals(taskId) & s.deletedAt.isNull()))
          .get();
      if (subs.isNotEmpty) {
        final doneCount = subs.where((s) => s.status == 'done').length;
        computed = ((doneCount * 100) / subs.length).round();
      }
    }

    final nextProgress = computed ?? task.progressPercent;
    if (nextProgress != task.progressPercent) {
      await (db.update(db.localTasks)..where((t) => t.id.equals(taskId))).write(
        LocalTasksCompanion(progressPercent: Value(nextProgress)),
      );
      await pushRecord(
        tableName: 'tasks',
        recordId: taskId,
        action: 'update',
        payload: {'progress_percent': nextProgress},
      );
    }

    if (task.parentTaskId != null && task.parentTaskId!.isNotEmpty) {
      await recomputeTaskProgress(task.parentTaskId!);
    }
    return nextProgress;
  }

  /// Memperbarui progress manual (ketika tidak terkunci checklist/subtugas)
  Future<void> updateTaskProgressManual(String taskId, int percent) async {
    final clamped = percent.clamp(0, 100);
    await (db.update(db.localTasks)..where((t) => t.id.equals(taskId))).write(
      LocalTasksCompanion(progressPercent: Value(clamped)),
    );
    await pushRecord(
      tableName: 'tasks',
      recordId: taskId,
      action: 'update',
      payload: {'progress_percent': clamped},
    );
  }

  /// Membuat tugas atau subtugas baru beserta item checklist opsional (offline-first)
  Future<String> createTask({
    required String title,
    required String kind,
    String priority = 'sedang',
    String status = 'todo',
    String? projectId,
    String? parentTaskId,
    String? description,
    List<Map<String, dynamic>>? descriptionBlocks,
    DateTime? dueAt,
    bool dueIsDateOnly = false,
    int? estimateMinutes,
    Map<String, dynamic>? recurrenceRule,
    List<String> tags = const [],
    List<String> initialChecklist = const [],
  }) async {
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    final taskId = const Uuid().v4();
    final now = DateTime.now();

    final blocksJson =
        descriptionBlocks != null ? jsonEncode(descriptionBlocks) : null;
    final recJson = recurrenceRule != null ? jsonEncode(recurrenceRule) : null;
    final tagsEncoded = tags.isNotEmpty ? jsonEncode(tags) : null;

    await db.into(db.localTasks).insert(
      LocalTasksCompanion.insert(
        id: taskId,
        workspaceId: wsId,
        projectId: Value(projectId),
        kind: kind,
        title: title.trim(),
        description: Value(
          (description != null && description.trim().isNotEmpty)
              ? description.trim()
              : null,
        ),
        status: Value(status),
        priority: Value(priority),
        dueAt: Value(dueAt),
        dueIsDateOnly: Value(dueIsDateOnly),
        completedAt: Value(status == 'done' ? now : null),
        progressPercent: Value(status == 'done' ? 100 : 0),
        statusChangedAt: Value(now),
        parentTaskId: Value(parentTaskId),
        descriptionBlocksJson: Value(blocksJson),
        recurrenceRuleJson: Value(recJson),
        tagsJson: Value(tagsEncoded),
        estimateMinutes: Value(estimateMinutes),
      ),
    );

    await pushRecord(
      tableName: 'tasks',
      recordId: taskId,
      action: 'insert',
      payload: {
        'id': taskId,
        'workspace_id': wsId,
        if (projectId != null) 'project_id': projectId,
        if (parentTaskId != null) 'parent_task_id': parentTaskId,
        'kind': kind,
        'title': title.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'status': status,
        'priority': priority,
        if (dueAt != null) 'due_at': dueAt.toUtc().toIso8601String(),
        'due_is_date_only': dueIsDateOnly,
        if (status == 'done') 'completed_at': now.toUtc().toIso8601String(),
        'progress_percent': status == 'done' ? 100 : 0,
        if (estimateMinutes != null && estimateMinutes > 0)
          'estimate_minutes': estimateMinutes,
        if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
        if (descriptionBlocks != null) 'description_blocks': descriptionBlocks,
        if (tags.isNotEmpty) 'tags': tags,
      },
    );

    for (int i = 0; i < initialChecklist.length; i++) {
      final textVal = initialChecklist[i].trim();
      if (textVal.isEmpty) continue;
      await addChecklistItem(
        taskId: taskId,
        text: textVal,
        sortOrder: i,
        skipRecompute: true,
      );
    }
    if (initialChecklist.isNotEmpty) {
      await recomputeTaskProgress(taskId);
    }
    if (parentTaskId != null && parentTaskId.isNotEmpty) {
      await recomputeTaskProgress(parentTaskId);
    }

    return taskId;
  }

  /// Memperbarui atribut tugas dan mencatat ke outbox sinkronisasi
  Future<void> updateTaskFields({
    required String taskId,
    required LocalTasksCompanion companion,
    required Map<String, dynamic> remotePayload,
  }) async {
    await (db.update(db.localTasks)..where((t) => t.id.equals(taskId)))
        .write(companion);
    if (remotePayload.isNotEmpty) {
      await pushRecord(
        tableName: 'tasks',
        recordId: taskId,
        action: 'update',
        payload: remotePayload,
      );
    }
  }

  /// Menghapus tugas secara soft-delete
  Future<void> deleteTask(String taskId) async {
    final task = await (db.select(db.localTasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    final now = DateTime.now();
    await (db.update(db.localTasks)..where((t) => t.id.equals(taskId))).write(
      LocalTasksCompanion(deletedAt: Value(now)),
    );
    await pushRecord(
      tableName: 'tasks',
      recordId: taskId,
      action: 'update',
      payload: {'deleted_at': now.toUtc().toIso8601String()},
    );
    if (task?.parentTaskId != null && task!.parentTaskId!.isNotEmpty) {
      await recomputeTaskProgress(task.parentTaskId!);
    }
  }

  /// Menambah item checklist tugas & hitung ulang progress
  Future<String> addChecklistItem({
    required String taskId,
    required String text,
    int? sortOrder,
    bool skipRecompute = false,
  }) async {
    final itemId = const Uuid().v4();
    final cleanText = text.trim();
    final resolvedOrder = sortOrder ??
        (await (db.select(db.localTaskChecklistItems)
                  ..where((c) => c.taskId.equals(taskId)))
                .get())
            .length;
    await db.into(db.localTaskChecklistItems).insert(
      LocalTaskChecklistItemsCompanion.insert(
        id: itemId,
        taskId: taskId,
        textContent: cleanText,
        done: const Value(false),
        sortOrder: Value(resolvedOrder),
      ),
    );
    await pushRecord(
      tableName: 'task_checklist_items',
      recordId: itemId,
      action: 'insert',
      payload: {
        'id': itemId,
        'task_id': taskId,
        'text': cleanText,
        'done': false,
        'sort_order': resolvedOrder,
      },
    );
    if (!skipRecompute) {
      await recomputeTaskProgress(taskId);
    }
    return itemId;
  }

  /// Toggle selesai pada item checklist & hitung ulang progress
  Future<void> toggleChecklistItem({
    required String itemId,
    required bool done,
  }) async {
    final item = await (db.select(db.localTaskChecklistItems)
          ..where((c) => c.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    await (db.update(db.localTaskChecklistItems)
          ..where((c) => c.id.equals(itemId)))
        .write(LocalTaskChecklistItemsCompanion(done: Value(done)));
    await pushRecord(
      tableName: 'task_checklist_items',
      recordId: itemId,
      action: 'update',
      payload: {'done': done},
    );
    await recomputeTaskProgress(item.taskId);
  }

  /// Hapus item checklist & hitung ulang progress
  Future<void> deleteChecklistItem(String itemId) async {
    final item = await (db.select(db.localTaskChecklistItems)
          ..where((c) => c.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    await (db.delete(db.localTaskChecklistItems)
          ..where((c) => c.id.equals(itemId)))
        .go();
    await pushRecord(
      tableName: 'task_checklist_items',
      recordId: itemId,
      action: 'delete',
      payload: {'id': itemId},
    );
    await recomputeTaskProgress(item.taskId);
  }

  /// Menambah komentar pada entitas (task/project/event/transaction/bill)
  Future<String> addComment({
    required String entityType,
    required String entityId,
    required String body,
    String? parentCommentId,
  }) async {
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    final id = const Uuid().v4();
    final now = DateTime.now();
    final cleanBody = body.trim();
    final authorId = supabase.auth.currentUser?.id;

    await db.into(db.localComments).insert(
      LocalCommentsCompanion.insert(
        id: id,
        workspaceId: wsId,
        entityType: entityType,
        entityId: entityId,
        parentCommentId: Value(parentCommentId),
        body: cleanBody,
        authorId: Value(authorId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pushRecord(
      tableName: 'comments',
      recordId: id,
      action: 'insert',
      payload: {
        'id': id,
        'workspace_id': wsId,
        'entity_type': entityType,
        'entity_id': entityId,
        if (parentCommentId != null) 'parent_comment_id': parentCommentId,
        'body': cleanBody,
        if (authorId != null) 'author_id': authorId,
      },
    );
    return id;
  }

  /// Soft-delete komentar lokal & sinkronkan ke Supabase
  Future<void> deleteComment(String commentId) async {
    final now = DateTime.now();
    await (db.update(db.localComments)..where((c) => c.id.equals(commentId)))
        .write(LocalCommentsCompanion(deletedAt: Value(now)));
    await pushRecord(
      tableName: 'comments',
      recordId: commentId,
      action: 'update',
      payload: {'deleted_at': now.toUtc().toIso8601String()},
    );
  }

  /// Menautkan entitas terkait (relasi Notion/Jira)
  Future<String> addEntityLink({
    required String sourceType,
    required String sourceId,
    required String targetType,
    required String targetId,
    String relationType = 'related',
  }) async {
    if (sourceType == targetType && sourceId == targetId) {
      throw ArgumentError('Entitas tidak dapat ditautkan ke dirinya sendiri.');
    }
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    final id = const Uuid().v4();
    final now = DateTime.now();
    final createdBy = supabase.auth.currentUser?.id;

    await db.into(db.localEntityLinks).insert(
      LocalEntityLinksCompanion.insert(
        id: id,
        workspaceId: wsId,
        sourceType: sourceType,
        sourceId: sourceId,
        targetType: targetType,
        targetId: targetId,
        relationType: Value(relationType),
        createdBy: Value(createdBy),
        createdAt: now,
      ),
    );
    await pushRecord(
      tableName: 'entity_links',
      recordId: id,
      action: 'insert',
      payload: {
        'id': id,
        'workspace_id': wsId,
        'source_type': sourceType,
        'source_id': sourceId,
        'target_type': targetType,
        'target_id': targetId,
        'relation_type': relationType,
        if (createdBy != null) 'created_by': createdBy,
      },
    );
    return id;
  }

  /// Menghapus tautan entitas
  Future<void> deleteEntityLink(String linkId) async {
    await (db.delete(db.localEntityLinks)..where((l) => l.id.equals(linkId)))
        .go();
    await pushRecord(
      tableName: 'entity_links',
      recordId: linkId,
      action: 'delete',
      payload: {'id': linkId},
    );
  }

  /// Menyimpan Tampilan Tersimpan (Saved View)
  Future<String> saveSavedView({
    required String name,
    String scope = 'tasks',
    required String viewMode,
    Map<String, dynamic> filters = const {},
    Map<String, dynamic> sort = const {},
    bool isPinned = false,
  }) async {
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    final id = const Uuid().v4();
    final now = DateTime.now();
    final createdBy = supabase.auth.currentUser?.id;
    final cleanName = name.trim();
    final filterStr = jsonEncode(filters);
    final sortStr = jsonEncode(sort);

    await db.into(db.localSavedViews).insert(
      LocalSavedViewsCompanion.insert(
        id: id,
        workspaceId: wsId,
        createdBy: Value(createdBy),
        name: cleanName,
        scope: scope,
        viewMode: Value(viewMode),
        filterJson: Value(filterStr),
        sortJson: Value(sortStr),
        isPinned: Value(isPinned),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await pushRecord(
      tableName: 'saved_views',
      recordId: id,
      action: 'insert',
      payload: {
        'id': id,
        'workspace_id': wsId,
        if (createdBy != null) 'created_by': createdBy,
        'name': cleanName,
        'scope': scope,
        'view_mode': viewMode,
        'filter_json': filters,
        'sort_json': sort,
        'is_pinned': isPinned,
      },
    );
    return id;
  }

  /// Menyematkan / melepas sematan Saved View ke Workspace Drawer
  Future<void> togglePinSavedView(String viewId, bool isPinned) async {
    await (db.update(db.localSavedViews)..where((v) => v.id.equals(viewId)))
        .write(LocalSavedViewsCompanion(
      isPinned: Value(isPinned),
      updatedAt: Value(DateTime.now()),
    ));
    await pushRecord(
      tableName: 'saved_views',
      recordId: viewId,
      action: 'update',
      payload: {'is_pinned': isPinned},
    );
  }

  /// Menghapus Saved View secara soft-delete
  Future<void> deleteSavedView(String viewId) async {
    final now = DateTime.now();
    await (db.update(db.localSavedViews)..where((v) => v.id.equals(viewId)))
        .write(LocalSavedViewsCompanion(deletedAt: Value(now)));
    await pushRecord(
      tableName: 'saved_views',
      recordId: viewId,
      action: 'update',
      payload: {'deleted_at': now.toUtc().toIso8601String()},
    );
  }

  /// Menyimpan tugas sebagai template yang dapat dipakai ulang
  Future<String> saveTaskAsTemplate({
    required String name,
    required String kind,
    String defaultPriority = 'sedang',
    int? defaultEstimateMinutes,
    List<String> checklistTexts = const [],
    String? blocksJson,
  }) async {
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    final id = const Uuid().v4();
    final now = DateTime.now();
    final createdBy = supabase.auth.currentUser?.id;
    final checklistJsonStr = jsonEncode(checklistTexts);

    await db.into(db.localTaskTemplates).insert(
      LocalTaskTemplatesCompanion.insert(
        id: id,
        workspaceId: wsId,
        createdBy: Value(createdBy),
        name: name.trim(),
        kind: Value(kind),
        defaultPriority: Value(defaultPriority),
        defaultEstimateMinutes: Value(defaultEstimateMinutes),
        checklistJson: Value(checklistJsonStr),
        blocksJson: Value(blocksJson),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await pushRecord(
      tableName: 'task_templates',
      recordId: id,
      action: 'insert',
      payload: {
        'id': id,
        'workspace_id': wsId,
        if (createdBy != null) 'created_by': createdBy,
        'name': name.trim(),
        'kind': kind,
        'default_priority': defaultPriority,
        if (defaultEstimateMinutes != null)
          'default_estimate_minutes': defaultEstimateMinutes,
        'checklist_json': checklistTexts,
        if (blocksJson != null) 'blocks_json': jsonDecode(blocksJson),
      },
    );
    return id;
  }

  /// Menambah metadata lampiran (storagePath mengikuti format workspace_id/owner_table/owner_id/file)
  Future<String> addAttachmentMetadata({
    required String ownerTable,
    required String ownerId,
    required String fileName,
    String mime = 'application/pdf',
    int size = 1024,
  }) async {
    final wsId = (await getWorkspaceId()) ?? 'personal-ws';
    final id = const Uuid().v4();
    final now = DateTime.now();
    final createdBy = supabase.auth.currentUser?.id;
    final cleanName = fileName.trim();
    final storagePath = '$wsId/$ownerTable/$ownerId/${id}_$cleanName';
    final safeSize = size.clamp(1, 10485760);

    await db.into(db.localAttachments).insert(
      LocalAttachmentsCompanion.insert(
        id: id,
        workspaceId: wsId,
        ownerTable: ownerTable,
        ownerId: ownerId,
        storagePath: storagePath,
        mime: mime,
        size: safeSize,
        fileName: Value(cleanName),
        createdBy: Value(createdBy),
        createdAt: Value(now),
      ),
    );
    await pushRecord(
      tableName: 'attachments',
      recordId: id,
      action: 'insert',
      payload: {
        'id': id,
        'workspace_id': wsId,
        'owner_table': ownerTable,
        'owner_id': ownerId,
        'storage_path': storagePath,
        'mime': mime,
        'size': safeSize,
        'file_name': cleanName,
        if (createdBy != null) 'created_by': createdBy,
      },
    );
    return id;
  }

  /// Menghapus lampiran secara soft-delete
  Future<void> deleteAttachmentMetadata(String attachmentId) async {
    final now = DateTime.now();
    await (db.update(db.localAttachments)
          ..where((a) => a.id.equals(attachmentId)))
        .write(LocalAttachmentsCompanion(deletedAt: Value(now)));
    await pushRecord(
      tableName: 'attachments',
      recordId: attachmentId,
      action: 'update',
      payload: {'deleted_at': now.toUtc().toIso8601String()},
    );
  }

  /// Pencarian global lintas entitas (RPC fn_global_search saat online + fallback lokal Drift instan)
  Future<List<GlobalSearchHit>> globalSearch(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final Map<String, GlobalSearchHit> merged = {};

    // 1. Query lokal Drift terlebih dahulu agar respons instan & tersedia offline
    final tasks = await (db.select(db.localTasks)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    for (final t in tasks) {
      final hayTitle = t.title.toLowerCase();
      final hayDesc = (t.description ?? '').toLowerCase();
      if (hayTitle.contains(q) || hayDesc.contains(q)) {
        merged['task:${t.id}'] = GlobalSearchHit(
          entityType: 'task',
          entityId: t.id,
          title: t.title,
          subtitle: t.description,
          statusLabel: t.status,
          kind: t.kind,
          dueAt: t.dueAt,
        );
      }
    }

    final projects = await (db.select(db.localProjects)
          ..where((p) => p.deletedAt.isNull()))
        .get();
    for (final p in projects) {
      final hayName = p.name.toLowerCase();
      final hayClient = (p.clientName ?? '').toLowerCase();
      final hayDesc = (p.description ?? '').toLowerCase();
      if (hayName.contains(q) ||
          hayClient.contains(q) ||
          hayDesc.contains(q)) {
        merged['project:${p.id}'] = GlobalSearchHit(
          entityType: 'project',
          entityId: p.id,
          title: p.name,
          subtitle: p.clientName ?? p.description,
          statusLabel: p.status,
          kind: p.kind,
        );
      }
    }

    final events = await (db.select(db.localEvents)
          ..where((e) => e.deletedAt.isNull()))
        .get();
    for (final ev in events) {
      final hayTitle = ev.title.toLowerCase();
      final hayLoc = (ev.location ?? '').toLowerCase();
      final hayDesc = (ev.description ?? '').toLowerCase();
      if (hayTitle.contains(q) || hayLoc.contains(q) || hayDesc.contains(q)) {
        merged['event:${ev.id}'] = GlobalSearchHit(
          entityType: 'event',
          entityId: ev.id,
          title: ev.title,
          subtitle: ev.location ?? ev.description,
          statusLabel: DateFormat('dd MMM HH:mm').format(ev.startsAt),
          kind: ev.kind,
          dueAt: ev.startsAt,
        );
      }
    }

    final transactions = await (db.select(db.localTransactions)
          ..where((tr) => tr.deletedAt.isNull()))
        .get();
    for (final tx in transactions) {
      final hayNote = (tx.note ?? '').toLowerCase();
      final hayMerchant = (tx.merchant ?? '').toLowerCase();
      if (hayNote.contains(q) || hayMerchant.contains(q)) {
        merged['transaction:${tx.id}'] = GlobalSearchHit(
          entityType: 'transaction',
          entityId: tx.id,
          title: tx.merchant ?? tx.note ?? 'Transaksi',
          subtitle: tx.note ?? tx.type,
          statusLabel: tx.status,
          kind: tx.type,
          dueAt: tx.occurredAt,
        );
      }
    }

    // 2. Jika online, lengkapi dengan hasil RPC fn_global_search di Supabase
    if (supabase.auth.currentUser != null) {
      try {
        final wsId = await getWorkspaceId();
        if (wsId != null && wsId.isNotEmpty) {
          final res = await supabase.rpc('fn_global_search', params: {
            'p_workspace_id': wsId,
            'p_query': query.trim(),
            'p_limit': limit,
          });
          if (res is List) {
            for (final raw in res) {
              if (raw is! Map) continue;
              final type = raw['entity_type']?.toString() ?? 'task';
              final id = raw['entity_id']?.toString() ?? '';
              if (id.isEmpty) continue;
              final key = '$type:$id';
              merged.putIfAbsent(
                key,
                () => GlobalSearchHit(
                  entityType: type,
                  entityId: id,
                  title: raw['title']?.toString() ?? '',
                  subtitle: raw['subtitle']?.toString(),
                  statusLabel: raw['status_label']?.toString(),
                  kind: raw['kind']?.toString(),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('SyncService.globalSearch RPC fallback to local: $e');
      }
    }

    return merged.values.take(limit).toList();
  }
}

/// Hasil pencarian global lintas entitas Orbit
class GlobalSearchHit {
  final String entityType; // task, project, event, transaction
  final String entityId;
  final String title;
  final String? subtitle;
  final String? statusLabel;
  final String? kind;
  final DateTime? dueAt;

  const GlobalSearchHit({
    required this.entityType,
    required this.entityId,
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.kind,
    this.dueAt,
  });
}

/// Ringkasan kesehatan antrean sinkronisasi lokal (`syncOutbox`).
class OutboxHealthSummary {
  final int pendingCount;
  final int failedCount;
  final int syncedCount;
  final DateTime? oldestPendingAt;
  final String? lastError;

  const OutboxHealthSummary({
    required this.pendingCount,
    required this.failedCount,
    required this.syncedCount,
    this.oldestPendingAt,
    this.lastError,
  });

  int get unsyncedCount => pendingCount + failedCount;
  bool get hasIssues => failedCount > 0;
}
