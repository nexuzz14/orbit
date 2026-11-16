import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/home_widget_bridge.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class TodayHeroCommandCard extends StatelessWidget {
  final int doneTasks;
  final int totalTasks;
  final int todayEventsCount;
  final int todayFocusMinutes;
  final double todayNetCashflow;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenPlanning;
  final VoidCallback? onOpenProjects;

  const TodayHeroCommandCard({
    super.key,
    required this.doneTasks,
    required this.totalTasks,
    required this.todayEventsCount,
    required this.todayFocusMinutes,
    required this.todayNetCashflow,
    this.onOpenSchedule,
    this.onOpenTasks,
    this.onOpenPlanning,
    this.onOpenProjects,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    final subtle = AppColors.accentSubtleColor(context);
    final ratio = totalTasks > 0 ? (doneTasks / totalTasks).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).round();

    return OrbitCard(
      borderColor: accent.withValues(alpha: 0.32),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceColor(context),
          subtle.withValues(alpha: 0.42),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: ratio),
                        duration: const Duration(milliseconds: 450),
                        builder: (context, val, _) => CircularProgressIndicator(
                          value: val,
                          strokeWidth: 6,
                          backgroundColor: AppColors.subtleColor(context),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMAND CENTER HARI INI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$doneTasks/$totalTasks Tugas • $todayFocusMinutes mnt Fokus',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    OrbitPrivacyBuilder(
                      builder: (context, masked) {
                        final netPrefix = todayNetCashflow >= 0 ? '+' : '-';
                        final netStr = masked
                            ? PrivacyModeController.maskedPlaceholder
                            : '$netPrefix${formatRupiah(todayNetCashflow.abs())}';
                        return Text(
                          '$todayEventsCount jadwal • Arus kas: $netStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryColor(context),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickModuleChip(
                icon: Icons.calendar_today_outlined,
                label: 'Jadwal',
                onTap: onOpenSchedule,
              ),
              _QuickModuleChip(
                icon: Icons.view_kanban_outlined,
                label: 'Papan Tugas',
                onTap: onOpenTasks,
              ),
              _QuickModuleChip(
                icon: Icons.pie_chart_outline,
                label: 'Anggaran & Tagihan',
                onTap: onOpenPlanning,
              ),
              _QuickModuleChip(
                icon: Icons.folder_outlined,
                label: 'Proyek',
                onTap: onOpenProjects,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickModuleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickModuleChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    return Material(
      color: AppColors.surfaceColor(context),
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodayFocusTimerCard extends StatefulWidget {
  final List<Map<String, dynamic>> activeTasks;
  final String? selectedTaskId;
  final ValueChanged<String>? onSelectedTaskChanged;
  final VoidCallback? onLogged;

  const TodayFocusTimerCard({
    super.key,
    required this.activeTasks,
    this.selectedTaskId,
    this.onSelectedTaskChanged,
    this.onLogged,
  });

  @override
  State<TodayFocusTimerCard> createState() => _TodayFocusTimerCardState();
}

class _TodayFocusTimerCardState extends State<TodayFocusTimerCard> {
  static const int _pomodoroSeconds = 25 * 60;
  String _mode = 'pomodoro'; // pomodoro | stopwatch
  bool _running = false;
  int _elapsed = 0;
  DateTime? _startedAt;
  Timer? _timer;
  bool _saving = false;
  String? _taskId;

  @override
  void initState() {
    super.initState();
    _syncSelectedTask();
  }

  @override
  void didUpdateWidget(covariant TodayFocusTimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTaskId != null &&
        widget.selectedTaskId != oldWidget.selectedTaskId) {
      _taskId = widget.selectedTaskId;
    } else {
      _syncSelectedTask();
    }
  }

  void _syncSelectedTask() {
    if (widget.selectedTaskId != null &&
        widget.activeTasks.any((t) => t['id'] == widget.selectedTaskId)) {
      _taskId = widget.selectedTaskId;
      return;
    }
    if (_taskId == null ||
        !widget.activeTasks.any((t) => t['id'] == _taskId)) {
      _taskId = widget.activeTasks.isNotEmpty
          ? widget.activeTasks.first['id'] as String
          : null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleStartPause() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    _startedAt ??= DateTime.now().toUtc();
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_mode == 'pomodoro' && _elapsed >= _pomodoroSeconds) {
          _running = false;
          _timer?.cancel();
        }
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _elapsed = 0;
      _startedAt = null;
    });
  }

  Future<void> _saveLog() async {
    if (_taskId == null || _elapsed <= 0 || _saving) return;
    _timer?.cancel();
    setState(() {
      _running = false;
      _saving = true;
    });

    final endedAt = DateTime.now().toUtc();
    final startedAt = _startedAt ?? endedAt.subtract(Duration(seconds: _elapsed));
    final secs = _elapsed;

    await SyncService.instance.createTaskTimeLog(
      taskId: _taskId!,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: secs,
      mode: _mode,
      note: 'Sesi fokus dari Hari Ini',
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _elapsed = 0;
      _startedAt = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sesi fokus ${(secs / 60).ceil()} menit tersimpan ke log tugas.',
        ),
      ),
    );
    widget.onLogged?.call();
  }

  String _formatClock(int total) {
    final s = total.clamp(0, 86400);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);
    final shown =
        _mode == 'pomodoro' ? (_pomodoroSeconds - _elapsed).clamp(0, _pomodoroSeconds) : _elapsed;
    final progress = _mode == 'pomodoro'
        ? (_elapsed / _pomodoroSeconds).clamp(0.0, 1.0)
        : ((_elapsed % 3600) / 3600).clamp(0.0, 1.0);

    return OrbitCard(
      borderColor: _running ? accent : AppColors.borderColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Focus Timer',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                    Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
                  ),
                ),
                segments: const [
                  ButtonSegment(value: 'pomodoro', label: Text('25m')),
                  ButtonSegment(value: 'stopwatch', label: Text('Stopwatch')),
                ],
                selected: {_mode},
                onSelectionChanged: (sel) {
                  _reset();
                  setState(() => _mode = sel.first);
                },
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                _formatClock(shown),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed:
                        widget.activeTasks.isEmpty ? null : _toggleStartPause,
                    icon: Icon(
                      _running ? Icons.pause : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(_running ? 'Jeda' : 'Mulai'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _reset,
                    tooltip: 'Reset timer',
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  IconButton(
                    onPressed: (_elapsed > 0 && !_saving) ? _saveLog : null,
                    tooltip: 'Simpan log fokus',
                    icon: Icon(
                      Icons.save_outlined,
                      size: 20,
                      color: _elapsed > 0 ? accent : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.subtleColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          if (widget.activeTasks.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _taskId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Tugas yang sedang difokuskan',
              ),
              items: widget.activeTasks.map((t) {
                return DropdownMenuItem<String>(
                  value: t['id'] as String,
                  child: Text(
                    t['title'] as String? ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _taskId = val);
                if (val != null) widget.onSelectedTaskChanged?.call(val);
              },
            )
          else
            Text(
              'Tambahkan tugas aktif untuk mulai mencatat waktu fokus.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
        ],
      ),
    );
  }
}

class TodayPlanningHubCard extends StatefulWidget {
  final List<LocalRecurringBill> bills;
  final List<LocalBudget> budgets;
  final List<LocalSavingsGoal> goals;
  final Map<String, double> spentByCategory;
  final Map<String, String> categoryNames;
  final VoidCallback onMutated;

  const TodayPlanningHubCard({
    super.key,
    required this.bills,
    required this.budgets,
    required this.goals,
    required this.spentByCategory,
    required this.categoryNames,
    required this.onMutated,
  });

  @override
  State<TodayPlanningHubCard> createState() => _TodayPlanningHubCardState();
}

class _TodayPlanningHubCardState extends State<TodayPlanningHubCard> {
  String _tab = 'bills'; // bills | budgets | goals
  String? _busyBillId;

  Future<void> _payBillNow(LocalRecurringBill bill) async {
    if (_busyBillId != null) return;
    setState(() => _busyBillId = bill.id);
    try {
      final db = AppDatabase.shared;
      final wsId = (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
      final txId = const Uuid().v4();
      final now = DateTime.now();

      await db.into(db.localTransactions).insert(
            LocalTransactionsCompanion.insert(
              id: txId,
              workspaceId: wsId,
              accountId: bill.accountId,
              categoryId: Value(bill.categoryId),
              type: 'expense',
              status: 'confirmed',
              amount: bill.amount,
              currency: 'IDR',
              source: const Value('pribadi'),
              merchant: Value(bill.name),
              note: Value('Pembayaran tagihan rutin: ${bill.name}'),
              occurredAt: now,
            ),
          );

      final acc = await (db.select(db.localAccounts)
            ..where((a) => a.id.equals(bill.accountId)))
          .getSingleOrNull();
      if (acc != null) {
        await (db.update(db.localAccounts)..where((a) => a.id.equals(acc.id))).write(
          LocalAccountsCompanion(
            currentBalance: Value(acc.currentBalance - bill.amount),
          ),
        );
      }

      await SyncService.instance.pushRecord(
        tableName: 'transactions',
        recordId: txId,
        action: 'insert',
        payload: {
          'id': txId,
          'workspace_id': wsId,
          'account_id': bill.accountId,
          'category_id': bill.categoryId,
          'type': 'expense',
          'status': 'confirmed',
          'amount': bill.amount,
          'currency': 'IDR',
          'source': 'personal',
          'merchant': bill.name,
          'note': 'Pembayaran tagihan rutin: ${bill.name}',
          'occurred_at': now.toUtc().toIso8601String(),
          'origin': 'manual',
        },
      );

      await HomeWidgetBridge.syncFromDatabase(db);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tagihan "${bill.name}" tercatat lunas.')),
        );
      }
      widget.onMutated();
    } finally {
      if (mounted) setState(() => _busyBillId = null);
    }
  }

  Future<void> _showTopupDialog(LocalSavingsGoal goal) async {
    final ctrl = TextEditingController(text: '100000');
    final confirmed = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Top-up ${goal.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nominal Setor (IDR)',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final val =
                  double.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
              Navigator.of(ctx).pop(val > 0 ? val : null);
            },
            child: const Text('Setor'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (confirmed == null || confirmed <= 0) return;
    final db = AppDatabase.shared;
    final nextAmount = goal.currentAmount + confirmed;
    final completed = nextAmount >= goal.targetAmount;

    await (db.update(db.localSavingsGoals)..where((g) => g.id.equals(goal.id))).write(
      LocalSavingsGoalsCompanion(
        currentAmount: Value(nextAmount),
        isCompleted: Value(completed),
      ),
    );
    await SyncService.instance.pushRecord(
      tableName: 'savings_goals',
      recordId: goal.id,
      action: 'update',
      payload: {
        'id': goal.id,
        'current_amount': nextAmount,
        'is_completed': completed,
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '+${formatRupiah(confirmed)} ditambahkan ke "${goal.name}".',
          ),
        ),
      );
    }
    widget.onMutated();
  }

  @override
  Widget build(BuildContext context) {
    final activeBills = widget.bills.where((b) => b.active).toList();
    return OrbitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 18,
                color: AppColors.accentColor(context),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kontrol Tagihan, Anggaran & Tabungan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space3),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(
                Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
              ),
            ),
            segments: [
              ButtonSegment(
                value: 'bills',
                label: Text('Tagihan (${activeBills.length})'),
              ),
              ButtonSegment(
                value: 'budgets',
                label: Text('Anggaran (${widget.budgets.length})'),
              ),
              ButtonSegment(
                value: 'goals',
                label: Text('Tabungan (${widget.goals.length})'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (sel) => setState(() => _tab = sel.first),
          ),
          const SizedBox(height: AppTokens.space3),
          if (_tab == 'bills') ...[
            if (activeBills.isEmpty)
              Text(
                'Belum ada tagihan rutin aktif.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor(context),
                ),
              )
            else
              for (final bill in activeBills.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            OrbitPrivacyBuilder(
                              builder: (context, masked) => Text(
                                '${masked ? PrivacyModeController.maskedPlaceholder : formatRupiah(bill.amount)} • Tgl ${bill.scheduleValue}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondaryColor(context),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed:
                            _busyBillId == bill.id ? null : () => _payBillNow(bill),
                        child: Text(_busyBillId == bill.id ? '...' : 'Bayar'),
                      ),
                    ],
                  ),
                ),
          ] else if (_tab == 'budgets') ...[
            if (widget.budgets.isEmpty)
              Text(
                'Belum ada anggaran bulanan.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor(context),
                ),
              )
            else
              for (final b in widget.budgets.take(4)) ...[
                Builder(
                  builder: (context) {
                    final spent = widget.spentByCategory[b.categoryId] ?? 0.0;
                    final ratio = b.amount > 0 ? (spent / b.amount) : 0.0;
                    final color = ratio >= 1.0
                        ? AppColors.expenseColor(context)
                        : ((ratio * 100) >= b.notifyAtPercent
                            ? AppColors.warningColor(context)
                            : AppColors.accentColor(context));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.categoryNames[b.categoryId] ?? b.categoryId,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              OrbitPrivacyBuilder(
                                builder: (context, masked) => Text(
                                  masked
                                      ? PrivacyModeController.maskedPlaceholder
                                      : '${formatRupiah(spent)} / ${formatRupiah(b.amount)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: AppColors.subtleColor(context),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
          ] else ...[
            if (widget.goals.isEmpty)
              Text(
                'Belum ada target tabungan.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor(context),
                ),
              )
            else
              for (final goal in widget.goals.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                OrbitPrivacyBuilder(
                                  builder: (context, masked) => Text(
                                    masked
                                        ? PrivacyModeController.maskedPlaceholder
                                        : '${formatRupiah(goal.currentAmount)} / ${formatRupiah(goal.targetAmount)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondaryColor(context),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showTopupDialog(goal),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Top-up'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: goal.targetAmount > 0
                              ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 6,
                          backgroundColor: AppColors.subtleColor(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goal.isCompleted
                                ? AppColors.incomeColor(context)
                                : AppColors.accentColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
