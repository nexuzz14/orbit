import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:orbit_app/core/storage/secure_storage_service.dart';

part 'database.g.dart';

// Tabel Akun Lokal
class LocalAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get currency => text()();
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isLiquid => boolean().withDefault(const Constant(true))();
  TextColumn get visibility => text().withDefault(const Constant('shared'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Kategori Lokal
class LocalCategories extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // income / expense
  TextColumn get parentId => text().nullable()();
  TextColumn get systemKey => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Transaksi Lokal
class LocalTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get type => text()(); // income / expense / transfer
  TextColumn get status => text()(); // draft / confirmed
  TextColumn get draftState => text().nullable()(); // baru / perlu_dilengkapi / perlu_dicek
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  TextColumn get source => text().nullable()(); // intern / freelance / kuliah / personal
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get transferGroupId => text().nullable()();
  TextColumn get transferDirection => text().nullable()();
  TextColumn get origin => text().withDefault(const Constant('manual'))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Outbox Sinkronisasi Idempoten (PRD Bagian 12)
class SyncOutbox extends Table {
  TextColumn get id => text()(); // client_generated_id (UUID)
  TextColumn get tableName => text()();
  TextColumn get recordId => text()();
  TextColumn get action => text()(); // insert / update / delete / rpc
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending / synced / failed
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalAccounts, LocalCategories, LocalTransactions, SyncOutbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'orbit_encrypted.db'));

    // Ambil passphrase dari Secure Storage untuk SQLCipher (PRD 9.7 & 9.9)
    final passphrase = await SecureStorageService.getOrCreateDatabasePassphrase();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // Jika SQLCipher aktif, terapkan PRAGMA key
        try {
          rawDb.execute("PRAGMA key = '$passphrase';");
          rawDb.execute("PRAGMA cipher_memory_security = ON;");
        } catch (_) {
          // Fallback bila run di desktop environment tanpa build SQLCipher
        }
      },
    );
  });
}
