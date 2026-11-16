import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/tasks/orbit_task_detail_page.dart';
import 'package:orbit_app/features/today/widgets/today_agenda_rows.dart';

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
  String? _attentionFilter; // overdue, revisi, stagnant, null

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _tasks = [];
  OrbitAttentionSummary _attentionSummary = const OrbitAttentionSummary(
    overdueCount: 0,
    revisionCount: 0,
    stagnantCount: 0,
    conflictCount: 0,
  );
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

      final filteredLocalTasks = localTsks
          .where((t) =>
              t.deletedAt == null &&
              (_selectedKind == 'all' || t.kind == _selectedKind))
          .toList();

      final todayLocalEvents = localEvts
          .where((e) =>
              e.deletedAt == null &&
              (_selectedKind == 'all' || e.kind == _selectedKind) &&
              !e.endsAt.isBefore(startOfDay) &&
              !e.startsAt.isAfter(endOfDay))
          .toList();

      final summary = computeOrbitAttentionSummary(
        tasks: filteredLocalTasks,
        todayEvents: todayLocalEvents,
        now: now,
      );

      final filteredTasks = filteredLocalTasks.map((t) {
        final isOverdue = isOrbitTaskOverdue(t, now: now) &&
            t.status != 'selesai';
        final isStagnant = isOrbitTaskStagnant(t, now: now);
        return {
          'id': t.id,
          'title': t.title,
          'kind': t.kind,
          'status': t.status,
          'priority': t.priority,
          'due_at': t.dueAt,
          'progress_percent': t.progressPercent,
          'revision_count': t.revisionCount,
          'is_overdue': isOverdue,
          'is_stagnant': isStagnant,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _events = filteredEvts;
          _tasks = filteredTasks;
          _attentionSummary = summary;
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

    try {
      await SyncService.instance.changeTaskStatus(
        taskId: id,
        toStatus: nextStatus,
      );
    } catch (_) {
      final completedAt = isDone ? null : DateTime.now();
      await (_db.update(_db.localTasks)..where((t) => t.id.equals(id))).write(
        LocalTasksCompanion(
          status: Value(nextStatus),
          completedAt: Value(completedAt),
        ),
      );
    }

    await _loadData();
  }

  Future<void> _openTaskDetail(String taskId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrbitTaskDetailPage(taskId: taskId),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: OrbitShellScope.maybeOf(context) != null
            ? const OrbitShellMenuButton()
            : null,
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
          const OrbitPrivacyToggleButton(),
          if (OrbitShellScope.maybeOf(context) != null)
            const OrbitShellSearchButton(),
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
              // Attention Banner Card v2 (Terlambat, Revisi, Macet >5 hari, Jadwal Bentrok)
              if (!_attentionSummary.isEmpty) ...[
                OrbitAttentionCard(
                  summary: _attentionSummary,
                  onTapSignal: (signal) {
                    if (signal == 'conflict') return;
                    setState(() {
                      _attentionFilter =
                          _attentionFilter == signal ? null : signal;
                    });
                  },
                ),
                const SizedBox(height: AppTokens.space3),
              ],

              // Peringatan Benturan Jadwal / Hari Padat
              if (_hasConflict && _conflictDescription != null) ...[
                TodayAlertBanner(
                  icon: Icons.warning_amber_rounded,
                  text: 'Benturan Jadwal: $_conflictDescription',
                  isDanger: true,
                ),
                const SizedBox(height: AppTokens.space3),
              ],

              if (_isHeavyDay) ...[
                const TodayAlertBanner(
                  icon: Icons.schedule,
                  text: 'Hari Padat: Total durasi jadwal mencapai 8 jam atau lebih.',
                ),
                const SizedBox(height: AppTokens.space3),
              ],

              // 1. Bagian Jadwal Hari Ini (Sesuai Urutan PRD M10c)
              TodaySectionHeader(
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
                        TodayEventRow(
                          event: _events[i],
                          hasConflict: _hasConflict,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppTokens.space6),

              // 2. Bagian Tugas Hari Ini & Terlambat
              Builder(
                builder: (context) {
                  final displayedTasks = _attentionFilter == null
                      ? _tasks
                      : _tasks.where((t) {
                          if (_attentionFilter == 'overdue') {
                            return t['is_overdue'] == true;
                          }
                          if (_attentionFilter == 'revisi') {
                            return t['status'] == 'revisi';
                          }
                          if (_attentionFilter == 'stagnant') {
                            return t['is_stagnant'] == true;
                          }
                          return true;
                        }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TodaySectionHeader(
                              icon: Icons.check_circle_outline,
                              title: 'Tugas Prioritas',
                              countLabel: '${displayedTasks.length}',
                            ),
                          ),
                          if (_attentionFilter != null)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _attentionFilter = null),
                              child: const Text('Reset filter'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space2),
                      if (displayedTasks.isEmpty)
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
                              for (int i = 0; i < displayedTasks.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                TodayTaskRow(
                                  task: displayedTasks[i],
                                  onToggleStatus: () =>
                                      _toggleTaskStatus(displayedTasks[i]),
                                  onTap: () => _openTaskDetail(
                                      displayedTasks[i]['id'] as String),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppTokens.space6),

              // 3. Bagian Ringkasan Uang Hari Itu
              const TodaySectionHeader(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Ringkasan Uang Hari Ini',
              ),
              const SizedBox(height: AppTokens.space2),
              TodayMoneySummaryCard(
                liquidBalance: _liquidBalance,
                todayIncome: _todayIncome,
                todayExpense: _todayExpense,
                draftCount: _draftCount,
                onOpenInbox: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const InboxScreen(),
                        ),
                      )
                      .then((_) => _loadData());
                },
                onQuickAdd: () {
                  TransactionFormSheet.show(
                    context,
                    onSaved: _loadData,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
