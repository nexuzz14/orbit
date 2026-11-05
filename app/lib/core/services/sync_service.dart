import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:orbit_app/core/database/database.dart';

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
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncService({required this.db, required this.supabase});

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

    _isSyncing = true;
    try {
      final wsId = await getWorkspaceId();
      if (wsId == null || wsId.isEmpty) return;

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
          await db.into(db.localProjects).insertOnConflictUpdate(
            LocalProjectsCompanion.insert(
              id: m['id'] as String,
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

      // 4. Tarik Tugas (tasks)
      try {
        final tasksData = await supabase
            .from('tasks')
            .select('*')
            .eq('workspace_id', wsId)
            .isFilter('deleted_at', null);

        for (final m in tasksData) {
          await db.into(db.localTasks).insertOnConflictUpdate(
            LocalTasksCompanion.insert(
              id: m['id'] as String,
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
          final startsAt = DateTime.tryParse(m['starts_at'].toString()) ??
              DateTime.now();
          final endsAt = DateTime.tryParse(m['ends_at'].toString()) ??
              startsAt.add(const Duration(hours: 1));
          await db.into(db.localEvents).insertOnConflictUpdate(
            LocalEventsCompanion.insert(
              id: m['id'] as String,
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
          final occurredAt =
              DateTime.tryParse(m['occurred_at'].toString()) ?? DateTime.now();
          await db.into(db.localTransactions).insertOnConflictUpdate(
            LocalTransactionsCompanion.insert(
              id: m['id'] as String,
              workspaceId: m['workspace_id'] as String,
              accountId: m['account_id'] as String,
              categoryId: Value(m['category_id'] as String?),
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
          await db.into(db.localProjectPayments).insertOnConflictUpdate(
            LocalProjectPaymentsCompanion.insert(
              id: m['id'] as String,
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

      // 13. Kirim antrean outbox yang belum tersinkronisasi
      await triggerSync();
    } catch (e, st) {
      debugPrint('SyncService.pullAllFromSupabase error: $e\n$st');
    } finally {
      _isSyncing = false;
    }
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
        if (action == 'insert') {
          await supabase.from(tableName).insert(payload);
          return;
        } else if (action == 'update') {
          await supabase.from(tableName).update(payload).eq('id', recordId);
          return;
        } else if (action == 'delete') {
          await supabase.from(tableName).delete().eq('id', recordId);
          return;
        } else if (action == 'rpc') {
          await supabase.rpc(tableName, params: payload);
          return;
        }
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

  /// Memproses antrean outbox ke Supabase
  Future<void> triggerSync() async {
    if (supabase.auth.currentUser == null) return;

    final pendingOps = await (db.select(db.syncOutbox)
          ..where((tbl) => tbl.status.equals('pending'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();

    for (final op in pendingOps) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;

        if (op.action == 'rpc') {
          await supabase.rpc(op.targetTable, params: payload);
        } else if (op.action == 'insert') {
          await supabase.from(op.targetTable).insert(payload);
        } else if (op.action == 'update') {
          await supabase
              .from(op.targetTable)
              .update(payload)
              .eq('id', op.recordId);
        } else if (op.action == 'delete') {
          if (op.targetTable == 'transactions') {
            await supabase.rpc('fn_delete_transaction',
                params: {'p_transaction_id': op.recordId});
          } else {
            await supabase
                .from(op.targetTable)
                .delete()
                .eq('id', op.recordId);
          }
        }

        // Tandai sukses sinkronisasi
        await (db.update(db.syncOutbox)..where((tbl) => tbl.id.equals(op.id)))
            .write(
          const SyncOutboxCompanion(
            status: Value('synced'),
          ),
        );
      } catch (e) {
        debugPrint('Sync failed for op ${op.id}: $e');
        await (db.update(db.syncOutbox)..where((tbl) => tbl.id.equals(op.id)))
            .write(
          SyncOutboxCompanion(
            attempts: Value(op.attempts + 1),
            lastError: Value(e.toString()),
            status: Value(op.attempts >= 5 ? 'failed' : 'pending'),
          ),
        );
      }
    }
  }
}
