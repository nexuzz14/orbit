import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';

class TodayScreen extends StatefulWidget {
  final bool forceLoading;
  final String? forceError;

  const TodayScreen({
    super.key,
    this.forceLoading = false,
    this.forceError,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  AppDatabase get _db => AppDatabase.shared;

  bool _loading = true;
  String? _errorMessage;
  String _selectedKind = 'all'; // all, intern, freelance, kuliah, pribadi

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _hasConflict = false;
  String? _conflictDescription;
  bool _isHeavyDay = false;

  double _liquidBalance = 0.0;
  double _todayIncome = 0.0;
  double _todayExpense = 0.0;
  int _draftCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError != null) {
      _loading = false;
      _errorMessage = widget.forceError;
    } else {
      _loadData();
      SyncService.instance.pullAllFromSupabase().then((_) {
        if (mounted) _loadData();
      });
    }
  }

  String _greeting() {
    return getGreeting();
  }

  Future<void> _loadData({bool pull = false}) async {
    if (widget.forceLoading) return;
    setState(() {
      _loading = true;
      _errorMessage = widget.forceError;
    });

    if (widget.forceError != null) {
      setState(() => _loading = false);
      return;
    }

    if (pull) {
      await SyncService.instance.pullAllFromSupabase();
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // 1. Baca data lokal dari Drift terlebih dahulu (offline-first)
      final localAccs = await _db.select(_db.localAccounts).get();
      final localEvts = await _db.select(_db.localEvents).get();
      final localTsks = await _db.select(_db.localTasks).get();
      final localTxs = await _db.select(_db.localTransactions).get();

      double bal = 0;
      for (final a in localAccs) {
        if (a.isLiquid && !a.archived) {
          bal += a.currentBalance;
        }
      }

      double inc = 0;
      double exp = 0;
      int drafts = 0;
      for (final t in localTxs) {
        if (t.deletedAt != null) continue;
        if (t.status == 'draft') {
          drafts++;
          continue;
        }
        if (t.occurredAt.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            t.occurredAt.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
          if (t.type == 'income') inc += t.amount;
          if (t.type == 'expense') exp += t.amount;
        }
        if (bal == 0) {
          if (t.type == 'income') bal += t.amount;
          if (t.type == 'expense') bal -= t.amount;
        }
      }

      final filteredEvts = localEvts
          .where((e) =>
              e.deletedAt == null &&
              (_selectedKind == 'all' || e.kind == _selectedKind))
          .map((e) => {
                'id': e.id,
                'title': e.title,
                'kind': e.kind,
                'starts_at': e.startsAt,
                'ends_at': e.endsAt,
                'all_day': e.allDay,
                'location': e.location,
              })
          .toList();

      // Deteksi benturan waktu antar-jadwal
      bool conflict = false;
      String? conflictText;
      int totalMinutes = 0;
      for (int i = 0; i < filteredEvts.length; i++) {
        final aStart = filteredEvts[i]['starts_at'] as DateTime;
        final aEnd = filteredEvts[i]['ends_at'] as DateTime;
        totalMinutes += aEnd.difference(aStart).inMinutes.clamp(0, 1440);
        for (int j = i + 1; j < filteredEvts.length; j++) {
          final bStart = filteredEvts[j]['starts_at'] as DateTime;
          final bEnd = filteredEvts[j]['ends_at'] as DateTime;
          if (aStart.isBefore(bEnd) && bStart.isBefore(aEnd)) {
            conflict = true;
            conflictText =
                '"${filteredEvts[i]['title']}" berbenturan dengan "${filteredEvts[j]['title']}".';
          }
        }
      }

      final filteredTasks = localTsks
          .where((t) =>
              t.deletedAt == null &&
              (_selectedKind == 'all' || t.kind == _selectedKind))
          .map((t) {
            final isOverdue = t.dueAt != null &&
                t.dueAt!.isBefore(startOfDay) &&
                t.status != 'selesai' &&
                t.status != 'done';
            return {
              'id': t.id,
              'title': t.title,
              'kind': t.kind,
              'status': t.status,
              'priority': t.priority,
              'due_at': t.dueAt,
              'is_overdue': isOverdue,
            };
          })
          .toList();

      if (mounted) {
        setState(() {
          _events = filteredEvts;
          _tasks = filteredTasks;
          _hasConflict = conflict;
          _conflictDescription = conflictText;
          _isHeavyDay = totalMinutes >= 480;
          _liquidBalance = bal;
          _todayIncome = inc;
          _todayExpense = exp;
          _draftCount = drafts;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat ringkasan hari ini: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleTaskStatus(Map<String, dynamic> task) async {
    final id = task['id'] as String;
    final currentStatus = task['status'] as String;
    final isDone = currentStatus == 'done' || currentStatus == 'selesai';
    final nextStatus = isDone ? 'todo' : 'done';
    final completedAt = isDone ? null : DateTime.now();

    await (_db.update(_db.localTasks)..where((t) => t.id.equals(id))).write(
      LocalTasksCompanion(
        status: Value(nextStatus),
        completedAt: Value(completedAt),
      ),
    );

    SyncService.instance.pushRecord(
      tableName: 'tasks',
      recordId: id,
      action: 'update',
      payload: {
        'status': nextStatus,
        'completed_at': completedAt?.toIso8601String(),
      },
    );

    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: Image.asset(
                'assets/images/orbit_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.public, size: 28),
              ),
            ),
            const SizedBox(width: AppTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatDateIndoShort(now),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            tooltip: 'Muat ulang ringkasan hari ini',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(pull: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space4,
            AppTokens.space3,
            AppTokens.space4,
            96,
          ),
          children: [
            // Filter Chip Jenis Kegiatan
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in const [
                    MapEntry('all', 'Semua'),
                    MapEntry('intern', 'Intern'),
                    MapEntry('freelance', 'Freelance'),
                    MapEntry('kuliah', 'Kuliah'),
                    MapEntry('pribadi', 'Pribadi'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppTokens.space2),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.minTouchTarget,
                        ),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: _selectedKind == entry.key,
                          onSelected: (_) {
                            setState(() => _selectedKind = entry.key);
                            _loadData();
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space4),

            if (_errorMessage != null) ...[
              OrbitErrorState(
                message: _errorMessage!,
                onRetry: _loadData,
              ),
              const SizedBox(height: AppTokens.space4),
            ],

            if (_loading) ...[
              const OrbitSkeleton(height: 112),
              const SizedBox(height: AppTokens.space4),
              const OrbitSkeleton(height: 128),
              const SizedBox(height: AppTokens.space4),
              const OrbitSkeleton(height: 112),
            ] else ...[
              // Peringatan Benturan Jadwal / Hari Padat
              if (_hasConflict && _conflictDescription != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppTokens.space3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.expenseSubtleDark
                        : AppColors.expenseSubtleLight,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(
                      color: AppColors.expenseColor(context).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: AppColors.expenseColor(context),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      Expanded(
                        child: Text(
                          'Benturan Jadwal: $_conflictDescription',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expenseColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space3),
              ],

              if (_isHeavyDay) ...[
                Container(
                  padding: const EdgeInsets.all(AppTokens.space3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.warningSubtleDark
                        : AppColors.warningSubtleLight,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(
                      color: AppColors.warningColor(context).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: AppColors.warningColor(context),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      Expanded(
                        child: Text(
                          'Hari Padat: Total durasi jadwal mencapai 8 jam atau lebih.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warningColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.space3),
              ],

              // 1. Bagian Jadwal Hari Ini (Sesuai Urutan PRD M10c)
              _buildSectionHeader(
                context,
                icon: Icons.event_note_outlined,
                title: 'Jadwal Hari Ini',
                countLabel: '${_events.length}',
              ),
              const SizedBox(height: AppTokens.space2),
              if (_events.isEmpty)
                const OrbitEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'Belum ada jadwal hari ini',
                  description:
                      'Gunakan tombol + di kanan bawah untuk menambahkan jadwal baru.',
                )
              else
                OrbitCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < _events.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _buildEventRow(context, _events[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppTokens.space6),

              // 2. Bagian Tugas Hari Ini & Terlambat
              _buildSectionHeader(
                context,
                icon: Icons.check_circle_outline,
                title: 'Tugas Prioritas',
                countLabel: '${_tasks.length}',
              ),
              const SizedBox(height: AppTokens.space2),
              if (_tasks.isEmpty)
                const OrbitEmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'Tidak ada tugas jatuh tempo',
                  description: 'Semua tugas hari ini sudah selesai.',
                )
              else
                OrbitCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < _tasks.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _buildTaskRow(context, _tasks[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppTokens.space6),

              // 3. Bagian Ringkasan Uang Hari Itu
              _buildSectionHeader(
                context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Ringkasan Uang Hari Ini',
              ),
              const SizedBox(height: AppTokens.space2),
              OrbitCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total Saldo Likuid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space1),
                    Text(
                      formatRupiah(_liquidBalance),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: AppTokens.space4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppTokens.space3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSubtle
                                  : AppColors.lightSubtle,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pemasukan Hari Ini',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppTokens.space1),
                                Text(
                                  '+${formatRupiah(_todayIncome)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.incomeColor(context),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppTokens.space3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSubtle
                                  : AppColors.lightSubtle,
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusMd),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pengeluaran Hari Ini',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppTokens.space1),
                                Text(
                                  '-${formatRupiah(_todayExpense)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.expenseColor(context),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => const InboxScreen(),
                                    ),
                                  )
                                  .then((_) => _loadData());
                            },
                            icon: const Icon(Icons.inbox_outlined, size: 18),
                            label: Text('Inbox ($_draftCount Draft)'),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              TransactionFormSheet.show(
                                context,
                                onSaved: _loadData,
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Catat Uang'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? countLabel,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppTokens.space2),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (countLabel != null) OrbitStatusBadge(label: countLabel),
      ],
    );
  }

  Widget _buildEventRow(BuildContext context, Map<String, dynamic> evt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startsAt = evt['starts_at'] as DateTime;
    final endsAt = evt['ends_at'] as DateTime;
    final timeStr = evt['all_day'] == true
        ? 'Seharian'
        : '${DateFormat('HH:mm').format(startsAt)} - ${DateFormat('HH:mm').format(endsAt)}';
    final kind = evt['kind'] as String? ?? 'pribadi';
    final location = evt['location'] as String?;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evt['title'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.space1),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OrbitKindBadge(kind: kind),
                    if (_hasConflict)
                      const OrbitStatusBadge(
                        label: 'Benturan',
                        variant: OrbitBadgeVariant.expense,
                      ),
                    if (location != null && location.isNotEmpty)
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, Map<String, dynamic> task) {
    final isDone =
        task['status'] == 'done' || task['status'] == 'selesai';
    final isOverdue = task['is_overdue'] == true;
    final kind = task['kind'] as String? ?? 'pribadi';
    final priority = task['priority'] as String? ?? 'sedang';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space2,
        vertical: AppTokens.space2,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _toggleTaskStatus(task),
            tooltip: isDone ? 'Tandai belum selesai' : 'Tandai selesai',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone
                  ? AppColors.incomeColor(context)
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration:
                        isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: AppTokens.space1),
                Wrap(
                  spacing: AppTokens.space2,
                  runSpacing: AppTokens.space1,
                  children: [
                    OrbitKindBadge(kind: kind),
                    if (isOverdue && !isDone)
                      const OrbitStatusBadge(
                        label: 'Terlambat',
                        variant: OrbitBadgeVariant.expense,
                      ),
                    if (priority == 'tinggi' || priority == 'mendesak')
                      const OrbitStatusBadge(
                        label: 'Prioritas Tinggi',
                        variant: OrbitBadgeVariant.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
