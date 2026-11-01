import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  TextColumn get targetTable => text()();
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

// -----------------------------------------------------------------------------
// Tabel Fase 2: Kerja, Tugas, Jadwal, & Milestone Pembayaran
// -----------------------------------------------------------------------------

// Tabel Proyek Lokal
class LocalProjects extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get kind => text()(); // intern / freelance / kuliah / pribadi
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('berjalan'))();
  DateTimeColumn get startedOn => dateTime().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get clientName => text().nullable()();
  RealColumn get contractValue => real().nullable()();
  TextColumn get currency => text().nullable()();
  RealColumn get platformFeePercent => real().nullable()();
  TextColumn get feeMode => text().nullable()();
  IntColumn get semester => integer().nullable()();
  TextColumn get courseCode => text().nullable()();
  IntColumn get credits => integer().nullable()();
  RealColumn get stipendAmount => real().nullable()();
  IntColumn get stipendDay => integer().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Tugas Lokal
class LocalTasks extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get projectId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('todo'))();
  TextColumn get priority => text().withDefault(const Constant('sedang'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get dueIsDateOnly => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get milestonePaymentId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Checklist Item Tugas Lokal
class LocalTaskChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get textContent => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Event Jadwal Lokal
class LocalEvents extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get projectId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get timezone => text().withDefault(const Constant('Asia/Jakarta'))();
  TextColumn get recurrence => text().nullable()(); // JSON string
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Milestone Pembayaran Lokal
class LocalProjectPayments extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get projectId => text()();
  TextColumn get label => text()();
  RealColumn get amount => real()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get accountId => text().nullable()();
  TextColumn get transactionId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Cache Agenda Lokal (Untuk Layar Hari Ini Offline, PRD M10c)
class LocalAgendaCache extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get itemType => text()(); // event / task
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get projectName => text().nullable()();
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get location => text().nullable()();
  TextColumn get status => text()();
  TextColumn get priority => text().nullable()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get dueIsDateOnly => boolean().withDefault(const Constant(false))();
  BoolColumn get isOverdue => boolean().withDefault(const Constant(false))();
  IntColumn get checklistTotal => integer().withDefault(const Constant(0))();
  IntColumn get checklistDone => integer().withDefault(const Constant(0))();
  TextColumn get eventId => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get milestonePaymentId => text().nullable()();
  TextColumn get cachedDate => text()(); // YYYY-MM-DD

  @override
  Set<Column> get primaryKey => {id, cachedDate};
}

// -----------------------------------------------------------------------------
// Tabel Fase 3: Perencanaan Keuangan (Budget, Tagihan, Tabungan, Split)
// -----------------------------------------------------------------------------

// Tabel Anggaran Lokal
class LocalBudgets extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get categoryId => text()();
  RealColumn get amount => real()();
  TextColumn get period => text().withDefault(const Constant('monthly'))();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  RealColumn get notifyAtPercent => real().withDefault(const Constant(80.0))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Tagihan Rutin Lokal
class LocalRecurringBills extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text()();
  TextColumn get accountId => text()();
  TextColumn get scheduleType => text().withDefault(const Constant('monthly'))();
  IntColumn get scheduleValue => integer().withDefault(const Constant(1))();
  TextColumn get remindDaysBefore => text().withDefault(const Constant('[3, 0]'))(); // JSON array
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get autoCreateDraft => boolean().withDefault(const Constant(true))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Target Tabungan Lokal
class LocalSavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Tabel Aturan Auto-Split Lokal
class LocalIncomeSplitRules extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get source => text()();
  TextColumn get goalId => text()();
  TextColumn get splitType => text().withDefault(const Constant('percentage'))();
  RealColumn get splitValue => real()();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  LocalAccounts,
  LocalCategories,
  LocalTransactions,
  SyncOutbox,
  LocalProjects,
  LocalTasks,
  LocalTaskChecklistItems,
  LocalEvents,
  LocalProjectPayments,
  LocalAgendaCache,
  LocalBudgets,
  LocalRecurringBills,
  LocalSavingsGoals,
  LocalIncomeSplitRules,
])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase shared = AppDatabase();

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(localProjects);
        await m.createTable(localTasks);
        await m.createTable(localTaskChecklistItems);
        await m.createTable(localEvents);
        await m.createTable(localProjectPayments);
        await m.createTable(localAgendaCache);
      }
      if (from < 3) {
        await m.createTable(localBudgets);
        await m.createTable(localRecurringBills);
        await m.createTable(localSavingsGoals);
        await m.createTable(localIncomeSplitRules);
      }
    },
  );
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
