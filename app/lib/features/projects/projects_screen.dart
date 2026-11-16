import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/finance_csv_service.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_privacy_widgets.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';
import 'package:uuid/uuid.dart';

class ProjectsScreen extends StatefulWidget {
  final String initialTab;
  final bool forceLoading;
  final bool forceError;

  const ProjectsScreen({
    super.key,
    this.initialTab = 'kegiatan',
    this.forceLoading = false,
    this.forceError = false,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late String _tab; // kegiatan | piutang | linimasa | laporan
  bool _loading = true;
  String? _errorMessage;

  List<LocalProject> _projects = const [];
  List<LocalProjectPayment> _payments = const [];
  List<LocalTask> _tasks = const [];
  List<LocalTransaction> _transactions = const [];
  List<LocalTaskTimeLog> _timeLogs = const [];
  List<LocalAccount> _accounts = const [];
  Map<String, String> _projectNames = const {};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    if (widget.forceLoading) {
      _loading = true;
    } else if (widget.forceError) {
      _loading = false;
      _errorMessage = 'Gagal memuat data proyek lokal.';
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final db = AppDatabase.shared;
      final projects = await (db.select(
        db.localProjects,
      )..where((p) => p.deletedAt.isNull())).get();
      final payments = await (db.select(
        db.localProjectPayments,
      )..where((p) => p.deletedAt.isNull())).get();
      final tasks = await (db.select(
        db.localTasks,
      )..where((t) => t.deletedAt.isNull())).get();
      final txs = await (db.select(
        db.localTransactions,
      )..where((t) => t.deletedAt.isNull())).get();
      final timeLogs = await (db.select(
        db.localTaskTimeLogs,
      )..where((l) => l.deletedAt.isNull())).get();
      final accounts = await (db.select(
        db.localAccounts,
      )..where((a) => a.archived.equals(false))).get();

      if (!mounted) return;
      setState(() {
        _projects = projects;
        _payments = payments;
        _tasks = tasks;
        _transactions = txs;
        _timeLogs = timeLogs;
        _accounts = accounts;
        _projectNames = {for (final p in projects) p.id: p.name};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat proyek: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasColor(context),
      appBar: AppBar(
        title: const Text('Proyek & Kegiatan'),
        actions: [
          const OrbitPrivacyToggleButton(),
          IconButton(
            tooltip: _tab == 'piutang' ? 'Tambah Termin' : 'Tambah Proyek',
            constraints: const BoxConstraints(
              minWidth: AppTokens.minTouchTarget,
              minHeight: AppTokens.minTouchTarget,
            ),
            onPressed: _tab == 'piutang'
                ? _showAddPaymentSheet
                : _showAddProjectSheet,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSegmentBar(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildSegmentBar(BuildContext context) {
    const tabs = [
      ('kegiatan', 'Kegiatan', Icons.folder_outlined),
      ('piutang', 'Piutang', Icons.payments_outlined),
      ('linimasa', 'Linimasa', Icons.view_timeline_outlined),
      ('laporan', 'Laporan', Icons.analytics_outlined),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space4,
        AppTokens.space3,
        AppTokens.space4,
        AppTokens.space3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor(context)),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.subtleColor(context),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Row(
          children: tabs.map((item) {
            final selected = _tab == item.$1;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = item.$1),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                child: AnimatedContainer(
                  duration: AppTokens.animFast,
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.surfaceColor(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    border: selected
                        ? Border.all(color: AppColors.borderColor(context))
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$3,
                        size: 15,
                        color: selected
                            ? AppColors.textPrimaryColor(context)
                            : AppColors.textMutedColor(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.textPrimaryColor(context)
                              : AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: const [
          OrbitSkeleton(height: 88),
          SizedBox(height: AppTokens.space3),
          OrbitSkeleton(height: 88),
        ],
      );
    }

    if (_errorMessage != null) {
      return OrbitErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    switch (_tab) {
      case 'piutang':
        return _buildPiutangTab(context);
      case 'linimasa':
        return _buildTimelineAndWorkloadTab(context);
      case 'laporan':
        return _buildMarginReportTab(context);
      default:
        return _buildKegiatanTab(context);
    }
  }

  Widget _buildKegiatanTab(BuildContext context) {
    if (_projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 36),
            OrbitEmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Belum ada proyek atau kegiatan',
              description:
                  'Buat proyek freelance, magang, atau mata kuliah untuk melacak tugas dan margin.',
              actionLabel: 'Tambah Proyek',
              onAction: _showAddProjectSheet,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.space4),
        itemCount: _projects.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space2),
        itemBuilder: (context, index) {
          final p = _projects[index];
          final projTasks = _tasks.where((t) => t.projectId == p.id).toList();
          final doneTasks = projTasks.where((t) => t.status == 'done').length;
          final totalEstMin = projTasks.fold<int>(
            0,
            (s, t) => s + (t.estimateMinutes ?? 0),
          );
          final taskIds = projTasks.map((t) => t.id).toSet();
          final loggedSeconds = _timeLogs
              .where((l) => taskIds.contains(l.taskId))
              .fold<int>(0, (s, l) => s + l.durationSeconds);
          final progress = projTasks.isNotEmpty
              ? doneTasks / projTasks.length
              : 0.0;

          return OrbitCard(
            onTap: () => _showProjectDetailSheet(p),
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppTokens.space2,
                        runSpacing: AppTokens.space1,
                        children: [
                          OrbitKindBadge(kind: p.kind),
                          OrbitStatusBadge(
                            label: _projectStatusLabel(p.status),
                            variant: p.status == 'completed'
                                ? OrbitBadgeVariant.income
                                : OrbitBadgeVariant.neutral,
                          ),
                        ],
                      ),
                    ),
                    if (p.contractValue != null && p.contractValue! > 0) ...[
                      const SizedBox(width: AppTokens.space2),
                      Flexible(
                        child: OrbitAmountText(
                          amount: p.contractValue!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                if (p.clientName != null && p.clientName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Klien: ${p.clientName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.space3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.subtleColor(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$doneTasks/${projTasks.length} tugas selesai',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space2),
                    Flexible(
                      child: Text(
                        'Est ${_formatMinutesAsHours(totalEstMin)} | Log ${_formatMinutesAsHours((loggedSeconds / 60).round())}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPiutangTab(BuildContext context) {
    final pendingTotal = _payments
        .where((p) => p.status != 'paid')
        .fold<double>(0, (s, p) => s + (p.amount - p.paidAmount).clamp(0, p.amount));
    final paidTotal = _payments.fold<double>(
      0,
      (s, p) => s + (p.status == 'paid' ? p.amount : p.paidAmount),
    );

    if (_payments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 36),
            OrbitEmptyState(
              icon: Icons.payments_outlined,
              title: 'Belum ada termin piutang',
              description:
                  'Catat termin invoice atau pembayaran proyek yang akan diterima.',
              actionLabel: 'Tambah Termin',
              onAction: _showAddPaymentSheet,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Piutang Menunggu',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      OrbitAmountText(
                        amount: pendingTotal,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.warningColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Sudah Terbayar',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      OrbitAmountText(
                        amount: paidTotal,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.incomeColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          for (final pay in _payments) ...[
            OrbitCard(
              padding: const EdgeInsets.all(AppTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pay.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ),
                      OrbitStatusBadge(
                        label: _paymentStatusLabel(pay),
                        variant: pay.status == 'paid'
                            ? OrbitBadgeVariant.income
                            : (pay.status == 'overdue'
                                ? OrbitBadgeVariant.expense
                                : OrbitBadgeVariant.warning),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _projectNames[pay.projectId] ?? 'Proyek',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: OrbitAmountText(
                          amount: pay.amount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                      ),
                      if (pay.dueDate != null) ...[
                        const SizedBox(width: AppTokens.space2),
                        Flexible(
                          child: Text(
                            'Jatuh tempo ${formatDateIndoShort(pay.dueDate!)}',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: AppColors.textMutedColor(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (pay.status != 'paid') ...[
                    const SizedBox(height: AppTokens.space3),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _showMarkPaidSheet(pay),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppTokens.minTouchTarget),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Tandai Lunas'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space2),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineAndWorkloadTab(BuildContext context) {
    final activeTasks = _tasks.where((t) => t.status != 'done').toList();
    final totalActiveEstMinutes = activeTasks.fold<int>(
      0,
      (sum, t) => sum + (t.estimateMinutes ?? 0),
    );
    final isOverloadedHours = totalActiveEstMinutes > 2400; // > 40 jam/minggu

    // Deteksi tumpang tindih proyek aktif
    final activeProjectsWithDates = _projects
        .where(
          (p) =>
              p.status != 'completed' &&
              p.startedOn != null &&
              p.deadline != null,
        )
        .toList();
    var hasOverlappingProjects = false;
    for (var i = 0; i < activeProjectsWithDates.length; i++) {
      for (var j = i + 1; j < activeProjectsWithDates.length; j++) {
        final a = activeProjectsWithDates[i];
        final b = activeProjectsWithDates[j];
        if (a.startedOn!.isBefore(b.deadline!) &&
            b.startedOn!.isBefore(a.deadline!)) {
          hasOverlappingProjects = true;
        }
      }
    }

    final warnColor = AppColors.warningColor(context);

    // Hitung rentang linimasa global
    final datedProjects = _projects
        .where((p) => p.startedOn != null || p.deadline != null)
        .toList();
    DateTime? minStart;
    DateTime? maxEnd;
    for (final p in datedProjects) {
      final s = p.startedOn ?? p.deadline!;
      final e = p.deadline ?? p.startedOn!;
      if (minStart == null || s.isBefore(minStart)) minStart = s;
      if (maxEnd == null || e.isAfter(maxEnd)) maxEnd = e;
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linimasa & Beban Kerja',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activeTasks.length} tugas aktif  |  Estimasi total ${_formatMinutesAsHours(totalActiveEstMinutes)} (ambang 40 jam/minggu)',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
                if (isOverloadedHours || hasOverlappingProjects) ...[
                  const SizedBox(height: AppTokens.space3),
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space3),
                    decoration: BoxDecoration(
                      color: warnColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(
                        color: warnColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: warnColor,
                        ),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: Text(
                            isOverloadedHours
                                ? 'Peringatan Overload: total estimasi tugas aktif melebihi 40 jam/minggu (${_formatMinutesAsHours(totalActiveEstMinutes)}).'
                                : 'Peringatan Jadwal: terdapat beberapa proyek aktif dengan rentang tenggat bertumpuk.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          Text(
            'Beban Estimasi per Proyek',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: AppTokens.space2),
          if (_projects.isEmpty)
            const OrbitEmptyState(
              icon: Icons.view_timeline_outlined,
              title: 'Belum ada proyek',
              description: 'Tambahkan proyek untuk menganalisis beban dan linimasa.',
            )
          else ...[
            for (final p in _projects) ...[
              _buildProjectWorkloadTimelineCard(
                context,
                p,
                minStart: minStart,
                maxEnd: maxEnd,
              ),
              const SizedBox(height: AppTokens.space2),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildProjectWorkloadTimelineCard(
    BuildContext context,
    LocalProject p, {
    DateTime? minStart,
    DateTime? maxEnd,
  }) {
    final projActive = _tasks
        .where((t) => t.projectId == p.id && t.status != 'done')
        .toList();
    final todoCount = projActive.where((t) => t.status == 'todo').length;
    final doingCount = projActive.where((t) => t.status == 'doing').length;
    final revisiCount = projActive.where((t) => t.status == 'revisi').length;
    final estMin = projActive.fold<int>(
      0,
      (s, t) => s + (t.estimateMinutes ?? 0),
    );
    final loadRatio = estMin / 2400.0;

    final start = p.startedOn;
    final end = p.deadline;
    double leftFrac = 0;
    double widthFrac = 0;
    if (start != null &&
        end != null &&
        minStart != null &&
        maxEnd != null &&
        maxEnd.isAfter(minStart)) {
      final totalDays = maxEnd.difference(minStart).inDays.clamp(1, 36500);
      leftFrac = (start.difference(minStart).inDays / totalDays).clamp(
        0.0,
        0.95,
      );
      widthFrac = ((end.difference(start).inDays + 1) / totalDays).clamp(
        0.08,
        1.0 - leftFrac,
      );
    }

    return OrbitCard(
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
              ),
              Text(
                _formatMinutesAsHours(estMin),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: estMin > 2400
                      ? AppColors.warningColor(context)
                      : AppColors.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Aktif: ${projActive.length} tugas (Todo $todoCount, Dikerjakan $doingCount, Revisi $revisiCount)',
            style: TextStyle(
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: AppColors.textMutedColor(context),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            child: LinearProgressIndicator(
              value: loadRatio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.subtleColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                estMin > 2400
                    ? AppColors.warningColor(context)
                    : AppColors.getKindColor(p.kind, isDark: Theme.of(context).brightness == Brightness.dark),
              ),
            ),
          ),
          if (start != null || end != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Mulai: ${start != null ? formatDateIndoShort(start) : '-'}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space2),
                Flexible(
                  child: Text(
                    'Tenggat: ${end != null ? formatDateIndoShort(end) : '-'}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
            if (widthFrac > 0) ...[
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalW = constraints.maxWidth;
                  return Container(
                    height: 10,
                    width: totalW,
                    decoration: BoxDecoration(
                      color: AppColors.subtleColor(context),
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: totalW * leftFrac,
                          width: (totalW * widthFrac).clamp(14.0, totalW),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.getKindColor(p.kind, isDark: Theme.of(context).brightness == Brightness.dark),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusLg,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<ProjectFinancialReportRow> _buildFinancialReportRows() {
    return _projects.map((p) {
      final contract = p.contractValue ?? 0.0;
      final projPayments = _payments
          .where((pay) => pay.projectId == p.id)
          .toList();
      final paid = projPayments.fold<double>(
        0,
        (s, pay) => s + (pay.status == 'paid' ? pay.amount : pay.paidAmount),
      );
      final totalScheduled = projPayments.fold<double>(
        0,
        (s, pay) => s + pay.amount,
      );
      final basis = contract > 0 ? contract : totalScheduled;
      final remaining = (basis - paid) > 0 ? (basis - paid) : 0.0;
      final expenses = _transactions
          .where((tx) => tx.projectId == p.id && tx.type == 'expense')
          .fold<double>(0, (s, tx) => s + tx.amount);

      return ProjectFinancialReportRow(
        projectId: p.id,
        projectName: p.name,
        kind: p.kind,
        status: p.status,
        clientName: p.clientName,
        contractValue: contract,
        paidAmount: paid,
        remainingReceivable: remaining,
        totalExpenses: expenses,
      );
    }).toList();
  }

  Widget _buildMarginReportTab(BuildContext context) {
    final rows = _buildFinancialReportRows();
    final totalContract = rows.fold<double>(0, (s, r) => s + r.contractValue);
    final totalPaid = rows.fold<double>(0, (s, r) => s + r.paidAmount);
    final totalRemaining = rows.fold<double>(
      0,
      (s, r) => s + r.remainingReceivable,
    );
    final totalExpense = rows.fold<double>(0, (s, r) => s + r.totalExpenses);
    final totalMargin = totalPaid - totalExpense;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          OrbitCard(
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Laporan & Margin Proyek',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppTokens.space3),
                _MetricLine(label: 'Total Kontrak', value: totalContract),
                _MetricLine(
                  label: 'Total Terbayar',
                  value: totalPaid,
                  color: AppColors.incomeColor(context),
                ),
                _MetricLine(
                  label: 'Sisa Tagihan',
                  value: totalRemaining,
                  color: AppColors.warningColor(context),
                ),
                _MetricLine(
                  label: 'Pengeluaran Proyek',
                  value: totalExpense,
                  color: AppColors.expenseColor(context),
                ),
                Divider(color: AppColors.borderColor(context), height: 20),
                _MetricLine(
                  label: 'Margin Bersih (Kas)',
                  value: totalMargin,
                  bold: true,
                  color: totalMargin >= 0
                      ? AppColors.incomeColor(context)
                      : AppColors.expenseColor(context),
                ),
                const SizedBox(height: AppTokens.space3),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, AppTokens.minTouchTarget),
                  ),
                  onPressed: rows.isEmpty ? null : () => _exportProjectCsv(rows),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Ekspor CSV Laporan Proyek'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space3),
          if (rows.isEmpty)
            const OrbitEmptyState(
              icon: Icons.analytics_outlined,
              title: 'Belum ada laporan margin',
              description:
                  'Tambahkan proyek untuk memantau kontrak, termin masuk, dan pengeluaran terkait.',
            )
          else
            for (final r in rows) ...[
              OrbitCard(
                padding: const EdgeInsets.all(AppTokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.projectName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                        ),
                        OrbitPrivacyBuilder(
                          builder: (context, _) => OrbitStatusBadge(
                            label: PrivacyModeController.formatAmount(r.netMargin),
                            variant: r.netMargin >= 0
                                ? OrbitBadgeVariant.income
                                : OrbitBadgeVariant.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space2),
                    _MetricLine(label: 'Kontrak', value: r.contractValue),
                    _MetricLine(label: 'Terbayar', value: r.paidAmount),
                    _MetricLine(label: 'Sisa Tagihan', value: r.remainingReceivable),
                    _MetricLine(
                      label: 'Pengeluaran Proyek',
                      value: r.totalExpenses,
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddProjectExpenseSheet(r),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, AppTokens.minTouchTarget),
                        ),
                        icon: const Icon(Icons.add_card_outlined, size: 16),
                        label: const Text('Catat Pengeluaran Proyek'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space2),
            ],
        ],
      ),
    );
  }

  Future<void> _exportProjectCsv(List<ProjectFinancialReportRow> rows) async {
    final csv = FinanceCsvService.exportProjectReportCsv(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    String? filePath;
    try {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'orbit_laporan_proyek_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      filePath = file.path;
    } catch (_) {
      filePath = null;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          filePath != null
              ? 'Laporan proyek disalin & disimpan ke $filePath'
              : 'CSV laporan proyek berhasil disalin ke clipboard.',
        ),
      ),
    );
  }

  Future<void> _showMarkPaidSheet(LocalProjectPayment pay) async {
    String? accountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    final feeCtrl = TextEditingController(text: '0');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space4,
                AppTokens.space4,
                MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Konfirmasi Pelunasan Termin',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: 6),
                  OrbitPrivacyBuilder(
                    builder: (context, _) => Text(
                      '${pay.label} (${PrivacyModeController.formatAmount(pay.amount)})',
                      style: TextStyle(
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: AppColors.textSecondaryColor(ctx),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  if (_accounts.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue: accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Masuk ke Akun (Opsional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Tandai lunas tanpa catat akun',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ..._accounts.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheetState(() => accountId = v),
                    ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Biaya Admin / Platform Fee (IDR)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppTokens.minTouchTarget),
                    ),
                    onPressed: () async {
                      final fee =
                          double.tryParse(
                            feeCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                          ) ??
                          0;
                      await SyncService.instance.markProjectPaymentPaid(
                        payment: pay,
                        accountId: accountId,
                        fee: fee,
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      _loadData();
                    },
                    child: const Text('Tandai Lunas & Sinkronkan'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddProjectExpenseSheet(
    ProjectFinancialReportRow row,
  ) async {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Buat minimal 1 akun terlebih dahulu di tab Keuangan untuk mencatat pengeluaran.',
          ),
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var accountId = _accounts.first.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space4,
                AppTokens.space4,
                MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pengeluaran: ${row.projectName}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  DropdownButtonFormField<String>(
                    initialValue: accountId,
                    decoration: const InputDecoration(
                      labelText: 'Sumber Akun',
                      border: OutlineInputBorder(),
                    ),
                    items: _accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => accountId = v);
                    },
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan Biaya',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (IDR)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppTokens.minTouchTarget),
                    ),
                    onPressed: () async {
                      final amount =
                          double.tryParse(
                            amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                          ) ??
                          0;
                      if (amount <= 0) return;

                      final wsId = (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                      final txId = const Uuid().v4();
                      final now = DateTime.now().toUtc();
                      final merchant = titleCtrl.text.trim().isEmpty
                          ? 'Biaya ${row.projectName}'
                          : titleCtrl.text.trim();

                      await AppDatabase.shared
                          .into(AppDatabase.shared.localTransactions)
                          .insertOnConflictUpdate(
                            LocalTransactionsCompanion.insert(
                              id: txId,
                              workspaceId: wsId,
                              accountId: accountId,
                              projectId: drift.Value(row.projectId),
                              type: 'expense',
                              status: 'confirmed',
                              amount: amount,
                              currency: 'IDR',
                              source: const drift.Value('freelance'),
                              merchant: drift.Value(merchant),
                              note: drift.Value('Biaya proyek ${row.projectName}'),
                              occurredAt: now,
                            ),
                          );
                      await SyncService.instance.pushRecord(
                        tableName: 'transactions',
                        recordId: txId,
                        action: 'insert',
                        payload: {
                          'id': txId,
                          'workspace_id': wsId,
                          'account_id': accountId,
                          'project_id': row.projectId,
                          'type': 'expense',
                          'status': 'confirmed',
                          'amount': amount,
                          'currency': 'IDR',
                          'source': 'freelance',
                          'merchant': merchant,
                          'note': 'Biaya proyek ${row.projectName}',
                          'occurred_at': now.toIso8601String(),
                          'origin': 'manual',
                        },
                      );

                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      _loadData();
                    },
                    child: const Text('Simpan Pengeluaran'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddProjectSheet() async {
    final nameCtrl = TextEditingController();
    final clientCtrl = TextEditingController();
    final contractCtrl = TextEditingController();
    var kind = 'freelance';
    DateTime startedOn = DateTime.now();
    DateTime deadline = DateTime.now().add(const Duration(days: 14));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space4,
                AppTokens.space4,
                MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tambah Proyek / Kegiatan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Proyek',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(
                      labelText: 'Jenis',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'freelance',
                        child: Text('Freelance'),
                      ),
                      DropdownMenuItem(value: 'intern', child: Text('Intern')),
                      DropdownMenuItem(value: 'kuliah', child: Text('Kuliah')),
                      DropdownMenuItem(
                        value: 'pribadi',
                        child: Text('Pribadi'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => kind = v);
                    },
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: clientCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Klien / Instansi (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: contractCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nilai Kontrak (IDR, Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, AppTokens.minTouchTarget),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startedOn,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() => startedOn = picked);
                            }
                          },
                          child: Text('Mulai ${formatDateIndoShort(startedOn)}'),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space2),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, AppTokens.minTouchTarget),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: deadline,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() => deadline = picked);
                            }
                          },
                          child: Text('Tenggat ${formatDateIndoShort(deadline)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space3),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppTokens.minTouchTarget),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final contract = double.tryParse(
                        contractCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                      );
                      final wsId = (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                      final id = const Uuid().v4();

                      await AppDatabase.shared
                          .into(AppDatabase.shared.localProjects)
                          .insertOnConflictUpdate(
                            LocalProjectsCompanion.insert(
                              id: id,
                              workspaceId: wsId,
                              kind: kind,
                              name: name,
                              status: const drift.Value('berjalan'),
                              clientName: drift.Value(
                                clientCtrl.text.trim().isEmpty
                                    ? null
                                    : clientCtrl.text.trim(),
                              ),
                              contractValue: drift.Value(contract),
                              startedOn: drift.Value(startedOn),
                              deadline: drift.Value(deadline),
                            ),
                          );
                      await SyncService.instance.pushRecord(
                        tableName: 'projects',
                        recordId: id,
                        action: 'insert',
                        payload: {
                          'id': id,
                          'workspace_id': wsId,
                          'kind': kind,
                          'name': name,
                          'status': 'berjalan',
                          if (clientCtrl.text.trim().isNotEmpty)
                            'client_name': clientCtrl.text.trim(),
                          if (kind == 'freelance' && contract != null) ...{
                            'contract_value': contract,
                            'currency': 'IDR',
                          },
                          'started_on': startedOn.toUtc().toIso8601String(),
                          'deadline': deadline.toUtc().toIso8601String(),
                        },
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      _loadData();
                    },
                    child: const Text('Simpan Proyek'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddPaymentSheet() async {
    if (_projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 proyek sebelum membuat termin.'),
        ),
      );
      return;
    }

    var projectId = _projects.first.id;
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space4,
                AppTokens.space4,
                AppTokens.space4,
                MediaQuery.of(ctx).viewInsets.bottom + AppTokens.space4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tambah Termin Piutang',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryColor(ctx),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  DropdownButtonFormField<String>(
                    initialValue: projectId,
                    decoration: const InputDecoration(
                      labelText: 'Proyek',
                      border: OutlineInputBorder(),
                    ),
                    items: _projects
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => projectId = v);
                    },
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label Termin (contoh: DP 50%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (IDR)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space3),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppTokens.minTouchTarget),
                    ),
                    onPressed: () async {
                      final label = labelCtrl.text.trim();
                      final amount =
                          double.tryParse(
                            amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
                          ) ??
                          0;
                      if (label.isEmpty || amount <= 0) return;

                      final wsId = (await SyncService.instance.getWorkspaceId()) ?? 'personal-ws';
                      final id = const Uuid().v4();
                      final dueDate = DateTime.now().add(
                        const Duration(days: 7),
                      );
                      await AppDatabase.shared
                          .into(AppDatabase.shared.localProjectPayments)
                          .insertOnConflictUpdate(
                            LocalProjectPaymentsCompanion.insert(
                              id: id,
                              workspaceId: wsId,
                              projectId: projectId,
                              label: label,
                              amount: amount,
                              dueDate: drift.Value(dueDate),
                            ),
                          );
                      await SyncService.instance.pushRecord(
                        tableName: 'project_payments',
                        recordId: id,
                        action: 'insert',
                        payload: {
                          'id': id,
                          'workspace_id': wsId,
                          'project_id': projectId,
                          'label': label,
                          'amount': amount,
                          'due_date': dueDate.toUtc().toIso8601String(),
                          'status': 'pending',
                          'paid_amount': 0,
                        },
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      _loadData();
                    },
                    child: const Text('Simpan Termin'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showProjectDetailSheet(LocalProject p) async {
    final projTasks = _tasks.where((t) => t.projectId == p.id).toList();
    final projPay = _payments.where((pay) => pay.projectId == p.id).toList();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppTokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  OrbitKindBadge(kind: p.kind),
                  const SizedBox(width: AppTokens.space2),
                  OrbitStatusBadge(
                    label: _projectStatusLabel(p.status),
                    variant: OrbitBadgeVariant.neutral,
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space2),
              Text(
                p.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryColor(ctx),
                ),
              ),
              const SizedBox(height: AppTokens.space2),
              Text(
                '${projTasks.length} tugas terkait  |  ${projPay.length} termin pembayaran',
                style: TextStyle(
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: AppColors.textSecondaryColor(ctx),
                ),
              ),
              if (p.description != null && p.description!.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space2),
                Text(p.description!),
              ],
              const SizedBox(height: AppTokens.space4),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppTokens.minTouchTarget),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _projectStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'on_hold':
        return 'Ditunda';
      default:
        return 'Aktif';
    }
  }

  String _paymentStatusLabel(LocalProjectPayment pay) {
    switch (pay.status) {
      case 'paid':
        return 'Lunas';
      case 'overdue':
        return 'Terlambat';
      case 'partial':
        return 'Sebagian';
      default:
        return 'Menunggu';
    }
  }

  String _formatMinutesAsHours(int minutes) {
    if (minutes <= 0) return '0 j';
    if (minutes < 60) return '$minutes mnt';
    final hours = minutes / 60.0;
    return '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} jam';
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  final bool bold;

  const _MetricLine({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space2),
          Flexible(
            child: OrbitAmountText(
              amount: value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: color ?? AppColors.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
