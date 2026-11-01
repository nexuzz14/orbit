import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:orbit_app/core/database/database.dart';

class SyncService {
  final AppDatabase db;
  final SupabaseClient supabase;

  SyncService({required this.db, required this.supabase});

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
          await supabase.from(op.targetTable).update(payload).eq('id', op.recordId);
        } else if (op.action == 'delete') {
          await supabase.rpc('fn_delete_transaction', params: {'p_transaction_id': op.recordId});
        }

        // Tandai sukses sinkronisasi
        await (db.update(db.syncOutbox)..where((tbl) => tbl.id.equals(op.id))).write(
          const SyncOutboxCompanion(
            status: Value('synced'),
          ),
        );
      } catch (e) {
        debugPrint('Sync failed for op ${op.id}: $e');
        await (db.update(db.syncOutbox)..where((tbl) => tbl.id.equals(op.id))).write(
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
