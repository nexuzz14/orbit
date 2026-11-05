import 'package:flutter/material.dart';
import 'package:orbit_app/core/constants/app_colors.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/sync_service.dart';
import 'package:orbit_app/core/widgets/orbit_widgets.dart';

class PlanningScreen extends StatefulWidget {
  final String initialTab; // 'anggaran' | 'tagihan' | 'target'
  final bool forceLoading;
  final bool forceEmpty;
  final String? forceError;

  const PlanningScreen({
    super.key,
    this.initialTab = 'anggaran',
    this.forceLoading = false,
    this.forceEmpty = false,
    this.forceError,
  });

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  AppDatabase get _db => AppDatabase.shared;

  late String _activeTab;
  late bool _loading;
  String? _errorMessage;

  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _goals = [];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loading = widget.forceLoading;
    _errorMessage = widget.forceError;
    if (!widget.forceLoading && widget.forceError == null) {
      _loadData();
      if (!widget.forceEmpty) {
        SyncService.instance.pullAllFromSupabase().then((_) {
          if (mounted) _loadData();
        });
      }
    }
  }

  Future<void> _loadData({bool pull = false}) async {
    if (widget.forceLoading) return;
    if (widget.forceError != null) return;

    if (pull) {
      setState(() => _loading = true);
      await SyncService.instance.pullAllFromSupabase();
    }

    if (widget.forceEmpty) {
      if (mounted) {
        setState(() {
          _budgets = [];
          _subscriptions = [];
          _goals = [];
          _loading = false;
        });
      }
      return;
    }

    try {
      // 1. Muat Anggaran
      final localBudgets = await (_db.select(_db.localBudgets)
            ..where((b) => b.deletedAt.isNull()))
          .get();
      final localCategories = await _db.select(_db.localCategories).get();
      final catNameMap = {for (final c in localCategories) c.id: c.name};

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final localTxs = await _db.select(_db.localTransactions).get();

      final budgetList = <Map<String, dynamic>>[];
      for (final b in localBudgets) {
        final catName = catNameMap[b.categoryId] ?? b.categoryId;
        final spent = localTxs
            .where((t) =>
                (t.categoryId == b.categoryId || t.categoryId == catName) &&
                t.type == 'expense' &&
                t.status == 'confirmed' &&
                t.deletedAt == null &&
                t.occurredAt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))))
            .fold<double>(0.0, (acc, t) => acc + t.amount);

        budgetList.add({
          'id': b.id,
          'category': catName,
          'kind': 'pribadi',
          'limit': b.amount,
          'spent': spent,
        });
      }

      // 2. Muat Tagihan Berulang
      final localBills = await (_db.select(_db.localRecurringBills)
            ..where((b) => b.deletedAt.isNull()))
          .get();
      final billList = <Map<String, dynamic>>[];
      for (final b in localBills) {
        billList.add({
          'id': b.id,
          'name': b.name,
          'amount': b.amount,
          'cycle': b.scheduleType == 'monthly' ? 'Bulanan' : 'Mingguan',
          'nextDue': 'Tgl ${b.scheduleValue}',
          'kind': 'pribadi',
        });
      }

      // 3. Muat Target Tabungan
      final localGoals = await (_db.select(_db.localSavingsGoals)
            ..where((g) => g.deletedAt.isNull()))
          .get();
      final goalList = <Map<String, dynamic>>[];
      for (final g in localGoals) {
        goalList.add({
          'id': g.id,
          'name': g.name,
          'target': g.targetAmount,
          'current': g.currentAmount,
          'deadline': g.targetDate != null ? formatDateIndoShort(g.targetDate!) : '-',
          'kind': 'pribadi',
        });
      }

      if (mounted) {
        setState(() {
          _budgets = budgetList;
          _subscriptions = billList;
          _goals = goalList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat rencana keuangan: $e';
          _loading = false;
        });
      }
    }
  }

  void _reload() {
    _loadData(pull: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perencanaan Keuangan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
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
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'anggaran', label: Text('Anggaran')),
                ButtonSegment(value: 'tagihan', label: Text('Tagihan')),
                ButtonSegment(value: 'target', label: Text('Target')),
              ],
              selected: {_activeTab},
              onSelectionChanged: (s) => setState(() => _activeTab = s.first),
            ),
            const SizedBox(height: AppTokens.space4),

            if (_errorMessage != null) ...[
              OrbitErrorState(
                message: _errorMessage!,
                onRetry: _reload,
              ),
              const SizedBox(height: AppTokens.space4),
            ],

            if (_loading) ...[
              const OrbitSkeleton(height: 92),
              const SizedBox(height: AppTokens.space3),
              const OrbitSkeleton(height: 92),
            ] else if (_activeTab == 'anggaran') ...[
              if (_budgets.isEmpty)
                OrbitEmptyState(
                  icon: Icons.pie_chart_outline,
                  title: 'Belum ada anggaran bulanan',
                  description:
                      'Tetapkan batas pengeluaran per kategori agar arus kas tetap terkendali.',
                  actionLabel: 'Segarkan',
                  onAction: _reload,
                )
              else
                for (final b in _budgets) ...[
                  _buildBudgetCard(context, b, secondaryColor),
                  const SizedBox(height: AppTokens.space3),
                ],
            ] else if (_activeTab == 'tagihan') ...[
              if (_subscriptions.isEmpty)
                OrbitEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada tagihan berulang',
                  description:
                      'Pantau jadwal jatuh tempo langganan bulanan dan tagihan rutin Anda.',
                  actionLabel: 'Segarkan',
                  onAction: _reload,
                )
              else
                for (final s in _subscriptions) ...[
                  _buildSubscriptionCard(context, s, secondaryColor),
                  const SizedBox(height: AppTokens.space3),
                ],
            ] else ...[
              if (_goals.isEmpty)
                OrbitEmptyState(
                  icon: Icons.flag_outlined,
                  title: 'Belum ada target tabungan',
                  description:
                      'Buat target dana darurat atau pembelian perangkat dengan progres terukur.',
                  actionLabel: 'Segarkan',
                  onAction: _reload,
                )
              else
                for (final g in _goals) ...[
                  _buildGoalCard(context, g, secondaryColor),
                  const SizedBox(height: AppTokens.space3),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    Map<String, dynamic> b,
    Color secondaryColor,
  ) {
    final limit = b['limit'] as double;
    final spent = b['spent'] as double;
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > limit;
    final isWarn = ratio >= 0.8 && !isOver;

    final barColor = isOver
        ? AppColors.expenseColor(context)
        : isWarn
            ? AppColors.warningColor(context)
            : AppColors.incomeColor(context);

    return OrbitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  b['category'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OrbitKindBadge(kind: b['kind'] as String),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${formatRupiah(spent)} / ${formatRupiah(limit)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              OrbitStatusBadge(
                label: isOver
                    ? 'Melebihi Batas'
                    : '${(ratio * 100).round()}% Terpakai',
                variant: isOver
                    ? OrbitBadgeVariant.expense
                    : isWarn
                        ? OrbitBadgeVariant.warning
                        : OrbitBadgeVariant.income,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: barColor,
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    Map<String, dynamic> s,
    Color secondaryColor,
  ) {
    return OrbitCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['name'] as String,
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
                    OrbitKindBadge(kind: s['kind'] as String),
                    Text(
                      '${s['cycle']} - Jatuh tempo ${s['nextDue']}',
                      style: TextStyle(fontSize: 11, color: secondaryColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(s['amount'] as double),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.expenseColor(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    Map<String, dynamic> g,
    Color secondaryColor,
  ) {
    final target = g['target'] as double;
    final current = g['current'] as double;
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return OrbitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  g['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OrbitKindBadge(kind: g['kind'] as String),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${formatRupiah(current)} dari ${formatRupiah(target)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space2),
              OrbitStatusBadge(
                label: '${(ratio * 100).round()}% Tercapai',
                variant: ratio >= 1.0
                    ? OrbitBadgeVariant.income
                    : OrbitBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: AppColors.accentColor(context),
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}
