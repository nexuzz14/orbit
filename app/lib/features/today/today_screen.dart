import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/services/theme_controller.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:orbit_app/core/widgets/today_command_widgets.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';
import 'package:orbit_app/features/inbox/inbox_screen.dart';
import 'package:orbit_app/features/planning/planning_screen.dart';
import 'package:orbit_app/features/projects/projects_screen.dart';
import 'package:orbit_app/features/schedule/schedule_screen.dart';
import 'package:orbit_app/features/tasks/orbit_task_detail_page.dart';
import 'package:orbit_app/features/today/widgets/today_agenda_rows.dart';
import 'package:uuid/uuid.dart';

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
  int _todayFocusMinutes = 0;
  String? _focusTaskId;

  List<LocalRecurringBill> _bills = const [];
  List<LocalBudget> _budgets = const [];
  List<LocalSavingsGoal> _goals = const [];
  Map<String, double> _spentByCategory = const {};
  Map<String, String> _categoryNames = const {};

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
      final localBills = await (_db.select(_db.localRecurringBills)
            ..where((b) => b.deletedAt.isNull()))
          .get();
      final localBudgets = await (_db.select(_db.localBudgets)
            ..where((b) => b.deletedAt.isNull()))
          .get();
      final localGoals = await (_db.select(_db.localSavingsGoals)
            ..where((g) => g.deletedAt.isNull()))
          .get();
      final localCats = await (_db.select(_db.localCategories)
            ..where((c) => c.archived.equals(false)))
          .get();
      final localTimeLogs = await (_db.select(_db.localTaskTimeLogs)
            ..where((l) => l.deletedAt.isNull()))
          .get();

      double bal = 0;
      for (final a in localAccs) {
        if (a.isLiquid && !a.archived) {
          bal += a.currentBalance;
        }
      }

      double inc = 0;
      double exp = 0;
      int drafts = 0;
      final monthlyCatSpent = <String, double>{};
      for (final t in localTxs) {
        if (t.deletedAt != null) continue;
        if (t.status == 'draft') {
          drafts++;
          continue;
        }
        final wibTx = t.occurredAt.toUtc().add(const Duration(hours: 7));
        if (t.type == 'expense' &&
            t.categoryId != null &&
            wibTx.year == now.year &&
            wibTx.month == now.month) {
          monthlyCatSpent[t.categoryId!] =
              (monthlyCatSpent[t.categoryId!] ?? 0.0) + t.amount;
        }
        if (t.occurredAt.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
            t.occurredAt.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
          if (t.type == 'income') inc += t.amount;
          if (t.type == 'expense') exp += t.amount;
        }
        if (localAccs.isEmpty) {
          if (t.type == 'income') bal += t.amount;
          if (t.type == 'expense') bal -= t.amount;
          if (t.type == 'transfer') {
            bal += t.transferDirection == 'in' ? t.amount : -t.amount;
          }
        }
      }

      int focusSecToday = 0;
      for (final log in localTimeLogs) {
        final localStart = log.startedAt.toLocal();
        if (localStart.year == now.year &&
            localStart.month == now.month &&
            localStart.day == now.day) {
          focusSecToday += log.durationSeconds;
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
                'project_id': e.projectId,
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
          'project_id': t.projectId,
          'status': t.status,
          'priority': t.priority,
          'due_at': t.dueAt,
          'estimate_minutes': t.estimateMinutes,
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
          _todayFocusMinutes = (focusSecToday / 60).round();
          _bills = localBills;
          _budgets = localBudgets;
          _goals = localGoals;
          _spentByCategory = monthlyCatSpent;
          _categoryNames = {for (final c in localCats) c.id: c.name};
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

  Future<void> _createTaskFromEvent(Map<String, dynamic> event) async {
    final title = event['title'] as String? ?? 'Jadwal';
    final kind = event['kind'] as String? ?? 'pribadi';
    final projectId = event['project_id'] as String?;
    final eventId = event['id'] as String?;
    final endsAt = event['ends_at'] as DateTime?;

    final taskId = await SyncService.instance.createTask(
      title: 'Tindak lanjut: $title',
      kind: kind,
      projectId: projectId,
      dueAt: endsAt ?? DateTime.now(),
      dueIsDateOnly: event['all_day'] == true,
      priority: 'sedang',
    );
    if (eventId != null) {
      try {
        await SyncService.instance.addEntityLink(
          sourceType: 'task',
          sourceId: taskId,
          targetType: 'event',
          targetId: eventId,
          relationType: 'derived_from',
        );
      } catch (_) {}
    }
    await HomeWidgetBridge.syncFromDatabase(_db);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tugas "Tindak lanjut: $title" dibuat & ditautkan.')),
    );
    await _loadData();
  }

  Future<void> _scheduleFocusBlockForTask(Map<String, dynamic> task) async {
    final wsId = (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
    final title = task['title'] as String? ?? 'Tugas';
    final kind = task['kind'] as String? ?? 'pribadi';
    final projectId = task['project_id'] as String?;
    final taskId = task['id'] as String;
    final mins = ((task['estimate_minutes'] as int?) ?? 60).clamp(30, 180);

    final now = DateTime.now();
    final startHour = (now.hour + 1).clamp(8, 22);
    final startsAt = DateTime(now.year, now.month, now.day, startHour, 0);
    final endsAt = startsAt.add(Duration(minutes: mins));
    final eventId = const Uuid().v4();

    await _db.into(_db.localEvents).insert(
          LocalEventsCompanion.insert(
            id: eventId,
            workspaceId: wsId,
            projectId: Value(projectId),
            kind: kind,
            title: 'Fokus: $title',
            startsAt: startsAt,
            endsAt: endsAt,
          ),
        );
    await SyncService.instance.pushRecord(
      tableName: 'events',
      recordId: eventId,
      action: 'insert',
      payload: {
        'id': eventId,
        'workspace_id': wsId,
        if (projectId != null) 'project_id': projectId,
        'kind': kind,
        'title': 'Fokus: $title',
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'all_day': false,
        'timezone': 'Asia/Jakarta',
      },
    );
    try {
      await SyncService.instance.addEntityLink(
        sourceType: 'event',
        sourceId: eventId,
        targetType: 'task',
        targetId: taskId,
        relationType: 'related',
      );
    } catch (_) {}
    await HomeWidgetBridge.syncFromDatabase(_db);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Blok fokus "$title" ($mins mnt) masuk Jadwal.')),
    );
    await _loadData();
  }

  void _showEventActionSheet(Map<String, dynamic> event) {
    final title = event['title'] as String? ?? '';
    final kind = event['kind'] as String? ?? 'pribadi';
    final projectId = event['project_id'] as String?;
    final eventId = event['id'] as String?;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Aksi Lintas Modul Terhubung',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor(ctx),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.add_task_rounded, color: AppColors.accentColor(ctx)),
                title: const Text('Buat Tugas Tindak Lanjut'),
                subtitle: const Text('Tautkan langsung ke jadwal ini'),
                onTap: () {
                  Navigator.pop(ctx);
                  _createTaskFromEvent(event);
                },
              ),
              ListTile(
                leading: Icon(Icons.receipt_long_outlined, color: AppColors.accentColor(ctx)),
                title: const Text('Catat Biaya / Pengeluaran Jadwal'),
                subtitle: const Text('Otomatis terhubung ke proyek & jadwal'),
                onTap: () {
                  Navigator.pop(ctx);
                  TransactionFormSheet.show(
                    context,
                    initialType: 'expense',
                    initialNote: 'Biaya jadwal: $title',
                    initialSource: kind,
                    initialProjectId: projectId,
                    linkTargetType: eventId != null ? 'event' : null,
                    linkTargetId: eventId,
                    onSaved: _loadData,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Buka di Agenda & Jadwal'),
                onTap: () {
                  Navigator.pop(ctx);
                  final scope = OrbitShellScope.maybeOf(context);
                  if (scope?.switchTab != null) {
                    scope!.switchTab!(1, agendaMode: 'jadwal');
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          IconButton(
            onPressed: () => OrbitThemeController.showPickerSheet(context),
            tooltip: 'Tema & Aksen',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            icon: Icon(
              Icons.palette_outlined,
              color: AppColors.accentColor(context),
            ),
          ),
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
              // 0. Bento Command Center Hero Card
              Builder(
                builder: (context) {
                  final doneCount = _tasks
                      .where((t) =>
                          t['status'] == 'done' || t['status'] == 'selesai')
                      .length;
                  final shellScope = OrbitShellScope.maybeOf(context);
                  return TodayHeroCommandCard(
                    doneTasks: doneCount,
                    totalTasks: _tasks.length,
                    todayEventsCount: _events.length,
                    todayFocusMinutes: _todayFocusMinutes,
                    todayNetCashflow: _todayIncome - _todayExpense,
                    onOpenSchedule: () {
                      if (shellScope?.switchTab != null) {
                        shellScope!.switchTab!(1, agendaMode: 'jadwal');
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScheduleScreen(),
                          ),
                        );
                      }
                    },
                    onOpenTasks: () {
                      if (shellScope?.switchTab != null) {
                        shellScope!.switchTab!(1, agendaMode: 'tugas');
                      }
                    },
                    onOpenPlanning: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const PlanningScreen(),
                            ),
                          )
                          .then((_) => _loadData());
                    },
                    onOpenProjects: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const ProjectsScreen(),
                            ),
                          )
                          .then((_) => _loadData());
                    },
                  );
                },
              ),
              const SizedBox(height: AppTokens.space4),

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
                          onTap: () => _showEventActionSheet(_events[i]),
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
                                  onFocusTap: () {
                                    setState(() {
                                      _focusTaskId =
                                          displayedTasks[i]['id'] as String;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Timer Fokus siap untuk "${displayedTasks[i]['title']}".',
                                        ),
                                      ),
                                    );
                                  },
                                  onScheduleTap: () =>
                                      _scheduleFocusBlockForTask(
                                        displayedTasks[i],
                                      ),
                                  onExpenseTap: () {
                                    final t = displayedTasks[i];
                                    TransactionFormSheet.show(
                                      context,
                                      initialType: 'expense',
                                      initialNote: 'Biaya tugas: ${t['title']}',
                                      initialSource: t['kind'] as String?,
                                      initialProjectId:
                                          t['project_id'] as String?,
                                      linkTargetType: 'task',
                                      linkTargetId: t['id'] as String,
                                      onSaved: _loadData,
                                    );
                                  },
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

              // 2B. Focus Timer Terintegrasi
              TodayFocusTimerCard(
                activeTasks: _tasks
                    .where((t) =>
                        t['status'] != 'done' && t['status'] != 'selesai')
                    .toList(),
                selectedTaskId: _focusTaskId,
                onSelectedTaskChanged: (id) =>
                    setState(() => _focusTaskId = id),
                onLogged: _loadData,
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
              const SizedBox(height: AppTokens.space4),
              TodayPlanningHubCard(
                bills: _bills,
                budgets: _budgets,
                goals: _goals,
                spentByCategory: _spentByCategory,
                categoryNames: _categoryNames,
                onMutated: _loadData,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
